import 'dart:math';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import 'package:latlong2/latlong.dart';
import 'feature_layer_options.dart';
import 'package:tuple/tuple.dart';
import 'package:dio/dio.dart';
import 'dart:convert';
import 'package:flutter_map/src/layer/tile_layer/tile_image_manager.dart';
import 'dart:async';
import 'package:flutter_map/src/layer/tile_layer/tile_range.dart';
import 'package:flutter_map/src/layer/tile_layer/tile_bounds/tile_bounds.dart';
import 'package:flutter_map/src/layer/tile_layer/tile_range_calculator.dart';
import 'package:flutter_map/src/layer/tile_layer/tile_scale_calculator.dart';
import 'package:flutter_map/src/layer/tile_layer/tile_update_event.dart';

@immutable
class FeatureLayer extends StatefulWidget {
  final FeatureLayerOptions options;
  final Stream<void>? reset;

  /// Only load tiles that are within these bounds
  final LatLngBounds? tileBounds;
  final TileUpdateTransformer tileUpdateTransformer;

  FeatureLayer(
    this.options, {
    super.key,
    this.reset,
    this.tileBounds,
    TileUpdateTransformer? tileUpdateTransformer,
  }) : tileUpdateTransformer =
            tileUpdateTransformer ?? TileUpdateTransformers.ignoreTapEvents {}

  @override
  State<StatefulWidget> createState() => _FeatureLayerState();
}

class _FeatureLayerState extends State<FeatureLayer>
    with TickerProviderStateMixin {
  bool _initializedFromMapCamera = false;
  List<dynamic> featuresPre = <dynamic>[];
  List<dynamic> features = <dynamic>[];

  StreamSubscription? _moveSub;

  var timer = Timer(Duration(milliseconds: 100), () => {});

  bool isMoving = false;

  Tuple2<double, double>? _wrapX;
  Tuple2<double, double>? _wrapY;
  double? _tileZoom;

  Bounds? _globalTileRange;
  LatLngBounds? currentBounds;
  int activeRequests = 0;
  int targetRequests = 0;

  final _tileImageManager = TileImageManager();
  late TileBounds _tileBounds;
  late var _tileRangeCalculator = TileRangeCalculator(tileSize: 256);
  late TileScaleCalculator _tileScaleCalculator;

  // We have to hold on to the mapController hashCode to determine whether we
  // need to reinitialize the listeners. didChangeDependencies is called on
  // every map movement and if we unsubscribe and resubscribe every time we
  // miss events.
  int? _mapControllerHashCode;

  StreamSubscription<TileUpdateEvent>? _tileUpdateSubscription;
  Timer? _pruneLater;

  late final _resetSub = widget.reset?.listen((_) {
    _tileImageManager.removeAll(EvictErrorTileStrategy.none);
    _loadAndPruneInVisibleBounds(MapCamera.of(context));
  });

  // This is called on every map movement so we should avoid expensive logic
  // where possible.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final camera = MapCamera.of(context);
    final mapController = MapController.of(context);

    if (_mapControllerHashCode != mapController.hashCode) {
      _tileUpdateSubscription?.cancel();

      _mapControllerHashCode = mapController.hashCode;
      _tileUpdateSubscription = mapController.mapEventStream
          .map((mapEvent) => TileUpdateEvent(mapEvent: mapEvent))
          .transform(widget.tileUpdateTransformer)
          .listen((event) => _onTileUpdateEvent(event));
    }

    var reloadTiles = false;
    if (!_initializedFromMapCamera ||
        _tileBounds.shouldReplace(camera.crs, 256, widget.tileBounds)) {
      reloadTiles = true;
      _tileBounds = TileBounds(
        crs: camera.crs,
        tileSize: 256,
        latLngBounds: widget.tileBounds,
      );
    }

    if (!_initializedFromMapCamera ||
        _tileScaleCalculator.shouldReplace(camera.crs, 256)) {
      reloadTiles = true;
      _tileScaleCalculator = TileScaleCalculator(
        crs: camera.crs,
        tileSize: 256,
      );
    }

    if (reloadTiles) _loadAndPruneInVisibleBounds(camera);

    _initializedFromMapCamera = true;
  }

  int _clampToNativeZoom(double zoom) => zoom.round().clamp(0, 19);

  @override
  void didUpdateWidget(FeatureLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    var reloadTiles = false;

    // There is no caching in TileRangeCalculator so we can just replace it.
    _tileRangeCalculator = TileRangeCalculator(tileSize: 256);

    if (_tileBounds.shouldReplace(_tileBounds.crs, 256, widget.tileBounds)) {
      _tileBounds = TileBounds(
        crs: _tileBounds.crs,
        tileSize: 256,
        latLngBounds: widget.tileBounds,
      );
      reloadTiles = true;
    }

    if (_tileScaleCalculator.shouldReplace(_tileScaleCalculator.crs, 256)) {
      _tileScaleCalculator = TileScaleCalculator(
        crs: _tileScaleCalculator.crs,
        tileSize: 256,
      );
    }

    if (reloadTiles) {
      _tileImageManager.removeAll(EvictErrorTileStrategy.none);
      _loadAndPruneInVisibleBounds(MapCamera.maybeOf(context)!);
    }
  }

  void _onTileUpdateEvent(TileUpdateEvent event) {
    final tileZoom = _clampToNativeZoom(event.zoom);
    final visibleTileRange = _tileRangeCalculator.calculate(
      camera: event.camera,
      tileZoom: tileZoom,
      center: event.center,
      viewingZoom: event.zoom,
    );

    if (event.load) {
      _loadTiles(visibleTileRange, pruneAfterLoad: event.prune);
    }

    if (event.prune) {
      _tileImageManager.evictAndPrune(
        visibleRange: visibleTileRange,
        pruneBuffer: 1 + 2,
        evictStrategy: EvictErrorTileStrategy.none,
      );
    }
  }

  void _loadTiles(
    DiscreteTileRange tileLoadRange, {
    required bool pruneAfterLoad,
  }) async {
    setState(() {
      if (isMoving) {
        timer.cancel();
      }

      isMoving = true;
      timer = Timer(Duration(milliseconds: 200), () {
        isMoving = false;
        if (pruneAfterLoad) {
          final map = MapCamera.of(context);

          targetRequests = 1;
          activeRequests = 1;
          requestFeatures(map.visibleBounds);
        }
      });
    });
  }

  Bounds _pxBoundsToTileRange(Bounds bounds) {
    var tileSize = CustomPoint(256.0, 256.0);
    return Bounds(
      bounds.min.unscaleBy(tileSize).floor(),
      bounds.max.unscaleBy(tileSize).ceil() - CustomPoint(1, 1),
    );
  }

  double _clampZoom(double zoom) {
    // todo
    return zoom;
  }

  void getMapState() {}

  void _loadAndPruneInVisibleBounds(MapCamera camera) {
    final tileZoom = _clampToNativeZoom(camera.zoom);
    final visibleTileRange = _tileRangeCalculator.calculate(
      camera: camera,
      tileZoom: tileZoom,
    );

    _tileImageManager.evictAndPrune(
      visibleRange: visibleTileRange,
      pruneBuffer: max(1, 2),
      evictStrategy: EvictErrorTileStrategy.none,
    );
  }

  Future requestFeatures(LatLngBounds bounds) async {
    try {
      String bounds_ =
          '"xmin":${bounds.southWest!.longitude},"ymin":${bounds.southWest!.latitude},"xmax":${bounds.northEast!.longitude},"ymax":${bounds.northEast?.latitude}';

      String url =
          '${widget.options.url}/query?f=json&geometry={"spatialReference":{"wkid":4326},$bounds_}&maxRecordCountFactor=30&outFields=*&outSR=4326&returnExceededLimitFeatures=true&spatialRel=esriSpatialRelIntersects&where=1=1&geometryType=esriGeometryEnvelope';

      // print(url);

      Response response = await Dio().get(url);

      var features_ = <dynamic>[];

      var jsonData = response.data;
      if (jsonData is String) {
        jsonData = jsonDecode(jsonData);
      }

      if (jsonData["features"] != null) {
        for (var feature in jsonData["features"]) {
          if (widget.options.geometryType == "point") {
            var render = widget.options.render!(feature["attributes"]);

            if (render != null) {
              var latLng = LatLng(feature["geometry"]["y"].toDouble(),
                  feature["geometry"]["x"].toDouble());

              features_.add(Marker(
                width: render.width,
                height: render.height,
                point: latLng,
                child: Container(
                    child: GestureDetector(
                  onTap: () {
                    widget.options.onTap!(feature["attributes"], latLng);
                  },
                  child: render.builder,
                )),
              ));
            }
          } else if (widget.options.geometryType == "polygon") {
            for (var ring in feature["geometry"]["rings"]) {
              var points = <LatLng>[];

              for (var point_ in ring) {
                points.add(LatLng(point_[1].toDouble(), point_[0].toDouble()));
              }

              var render = widget.options.render!(feature["attributes"]);

              if (render != null) {
                features_.add(PolygonEsri(
                  points: points,
                  borderStrokeWidth: render.borderStrokeWidth,
                  color: render.color,
                  borderColor: render.borderColor,
                  isDotted: render.isDotted,
                  isFilled: render.isFilled,
                  attributes: feature["attributes"],
                ));
              }
            }
          } else if (widget.options.geometryType == "polyline") {
            for (var ring in feature["geometry"]["paths"]) {
              var points = <LatLng>[];

              for (var point_ in ring) {
                points.add(LatLng(point_[1].toDouble(), point_[0].toDouble()));
              }

              var render = widget.options.render!(feature["attributes"]);

              if (render != null) {
                features_.add(PolyLineEsri(
                  points: points,
                  borderStrokeWidth: render.borderStrokeWidth,
                  color: render.color,
                  borderColor: render.borderColor,
                  isDotted: render.isDotted,
                  attributes: feature["attributes"],
                ));
              }
            }
          }
        }

        activeRequests++;

        if (activeRequests >= targetRequests) {
          setState(() {
            features = [...featuresPre, ...features_];
            featuresPre = <Marker>[];
          });
        } else {
          setState(() {
            features = [...features, ...features_];
            featuresPre = [...featuresPre, ...features_];
          });
        }
      }
    } catch (e) {
      print(e);
    }
  }

  void findTapedPolygon(LatLng position) {
    for (var polygon in features) {
      var isInclude = _pointInPolygon(position, polygon.points);
      if (isInclude) {
        widget.options.onTap!(polygon.attributes, position);
      } else {
        widget.options.onTap!(null, position);
      }
    }
  }

  LatLng _offsetToCrs(Offset offset) {
    final camera = MapCamera.of(context);
    var renderObject = context.findRenderObject() as RenderBox;
    var width = renderObject.size.width;
    var height = renderObject.size.height;

    // convert the point to global coordinates
    var localPoint = _offsetToPoint(offset);
    var localPointCenterDistance =
        CustomPoint((width / 2) - localPoint.x, (height / 2) - localPoint.y);
    var mapCenter = camera.project(camera.center);
    var point = mapCenter - localPointCenterDistance;
    return camera.unproject(point);
  }

  CustomPoint _offsetToPoint(Offset offset) {
    return CustomPoint(offset.dx, offset.dy);
  }

  @override
  void dispose() {
    _tileUpdateSubscription?.cancel();
    _tileImageManager.removeAll(EvictErrorTileStrategy.none);
    _resetSub?.cancel();
    _pruneLater?.cancel();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.options.geometryType == "point") {
      return _buildMarkers(context);
    } else if (widget.options.geometryType == "polyline") {
      return LayoutBuilder(
        builder: (BuildContext context, BoxConstraints bc) {
          // TODO unused BoxContraints should remove?
          final size = Size(bc.maxWidth, bc.maxHeight);
          return _buildPoygonLines(context, size);
        },
      );
    } else {
      return LayoutBuilder(
        builder: (BuildContext context, BoxConstraints bc) {
          // TODO unused BoxContraints should remove?
          final size = Size(bc.maxWidth, bc.maxHeight);
          return _buildPoygons(context, size);
        },
      );
    }
  }

  Widget _buildMarkers(BuildContext context) {
    final map = MapCamera.of(context);
    var alignment = Alignment.center;
    return MobileLayerTransformer(
      child: Stack(
        children: (List<dynamic> markers) sync* {
          for (final m in features) {
            // Resolve real alignment
            final left = 0.5 * m.width * ((m.alignment ?? alignment).x + 1);
            final top = 0.5 * m.height * ((m.alignment ?? alignment).y + 1);
            final right = m.width - left;
            final bottom = m.height - top;

            // Perform projection
            final pxPoint = map.project(m.point);

            // Cull if out of bounds
            if (!map.pixelBounds.containsPartialBounds(
              Bounds(
                Point(pxPoint.x + left, pxPoint.y - bottom),
                Point(pxPoint.x - right, pxPoint.y + top),
              ),
            )) continue;

            // Apply map camera to marker position
            final pos = pxPoint - map.pixelOrigin.toDoublePoint();

            yield Positioned(
              key: m.key,
              width: m.width,
              height: m.height,
              left: pos.x - right,
              top: pos.y - bottom,
              child: m.child,
            );
          }
        }(features)
            .toList(),
      ),
    );
  }

  Widget _buildPoygons(BuildContext context, Size size) {
    var elements = <Widget>[];
    if (features.isNotEmpty) {
      final camera = MapCamera.of(context);
      for (var polygon in features) {
        if (polygon is PolygonEsri) {
          polygon.offsets.clear();
          var i = 0;

          for (var point in polygon.points) {
            var pos = camera
                .project(point)
                .subtract(camera.pixelOrigin)
                .toDoublePoint();

            polygon.offsets.add(Offset(pos.x.toDouble(), pos.y.toDouble()));
            if (i > 0 && i < polygon.points.length) {
              polygon.offsets.add(Offset(pos.x.toDouble(), pos.y.toDouble()));
            }
            i++;
          }

          elements.add(
            GestureDetector(
                onTapUp: (details) {
                  RenderBox box = context.findRenderObject() as RenderBox;
                  final offset = box.globalToLocal(details.globalPosition);

                  var latLng = _offsetToCrs(offset);
                  findTapedPolygon(latLng);
                },
                child: MobileLayerTransformer(
                    child: CustomPaint(
                  painter: PolygonPainter([polygon], camera, false, false),
                  size: size,
                ))),
          );
//          elements.add(
//              CustomPaint(
//                painter: PolygonPainter(polygon),
//                size: size,
//              )
//          );

//        elements.add(
//            CustomPaint(
//              painter:  PolygonPainter(polygon),
//              size: size,
//            )
//        );
        }
      }
    }

    return Container(
      child: Stack(
        children: elements,
      ),
    );
  }

  Widget _buildPoygonLines(BuildContext context, Size size) {
    var elements = <Widget>[];

    if (features.isNotEmpty) {
      final camera = MapCamera.of(context);
      for (var polyLine in features) {
        if (polyLine is PolyLineEsri) {
          polyLine.offsets.clear();
          var i = 0;

          for (var point in polyLine.points) {
            var pos = camera
                .project(point)
                .subtract(camera.pixelOrigin)
                .toDoublePoint();
            polyLine.offsets.add(Offset(pos.x.toDouble(), pos.y.toDouble()));
            if (i > 0 && i < polyLine.points.length) {
              polyLine.offsets.add(Offset(pos.x.toDouble(), pos.y.toDouble()));
            }
            i++;
          }

          elements.add(
            GestureDetector(
                onTapUp: (details) {
                  RenderBox box = context.findRenderObject() as RenderBox;
                  final offset = box.globalToLocal(details.globalPosition);

                  var latLng = _offsetToCrs(offset);
                  findTapedPolygon(latLng);
                },
                child: MobileLayerTransformer(
                    child: CustomPaint(
                  painter:
                      PolylinePainter([polyLine] as List<Polyline>, camera),
                  size: size,
                ))),
          );
        }
      }
    }

    return Container(
      child: Stack(
        children: elements,
      ),
    );
  }
}

class PolygonEsri extends Polygon {
  final List<LatLng> points;
  final List<Offset> offsets = [];
  final Color color;
  final double borderStrokeWidth;
  final Color borderColor;
  final bool isDotted;
  final bool isFilled;
  final dynamic attributes;
  late final LatLngBounds boundingBox;

  PolygonEsri({
    required this.points,
    this.color = const Color(0xFF00FF00),
    this.borderStrokeWidth = 0.0,
    this.borderColor = const Color(0xFFFFFF00),
    this.isDotted = false,
    this.isFilled = false,
    this.attributes,
  }) : super(points: points) {
    boundingBox = LatLngBounds.fromPoints(points);
  }
}

class PolyLineEsri extends Polyline {
  final List<LatLng> points;
  final List<Offset> offsets = [];
  final Color color;
  final double borderStrokeWidth;
  final Color borderColor;
  final bool isDotted;
  final dynamic attributes;
  late final LatLngBounds boundingBox;

  PolyLineEsri({
    required this.points,
    this.color = const Color(0xFF00FF00),
    this.borderStrokeWidth = 0.0,
    this.borderColor = const Color(0xFFFFFF00),
    this.isDotted = false,
    this.attributes,
  }) : super(points: points) {
    boundingBox = LatLngBounds.fromPoints(points);
  }
}

bool _pointInPolygon(LatLng position, List<LatLng> points) {
  // Check if the point sits exactly on a vertex
  // var vertexPosition = points.firstWhere((point) => point == position, orElse: () => null);
  LatLng? vertexPosition =
      points.firstWhereOrNull((point) => point == position);
  if (vertexPosition != null) {
    return true;
  }

  // Check if the point is inside the polygon or on the boundary
  int intersections = 0;
  var verticesCount = points.length;

  for (int i = 1; i < verticesCount; i++) {
    LatLng vertex1 = points[i - 1];
    LatLng vertex2 = points[i];

    // Check if point is on an horizontal polygon boundary
    if (vertex1.latitude == vertex2.latitude &&
        vertex1.latitude == position.latitude &&
        position.longitude > min(vertex1.longitude, vertex2.longitude) &&
        position.longitude < max(vertex1.longitude, vertex2.longitude)) {
      return true;
    }

    if (position.latitude > min(vertex1.latitude, vertex2.latitude) &&
        position.latitude <= max(vertex1.latitude, vertex2.latitude) &&
        position.longitude <= max(vertex1.longitude, vertex2.longitude) &&
        vertex1.latitude != vertex2.latitude) {
      var xinters = (position.latitude - vertex1.latitude) *
              (vertex2.longitude - vertex1.longitude) /
              (vertex2.latitude - vertex1.latitude) +
          vertex1.longitude;
      if (xinters == position.longitude) {
        // Check if point is on the polygon boundary (other than horizontal)
        return true;
      }
      if (vertex1.longitude == vertex2.longitude ||
          position.longitude <= xinters) {
        intersections++;
      }
    }
  }

  // If the number of edges we passed through is odd, then it's in the polygon.
  return intersections % 2 != 0;
}

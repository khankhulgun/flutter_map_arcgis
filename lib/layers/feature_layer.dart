import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map/plugin_api.dart';


import 'package:latlong/latlong.dart';
import 'feature_layer_options.dart';
import 'package:tuple/tuple.dart';
import 'package:flutter_map/src/core/util.dart' as util;

import 'package:dio/dio.dart';
import 'dart:convert';

import 'dart:async';

//import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';

class FeatureLayer extends StatefulWidget {
  final FeatureLayerOptions options;
  final MapState map;
  final Stream<void> stream;

  FeatureLayer(this.options, this.map, this.stream);

  @override
  _FeatureLayerState createState() => _FeatureLayerState();
}

class _FeatureLayerState extends State<FeatureLayer>{

  var  featuresPre =   <Marker>[];
  var features =  <Marker>[];

  StreamSubscription _moveSub;

  var timer = Timer(Duration(milliseconds: 100), () => {});

  bool isMoving = false;

  final Map<String, Tile> _tiles = {};
  final Map<double, Level> _levels = {};
  Tuple2<double, double> _wrapX;
  Tuple2<double, double> _wrapY;
  double _tileZoom;
  Level _level;
  Bounds _globalTileRange;
  int activeRequests;
  int targetRequests;

  @override
  initState() {
    super.initState();
    _resetView();
    //requestFeatures(widget.map.getBounds());
    _moveSub = widget.stream.listen((_) => _handleMove());

  }

  void _handleMove() {
    if(isMoving){
      timer.cancel();
    }
    isMoving = true;
    timer = Timer(Duration(milliseconds: 200), (){
        isMoving = false;
        _resetView();

    });
  }
  void _resetView() {
    setState(() {
      featuresPre = <Marker>[];
//      features = null;
    });
    _setView(widget.map.center, widget.map.zoom);
    _resetGrid();
    genrateVirtualGrids();
  }

  void _setView(LatLng center, double zoom) {
    var tileZoom = _clampZoom(zoom.round().toDouble());
    if (_tileZoom != tileZoom) {
      _tileZoom = tileZoom;

    }

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
  Coords _wrapCoords(Coords coords) {
    var newCoords = Coords(
      _wrapX != null
          ? util.wrapNum(coords.x.toDouble(), _wrapX)
          : coords.x.toDouble(),
      _wrapY != null
          ? util.wrapNum(coords.y.toDouble(), _wrapY)
          : coords.y.toDouble(),
    );
    newCoords.z = coords.z.toDouble();
    return newCoords;
  }


  bool _boundsContainsMarker(Marker marker) {
    var pixelPoint = widget.map.project(marker.point);

    final width = marker.width - marker.anchor.left;
    final height = marker.height - marker.anchor.top;

    var sw = CustomPoint(pixelPoint.x + width, pixelPoint.y - height);
    var ne = CustomPoint(pixelPoint.x - width, pixelPoint.y + height);
    return widget.map.pixelBounds.containsPartialBounds(Bounds(sw, ne));
  }
  Bounds _getTiledPixelBounds(LatLng center) {
    return widget.map.getPixelBounds(_tileZoom);
  }

  void _resetGrid() {
    var map = widget.map;
    var crs = map.options.crs;
    var tileSize = 256.0;
    var tileZoom = _tileZoom;

    var bounds = map.getPixelWorldBounds(_tileZoom);
    if (bounds != null) {
      _globalTileRange = _pxBoundsToTileRange(bounds);
    }

    // wrapping
    _wrapX = crs.wrapLng;
    if (_wrapX != null) {
      var first =
      (map.project(LatLng(0.0, crs.wrapLng.item1), tileZoom).x / 256.0)
          .floor()
          .toDouble();
      var second =
      (map.project(LatLng(0.0, crs.wrapLng.item2), tileZoom).x / 256.0)
          .ceil()
          .toDouble();
      _wrapX = Tuple2(first, second);
    }

    _wrapY = crs.wrapLat;
    if (_wrapY != null) {
      var first =
      (map.project(LatLng(crs.wrapLat.item1, 0.0), tileZoom).y / 256.0)
          .floor()
          .toDouble();
      var second =
      (map.project(LatLng(crs.wrapLat.item2, 0.0), tileZoom).y / 256.0)
          .ceil()
          .toDouble();
      _wrapY = Tuple2(first, second);
    }
  }
  void genrateVirtualGrids(){



    var pixelBounds = _getTiledPixelBounds(widget.map.center);
    var tileRange = _pxBoundsToTileRange(pixelBounds);
    var tileCenter = tileRange.getCenter();
    var queue = <Coords>[];

    // mark tiles as out of view...
    for (var key in _tiles.keys) {
      var c = _tiles[key].coords;
      if (c.z != _tileZoom) {
        _tiles[key].current = false;
      }
    }


    for (var j = tileRange.min.y; j <= tileRange.max.y; j++) {
      for (var i = tileRange.min.x; i <= tileRange.max.x; i++) {
        var coords = Coords(i.toDouble(), j.toDouble());
        coords.z = _tileZoom;

        if (!_isValidTile(coords)) {
          continue;
        }
        // Add all valid tiles to the queue on Flutter
        queue.add(coords);
      }
    }
    if (queue.isNotEmpty) {
      targetRequests = queue.length;
      activeRequests = 0;
      for (var i = 0; i < queue.length; i++) {

        var coords_new = _wrapCoords(queue[i]);


        var Bounds = _CoordsToBounds(coords_new);
        requestFeatures(Bounds);

      }
    }

  }
  LatLngBounds _CoordsToBounds (Coords coords) {
    var map = widget.map;
    var cellSize = 256.0;
    var nwPoint = coords.multiplyBy(cellSize);
    var sePoint = CustomPoint(nwPoint.x+cellSize, nwPoint.y+cellSize);
    var nw = map.unproject(nwPoint, coords.z);
    var se = map.unproject(sePoint, coords.z);
    return LatLngBounds(nw, se);
  }
  String _tileCoordsToKey(Coords coords) {
    return '${coords.x}:${coords.y}:${coords.z}';
  }
  bool _isValidTile(Coords coords) {
    var crs = widget.map.options.crs;
    if (!crs.infinite) {
      var bounds = _globalTileRange;
      if ((crs.wrapLng == null &&
          (coords.x < bounds.min.x || coords.x > bounds.max.x)) ||
          (crs.wrapLat == null &&
              (coords.y < bounds.min.y || coords.y > bounds.max.y))) {
        return false;
      }
    }
    return true;
  }
  void getMapState(){
  }
  void requestFeatures(LatLngBounds bounds) async {
    try {

      var bounds_ = '"xmin":${bounds.southWest.longitude},"ymin":${bounds.southWest.latitude},"xmax":${bounds.northEast.longitude},"ymax":${bounds.northEast.latitude}';

      var URL = '${widget.options.url}/query?f=json&geometry={"spatialReference":{"wkid":4326},${bounds_}}&maxRecordCountFactor=30&outFields=*&outSR=4326&resultType=tile&returnExceededLimitFeatures=false&spatialRel=esriSpatialRelIntersects&where=1=1&geometryType=esriGeometryEnvelope';

      Response response = await Dio().get(URL);

      var features_ =  <Marker>[];

      for (var feature in response.data["features"]) {
        features_.add(
            Marker(
              width: widget.options.marker.width,
              height: widget.options.marker.height,
              point: LatLng(feature["geometry"]["y"], feature["geometry"]["x"]),
              builder:(ctx) => Container(
                  child: GestureDetector(
                    onTap: () {
                        widget.options.onTap(feature["attributes"]);
                    },
                    child: widget.options.marker.builder(ctx),
                  )),
            )
        );
      }

      activeRequests++;

      if(activeRequests >= targetRequests){
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

    } catch (e) {
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {

    var markers = <Widget>[];
    if(features.isNotEmpty){
      for (var markerOpt in features) {
        var pos = widget.map.project(markerOpt.point);
        pos = pos.multiplyBy(widget.map.getZoomScale(widget.map.zoom, widget.map.zoom)) -
            widget.map.getPixelOrigin();

        var pixelPosX =
        (pos.x - (markerOpt.width - markerOpt.anchor.left)).toDouble();
        var pixelPosY =
        (pos.y - (markerOpt.height - markerOpt.anchor.top)).toDouble();

        if (!_boundsContainsMarker(markerOpt)) {
          continue;
        }

        markers.add(
          Positioned(
            width: markerOpt.width,
            height: markerOpt.height,
            left: pixelPosX,
            top: pixelPosY,
            child: markerOpt.builder(context),
          ),
        );
      }
    }

    return StreamBuilder<void>(
      stream: widget.stream, // a Stream<void> or null
      builder: (BuildContext context, _) {


//        return Container(
//          child: Stack(
//            children: markers,
//          ),
//        );
//
        return Container(
          child: Stack(
            children: markers,
          ),
        );
      },
    );
  }
}
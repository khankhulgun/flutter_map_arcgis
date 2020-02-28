import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map/plugin_api.dart';

import 'package:latlong/latlong.dart';
import 'tile_download_layer_options.dart';

import 'package:flutter_map/src/core/util.dart' as util;

import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter_range_slider/flutter_range_slider.dart' as frs;

import 'dart:async';

class TileDownloadLayer extends StatefulWidget {
  final TileDownloadLayerOptions options;
  final MapState map;
  final Stream<void> stream;

  TileDownloadLayer(this.options, this.map, this.stream);

  @override
  _TileDownloadLayerState createState() => _TileDownloadLayerState();
}

class _TileDownloadLayerState extends State<TileDownloadLayer> {
  double xPos = 0.0;
  double yPos = 0.0;
  double width = 0.0;
  double height = 0.0;
  bool _dragging = true;

  final Map<String, Tile> _tiles = {};
  final Map<double, Level> _levels = {};
  double _tileZoom;
  Bounds _globalTileRange;
  String _dir;

  /**/
  double _minZoom = 8;
  double _maxZoom = 12;
  double _downloadProgress = 0;
  bool _downloading = false;
  /**/

  @override
  initState() {
    super.initState();

  }

  @override
  void dispose() {
    super.dispose();
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

  void _setView(LatLng center, double zoom) {
    var tileZoom = _clampZoom(zoom.round().toDouble());
    if (_tileZoom != tileZoom) {
      _tileZoom = tileZoom;
    }

    var bounds = widget.map.getPixelWorldBounds(_tileZoom);
    if (bounds != null) {
      _globalTileRange = _pxBoundsToTileRange(bounds);
    }
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

  Future<File> moveFile(File sourceFile, String newPath) async {
    try {
      // prefer using rename as it is probably faster
      return await sourceFile.rename(newPath);
    } on FileSystemException catch (e) {
      // if rename fails, copy the source file and then delete it
      final newFile = await sourceFile.copy(newPath);
      await sourceFile.delete();
      return newFile;
    }
  }

  double getZoomScale(double toZoom, double fromZoom) {
    var crs = const Epsg3857();

    return crs.scale(toZoom) / crs.scale(fromZoom);
  }

  Bounds _getTiledPixelBounds(LatLng center) {
    return widget.map.getPixelBounds(_tileZoom);
  }

  Bounds getBounds(double zoom) {
    var sX = xPos + width;
    var sY = yPos + height;

    final offsetNo = Offset(xPos, yPos);
    final offsetSs = Offset(sX, sY);

    var No = _offsetToPoint2(offsetNo);
    var Se = _offsetToPoint2(offsetSs);

    var scale = getZoomScale(zoom, widget.map.zoom);

    return Bounds(No * scale, Se * scale);
  }

  Future<File> _downloadFile(String url, String filename, String dir) async {
    var req = await http.Client().get(Uri.parse(url));
    var file = File('$dir/$filename');
    return file.writeAsBytes(req.bodyBytes);
  }

  void genrateVirtualGrids(double zoom) async {
    _setView(widget.map.center, zoom);

    var pixelBounds = getBounds(zoom);

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
      if (_dir == null) {
        _dir = (await getApplicationDocumentsDirectory()).path;
      }

      await new Directory('${_dir}/offline_map').create()
          // The created directory is returned as a Future.
          .then((Directory directory) async {

        for (var i = 0; i < queue.length; i++) {
          String url = _createTileImage(queue[i]);

          await new Directory(
                  '${_dir}/offline_map/${queue[i].z.round().toString()}')
              .create()
              // The created directory is returned as a Future.
              .then((Directory directory) async {
            await new Directory(
                    '${_dir}/offline_map/${queue[i].z.round().toString()}/${queue[i].x.round().toString()}')
                .create()
                // The created directory is returned as a Future.
                .then((Directory directory) async {
              var savedTile = await _downloadFile(
                  url,
                  '${queue[i].y.round().toString()}.png',
                  '${_dir}/offline_map/${queue[i].z.round().toString()}/${queue[i].x.round().toString()}');

              print('${_dir}/offline_map/${queue[i].z.round().toString()}/${queue[i].x.round().toString()}');



            });
          });

//          var imageId = await ImageDownloader.downloadImage(
//              url, destination: AndroidDestinationType.custom()
//            ..inExternalFilesDir()
//            ..subDirectory(
//                "offline_map/${queue[i].z.round().toString()}/${queue[i].x
//                    .round()
//                    .toString()}/${queue[i].y.round().toString()}.png"));
//
//
//          var path = await ImageDownloader.findPath(imageId);
//          File sourceFile = File(path);
//          print(sourceFile);
//          print(url);

        }
      });
    }
  }

  CustomPoint _getTilePos(Coords coords) {
    var level = _levels[coords.z];
    return coords.scaleBy(CustomPoint(256.0, 256.0)) - level.origin;
  }

  String _tileCoordsToKey(Coords coords) {
    return '${coords.x}:${coords.y}:${coords.z}';
  }

  String getSubdomain(Coords coords, List<String> subdomains) {
    var index = (coords.x + coords.y).round() % subdomains.length;
    return subdomains[index];
  }

  String _createTileImage(Coords coords) {
    var data = <String, String>{
      'x': coords.x.round().toString(),
      'y': coords.y.round().toString(),
      'z': coords.z.round().toString(),
      's': getSubdomain(coords, widget.options.subdomains)
    };

    var allOpts = Map<String, String>.from(data);

    return util.template(widget.options.urlTemplate, allOpts);
  }

  LatLng _offsetToCrs(Offset offset) {
    // Get the widget's offset
    var renderObject = context.findRenderObject() as RenderBox;
    var width = renderObject.size.width;
    var height = renderObject.size.height;

    // convert the point to global coordinates
    var localPoint = _offsetToPoint(offset);
    var localPointCenterDistance =
        CustomPoint((width / 2) - localPoint.x, (height / 2) - localPoint.y);
    var mapCenter = widget.map.project(widget.map.center);
    var point = mapCenter - localPointCenterDistance;
    return widget.map.unproject(point);
  }

  Point _offsetToPoint2(Offset offset) {
    // Get the widget's offset
    var renderObject = context.findRenderObject() as RenderBox;
    var width = renderObject.size.width;
    var height = renderObject.size.height;

    // convert the point to global coordinates
    var localPoint = _offsetToPoint(offset);
    var localPointCenterDistance =
        CustomPoint((width / 2) - localPoint.x, (height / 2) - localPoint.y);
    var mapCenter = widget.map.project(widget.map.center);
    var point = mapCenter - localPointCenterDistance;
    return point;
  }

  CustomPoint _offsetToPoint(Offset offset) {
    return CustomPoint(offset.dx, offset.dy);
  }

  downloadTiles() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();


      var dir = (await getApplicationDocumentsDirectory()).path;

    setState((){
      _downloading = true;
      _dir = dir;

    });
    for( var i = _minZoom ; i <= _maxZoom; i++ ) {

      await genrateVirtualGrids(i);


      double maxPercent = 100.0;
      double zoomLevels = _maxZoom - _minZoom +1;
      double currentZoomLevel = i - _minZoom + 1;



      double currentPercent = (maxPercent/zoomLevels)*currentZoomLevel;

      setState(() {
        _downloadProgress = currentPercent;
      });

      if(currentPercent == 100.0){

        prefs.setDouble('offline_min_zoom', _minZoom);
        prefs.setDouble('offline_max_zoom', _maxZoom);
        prefs.setString('offline_template_url', "${_dir}/offline_map/{z}/{x}/{y}.png");
        AwesomeDialog(context: context,
            dialogType: DialogType.SUCCES,
            animType: AnimType.BOTTOMSLIDE,
            tittle: 'Амжилттай',
            btnOkText: 'За',
            desc: '${_minZoom} - ${_maxZoom} хүрээний суурь зураг татаж дууслаа',
            btnCancel:null,
            btnOkOnPress: () {

              setState((){
                xPos = 0.0;
                yPos = 0.0;
                width = 0.0;
                height = 0.0;
                _downloadProgress = 0.0;
                _dragging = false;
                _downloading = false;
              });

              widget.options.onSelected(false);

            }).show();
      }

    }

  }

  @override
  Widget build(BuildContext context) {
    if (!_dragging) {
      return LayoutBuilder(
        builder: (BuildContext context, BoxConstraints bc) {
          // TODO unused BoxContraints should remove?
          final size = Size(bc.maxWidth, bc.maxHeight);
          return _buildArea(context, size);
        },
      );
    } else {
      return LayoutBuilder(
        builder: (BuildContext context, BoxConstraints bc) {
          // TODO unused BoxContraints should remove?
          final size = Size(bc.maxWidth, bc.maxHeight);
          return _build(context, size);
        },
      );
    }
  }

  Widget _buildArea(BuildContext context, Size size) {
    var DownloadBtn = Container(
      child: Stack(children: [
        Positioned(
            top: 10,
            right: 10,
            child: Container(
                padding: const EdgeInsets.all(10.0),
                width: 250.0,
                decoration: BoxDecoration(
                    color: Colors.white70,
                    borderRadius: BorderRadius.all(
                      Radius.circular(5.0),
                    )),
                child: Column(children: <Widget>[
                  Container(
                    child: RaisedButton(
                      child: Text("Татах"),
                      onPressed: _downloading ? null : () {
                        downloadTiles();
                      },
                      color: Colors.blueAccent,
                      textColor: Colors.white,
                      padding: EdgeInsets.fromLTRB(10, 10, 10, 10),
                      splashColor: Colors.grey,
                    ),
                  ),

                  Text("Томруулах хүрээ"),
                  Container(
                    child: Row(
                      children: <Widget>[
                        Container(
                          constraints: BoxConstraints(
                            minWidth: 18.0,
                            maxWidth: 18.0,
                          ),
                          child: Text('${_minZoom.round().toString()}'),
                        ),
                        Expanded(
                          child: frs.RangeSlider(
                            min: 5,
                            max: 14,
                            lowerValue: _minZoom,
                            upperValue: _maxZoom,
                            divisions: 9,
                            showValueIndicator: true,
                            valueIndicatorFormatter: (int index, double value) {

                              return '${value.round().toString()}';
                            },
                            valueIndicatorMaxDecimals: 1,
                            onChanged: (double newLowerValue, double newUpperValue) {
                              setState(() {
                                _minZoom = newLowerValue;
                                _maxZoom = newUpperValue;
                              });
                            },

                          ),
                        ),
                        Container(
                          constraints: BoxConstraints(
                            minWidth: 18.0,
                            maxWidth: 18.0,
                          ),
                          child: Text('${_maxZoom.round().toString()}'),
                        ),
                      ],
                    ),
                  ),
                  new LinearPercentIndicator(
                    width: 230,
                    animation: true,
                    lineHeight: 20.0,
                    animationDuration: 2500,
                    percent: _downloadProgress.floor()/100.0,
                    center: Text("${_downloadProgress.round().toString()}%"),
                    linearStrokeCap: LinearStrokeCap.roundAll,
                    progressColor: Colors.green,
                  )
                ]))),
      ]),
    );

    var Empty = Container();

    return CustomPaint(
      painter: RectanglePainter(Rect.fromLTWH(xPos, yPos, width, height)),
      child: width >= 1 ? DownloadBtn : Empty,
      size: size,
    );
  }

  void saveData(LatLng latLngN, LatLng latLngS) async{
    SharedPreferences prefs = await SharedPreferences.getInstance();

    prefs.setDouble('offline_no_lat', latLngN.latitude);
    prefs.setDouble('offline_no_lng', latLngN.longitude);
    prefs.setDouble('offline_se_lat', latLngS.latitude);
    prefs.setDouble('offline_se_lng', latLngS.longitude);
  }
  Widget _build(BuildContext context, Size size) {
    return Container(
      child: Stack(
        children: [
          GestureDetector(
              onPanStart: (details) {
                setState(() {
                  RenderBox box = context.findRenderObject();
                  final offset = box.globalToLocal(details.globalPosition);
                  xPos = offset.dx;
                  yPos = offset.dy;
                });
                _dragging = true;
              },
              onPanEnd: (details)  {

                var sX = xPos + width;
                var sY = yPos + height;

                final offsetN = Offset(xPos, yPos);
                final offsetS = Offset(sX, sY);

                var latLngN = _offsetToCrs(offsetN);
                var latLngS = _offsetToCrs(offsetS);
//                print(latLngN);
//                print(latLngS);

                saveData(latLngN, latLngS);

                setState(() {
                  _dragging = false;

//                  widget.options.onSelected(false);
                });


              },
              onPanUpdate: (details) {
                if (_dragging) {
                  setState(() {
                    RenderBox box = context.findRenderObject();
                    final offset = box.globalToLocal(details.globalPosition);
                    width = offset.dx - xPos;
                    height = offset.dy - yPos;
                  });
                }
              },
              child: CustomPaint(
                painter:
                    RectanglePainter(Rect.fromLTWH(xPos, yPos, width, height)),
                child: Container(),
                size: size,
              ))
        ],
      ),
    );
  }
}

class RectanglePainter extends CustomPainter {
  RectanglePainter(this.rect);

  final Rect rect;

  @override
  void paint(Canvas canvas, Size size) {
//    var _paint = new Paint();
//
//    _paint.color = Colors.deepOrange;
////    _paint.color = Color(0x00000000);

    Paint _paint = new Paint()
      ..color = Colors.blueAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawRect(rect, _paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

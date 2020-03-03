import 'package:flutter/material.dart';
import 'package:flutter_map_arcgis/flutter_map_arcgis.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong/latlong.dart';



void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _platformVersion = 'Unknown';

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('ArcGIS')),
        body: Padding(
          padding: EdgeInsets.all(8.0),
          child: Column(
            children: [
              Flexible(
                child: FlutterMap(
                  options: MapOptions(
                    center: LatLng(40.000881, -96.2391999999999,),
                    zoom: 8.0,
                    plugins: [EsriPlugin()],

                  ),
                  layers: [
                    TileLayerOptions(
                      urlTemplate:
                      'http://{s}.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
                      subdomains: ['mt0', 'mt1', 'mt2', 'mt3'],
                      tileProvider: NonCachingNetworkTileProvider(),
                    ),
//                  MarkerLayerOptions(markers: markers),
                    FeatureLayerOptions(
                      url: "https://services.arcgis.com/P3ePLMYs2RVChkJx/arcgis/rest/services/USA_Congressional_Districts/FeatureServer/0",
//                      url: "https://dms.ulaanbaatar.mn/arcgis/rest/services/Manaikhoroo/Hot_standart1/FeatureServer/0",
//                      url: "https://dms.ulaanbaatar.mn/arcgis/rest/services/Manaikhoroo/Duureg_hil/FeatureServer/0",
                      geometryType:"polygon",
                      marker: Marker(
                        width: 30.0,
                        height: 30.0,
                        builder: (ctx) => Icon(Icons.pin_drop),
                      ),
                      onTap: (attributes, LatLng location) {
                        print(attributes);
                      },
                      polygonOptions: PolygonOptions(
                          borderColor: Colors.blueAccent,
                          color: Colors.black12,
                          borderStrokeWidth: 2),
                    ),

                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

# Flutter Map plugin for ArcGIS Esri

# Currently support feature layer(point, polygon, polyline)
We are working on more features

A Dart implementation of Esri Leaflet for Flutter apps.
This is a plugin for [flutter_map](https://github.com/johnpryan/flutter_map) package


## Usage

Add flutter_map, dio and  flutter_map_arcgis to your pubspec:

```yaml
dependencies:
  flutter_map: any
  flutter_map_arcgis: any # or the latest version on Pub
  dio: any # or the latest version on Pub
```

Add it in you FlutterMap and configure it using `FeatureLayerOptions`.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_map_arcgis/flutter_map_arcgis.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {

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
                    // center: LatLng(39.7644863,-105.0199111), // line
                    center: LatLng(35.611909, -82.440682),
                    zoom: 14.0,


                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                      'http://{s}.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
                      subdomains: ['mt0', 'mt1', 'mt2', 'mt3'],
                    ),
                    // FeatureLayer(FeatureLayerOptions("https://services.arcgis.com/P3ePLMYs2RVChkJx/arcgis/rest/services/USA_Congressional_Districts/FeatureServer/0",
                    //   "polygon",
                    //   onTap: (dynamic attributes, LatLng location) {
                    //     print(attributes);
                    //   },
                    //   render: (dynamic attributes){
                    //     return PolygonOptions(
                    //         borderColor: Colors.red,
                    //         color: Colors.black45,
                    //         borderStrokeWidth: 2,
                    //         isFilled:true
                    //     );
                    //   },
                    // ),)
                    FeatureLayer(
                        FeatureLayerOptions(
                          "https://services.arcgis.com/V6ZHFr6zdgNZuVG0/arcgis/rest/services/Landscape_Trees/FeatureServer/0",
                          "point",
                          render:(dynamic attributes){
                            // You can render by attribute
                            return PointOptions(
                              width: 30.0,
                              height: 30.0,
                              builder: const Icon(Icons.pin_drop),
                            );
                          },
                          onTap: (attributes, LatLng location) {
                            print(attributes);
                          },
                        )
                    ),
                    // FeatureLayer(FeatureLayerOptions(
                    //   "https://services.arcgis.com/V6ZHFr6zdgNZuVG0/ArcGIS/rest/services/Denver_Streets_Centerline/FeatureServer/0",
                    //   "polyline",
                    //   render:(dynamic attributes){
                    //     // You can render by attribute
                    //     return PolygonLineOptions(
                    //         borderColor: Colors.red,
                    //         color: Colors.red,
                    //         borderStrokeWidth: 2
                    //     );
                    //   },
                    //   onTap: (attributes, LatLng location) {
                    //     print(attributes);
                    //   },
                    // ))

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


```

### Run the example

See the `example/` folder for a working example app.

# Flutter Map plugin for ArcGIS Esri

# Currently support feature layer(point, polygon, polyline coming soon)
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
                      center: LatLng(32.91081899999999, -92.734876),
                      zoom: 11.0,
                      plugins: [EsriPlugin()],
  
                    ),
                    layers: [
                      TileLayerOptions(
                        urlTemplate:
                        'http://{s}.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
                        subdomains: ['mt0', 'mt1', 'mt2', 'mt3'],
                        tileProvider: NonCachingNetworkTileProvider(),
                      ),
                      FeatureLayerOptions(
                        url: "https://services.arcgis.com/P3ePLMYs2RVChkJx/arcgis/rest/services/USA_Congressional_Districts/FeatureServer/0",
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
                      FeatureLayerOptions(
                        url: "https://services8.arcgis.com/1p2fLWyjYVpl96Ty/arcgis/rest/services/Forest_Service_Recreation_Opportunities/FeatureServer/0",
                        geometryType:"point",
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
```

### Run the example

See the `example/` folder for a working example app.

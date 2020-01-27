# Flutter Map plugin for ArcGIS Esri

# Currently support feature layer and feature cluster
We are working on more features

A Dart implementation of Esri Leaflet for Flutter apps.
This is a plugin for [flutter_map](https://github.com/johnpryan/flutter_map) package

Feature layer's cluster Inspired by [flutter_map_marker_cluster](https://github.com/lpongetti/flutter_map_marker_cluster) package


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
    return FlutterMap(
      options: new MapOptions(
        center: LatLng(47.9187, 106.917782),
        zoom: 13.0,
        plugins: [
          EsriPlugin(),
        ],
      ),
      layers: [
        TileLayerOptions(
          urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
          subdomains: ['a', 'b', 'c'],
        ),
        FeatureLayerOptions(
          geometryType:"point",
          url:"https://dms.ulaanbaatar.mn/arcgis/rest/services/Manaikhoroo/Hot_standart1/FeatureServer/0",
          marker: Marker(
             width: 30.0,
             height: 30.0,
             builder: (ctx) => Icon(Icons.pin_drop),
          ),
          onTap: (attributes) {
             print(attributes);
          },
      ],
    );
  }
```

### Run the example

See the `example/` folder for a working example app.

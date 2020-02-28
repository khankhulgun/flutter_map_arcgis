import 'package:flutter/material.dart';
import 'package:flutter_map/plugin_api.dart';
import 'tileDownloader/tile_download_layer.dart';
import 'tileDownloader/tile_download_layer_options.dart';

class TileDownloaderPlugin extends MapPlugin {
  @override
  Widget createLayer(
      LayerOptions options, MapState mapState, Stream<void> stream) {
    return TileDownloadLayer(options, mapState, stream);
  }

  @override
  bool supportsLayer(LayerOptions options) {
    return options is TileDownloadLayerOptions;
  }
}
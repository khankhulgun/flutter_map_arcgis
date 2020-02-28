import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map/plugin_api.dart';


class TileDownloadLayerOptions extends LayerOptions {

  final Color color;
  final bool draw;
  final void Function(dynamic attributes) onSelected;
  String urlTemplate;
  List<String> subdomains;

  TileDownloadLayerOptions({
    this.color,
    this.draw,
    this.onSelected,
    this.urlTemplate,
    this.subdomains,
  });
}
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
class PolygonOptions {
  final Color color;
  final double borderStrokeWidth;
  final Color borderColor;
  final bool isDotted;
  final bool isFilled;

  const PolygonOptions({
    this.color = const Color(0xFF00FF00),
    this.borderStrokeWidth = 0.0,
    this.borderColor = const Color(0xFFFFFF00),
    this.isDotted = false,
    this.isFilled = false,
  });
}
class PolygonLineOptions {
  final Color color;
  final double borderStrokeWidth;
  final Color borderColor;
  final bool isDotted;

  const PolygonLineOptions({
    this.color = const Color(0xFF00FF00),
    this.borderStrokeWidth = 0.0,
    this.borderColor = const Color(0xFFFFFF00),
    this.isDotted = false,
  });
}

class PointOptions {
  final double width;
  final double height;
  final Widget builder;
  final Alignment? alignment;
  const PointOptions({
    this.width = 30.0,
    this.height = 30.0,
    this.alignment,
    this.builder = const Icon(Icons.pin_drop),
  });
}

class AnimationsOptions {
  final Duration zoom;
  final Duration fitBound;
  final Curve fitBoundCurves;
  final Duration centerMarker;
  final Curve centerMarkerCurves;
  final Duration spiderfy;

  const AnimationsOptions({
    this.zoom = const Duration(milliseconds: 500),
    this.fitBound = const Duration(milliseconds: 500),
    this.centerMarker = const Duration(milliseconds: 500),
    this.spiderfy = const Duration(milliseconds: 500),
    this.fitBoundCurves = Curves.fastOutSlowIn,
    this.centerMarkerCurves = Curves.fastOutSlowIn,
  });
}

typedef ClusterWidgetBuilder = Widget Function(
    BuildContext context, List<Marker> markers);

class FeatureLayerOptions  {
  /// Cluster size
  final Size size;

  /// Cluster compute size
  final Size Function(List<Marker>)? computeSize;

  /// Cluster anchor
  final Alignment? alignment;

  /// A cluster will cover at most this many pixels from its center
  final int maxClusterRadius;

  /// Feature layer URL
  final String url;

  /// Feature layer URL
  final String geometryType;

  /// Options for fit bounds
  final FitBoundsOptions fitBoundsOptions;

  /// Zoom buonds with animation on click cluster
  final bool zoomToBoundsOnClick;

  /// animations options
  final AnimationsOptions animationsOptions;

  /// When click marker, center it with animation
  final bool centerMarkerOnClick;

  /// Increase to increase the distance away that circle spiderfied markers appear from the center
  final int spiderfyCircleRadius;

  /// Increase to increase the distance away that spiral spiderfied markers appear from the center
  final int spiderfySpiralDistanceMultiplier;

  /// Show spiral instead of circle from this marker count upwards.
  /// 0 -> always spiral; Infinity -> always circle
  final int circleSpiralSwitchover;

  /// Make it possible to provide custom function to calculate spiderfy shape positions
  final List<Point> Function(int, Point)? spiderfyShapePositions;

  /// Render
  final dynamic Function(dynamic attributes)? render;

  /// Function to call when a Marker is tapped
  final void Function(dynamic attributes, LatLng location)? onTap;

  FeatureLayerOptions(
      this.url,
      this.geometryType,{
    this.size = const Size(30, 30),
    this.computeSize,
    this.alignment,
    this.maxClusterRadius = 80,
    this.animationsOptions = const AnimationsOptions(),
    this.fitBoundsOptions =
        const FitBoundsOptions(padding: EdgeInsets.all(12.0)),
    this.zoomToBoundsOnClick = true,
    this.centerMarkerOnClick = true,
    this.spiderfyCircleRadius = 40,
    this.spiderfySpiralDistanceMultiplier = 1,
    this.circleSpiralSwitchover = 9,
    this.spiderfyShapePositions,
    this.onTap,
    this.render,
  });
}

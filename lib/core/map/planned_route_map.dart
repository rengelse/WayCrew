import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../app/app_theme.dart';
import '../../domain/models/activity_models.dart';

class PlannedRouteMap extends StatefulWidget {
  final ActivityRoutePlan route;
  final List<ActivityRouteStop> stops;
  final bool compact;

  const PlannedRouteMap({super.key, required this.route, this.stops = const [], this.compact = false});

  @override
  State<PlannedRouteMap> createState() => _PlannedRouteMapState();
}

class _PlannedRouteMapState extends State<PlannedRouteMap> {
  static const _style = 'https://tiles.openfreemap.org/styles/liberty';
  MapLibreMapController? _controller;
  bool _ready = false;

  @override
  void didUpdateWidget(covariant PlannedRouteMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_ready && (oldWidget.route != widget.route || oldWidget.stops != widget.stops)) _render();
  }

  @override
  Widget build(BuildContext context) {
    final center = widget.route.points.isEmpty ? const LatLng(58.9690, 5.7331) : _center(widget.route.points);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTokens.radiusLg),
      child: MapLibreMap(
        styleString: _style,
        initialCameraPosition: CameraPosition(target: center, zoom: _zoom(widget.route.points)),
        compassEnabled: true,
        tiltGesturesEnabled: false,
        logoEnabled: false,
        attributionButtonPosition: AttributionButtonPosition.bottomLeft,
        onMapCreated: (controller) => _controller = controller,
        onStyleLoadedCallback: () {
          _ready = true;
          _render();
        },
      ),
    );
  }

  Future<void> _render() async {
    final c = _controller;
    if (c == null || !_ready) return;
    await c.clearLines();
    await c.clearSymbols();
    if (widget.route.points.length >= 2) {
      await c.addLine(LineOptions(
        geometry: [for (final p in widget.route.points) LatLng(p.latitude, p.longitude)],
        lineColor: '#16A34A',
        lineWidth: 5.5,
        lineOpacity: 0.92,
      ));
    }
    for (final stop in widget.stops) {
      final label = switch (stop.type) {
        'start' => 'Start · ${stop.name}',
        'destination' => 'Mål · ${stop.name}',
        'waypoint' => stop.name,
        'meeting' => 'Oppmøte · ${stop.name}',
        _ => stop.name,
      };
      await c.addSymbol(SymbolOptions(
        geometry: LatLng(stop.latitude, stop.longitude),
        textField: label,
        textSize: 12,
        textColor: '#17202A',
        textHaloColor: '#FFFFFF',
        textHaloWidth: 2.5,
        textAnchor: 'bottom',
        textOffset: const Offset(0, -0.8),
      ));
    }
    if (widget.route.points.isNotEmpty) {
      await c.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: _center(widget.route.points), zoom: _zoom(widget.route.points))));
    }
  }

  double _zoom(List<RouteCoordinate> points) {
    if (points.length < 2) return 11;
    var minLat = points.first.latitude, maxLat = points.first.latitude;
    var minLon = points.first.longitude, maxLon = points.first.longitude;
    for (final p in points.skip(1)) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLon) minLon = p.longitude;
      if (p.longitude > maxLon) maxLon = p.longitude;
    }
    final span = (maxLat - minLat).abs() > (maxLon - minLon).abs() ? (maxLat - minLat).abs() : (maxLon - minLon).abs();
    if (span > 6) return 4.2;
    if (span > 3) return 5.0;
    if (span > 1.5) return 5.8;
    if (span > .7) return 6.6;
    if (span > .3) return 7.4;
    if (span > .12) return 8.3;
    if (span > .05) return 9.2;
    return widget.compact ? 10.6 : 11.2;
  }

  LatLng _center(List<RouteCoordinate> points) {
    var lat = 0.0, lon = 0.0;
    for (final p in points) { lat += p.latitude; lon += p.longitude; }
    return LatLng(lat / points.length, lon / points.length);
  }
}

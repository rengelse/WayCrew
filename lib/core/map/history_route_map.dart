import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../app/app_theme.dart';
import '../../domain/models/activity_models.dart';

class HistoryRouteMap extends StatefulWidget {
  final List<RouteHistoryPoint> points;
  const HistoryRouteMap({super.key, required this.points});

  @override
  State<HistoryRouteMap> createState() => _HistoryRouteMapState();
}

class _HistoryRouteMapState extends State<HistoryRouteMap> {
  static const _style = 'https://tiles.openfreemap.org/styles/liberty';
  MapLibreMapController? _controller;
  bool _ready = false;

  LatLng get _center {
    if (widget.points.isEmpty) return const LatLng(58.9690, 5.7331);
    final lat = widget.points.fold<double>(0, (s, p) => s + p.latitude) / widget.points.length;
    final lon = widget.points.fold<double>(0, (s, p) => s + p.longitude) / widget.points.length;
    return LatLng(lat, lon);
  }

  @override
  void didUpdateWidget(covariant HistoryRouteMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_ready && oldWidget.points != widget.points) _render();
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(AppTokens.radiusLg),
    child: MapLibreMap(
      styleString: _style,
      initialCameraPosition: CameraPosition(target: _center, zoom: 12),
      logoEnabled: false,
      attributionButtonPosition: AttributionButtonPosition.bottomLeft,
      onMapCreated: (c) => _controller = c,
      onStyleLoadedCallback: () { _ready = true; _render(); },
    ),
  );

  Future<void> _render() async {
    final c = _controller;
    if (c == null || !_ready || widget.points.length < 2) return;
    await c.clearLines();
    await c.clearSymbols();
    final geometry = widget.points.map((p) => LatLng(p.latitude, p.longitude)).toList();
    await c.addLine(LineOptions(geometry: geometry, lineColor: '#168A5B', lineWidth: 4.5, lineOpacity: .9));
    await c.addSymbol(SymbolOptions(geometry: geometry.first, textField: 'Start', textColor: '#17202A', textHaloColor: '#FFFFFF', textHaloWidth: 3));
    await c.addSymbol(SymbolOptions(geometry: geometry.last, textField: 'Slutt', textColor: '#17202A', textHaloColor: '#FFFFFF', textHaloWidth: 3));
  }
}

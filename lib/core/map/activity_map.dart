import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../app/app_theme.dart';
import '../../domain/models/activity_models.dart';

class ActivityMap extends StatefulWidget {
  final List<Activity> activities;
  final String? selectedActivityId;
  final ValueChanged<Activity>? onActivityTap;
  final bool compact;
  final Map<String, ActivityPublicState> publicStates;

  const ActivityMap({
    super.key,
    required this.activities,
    this.selectedActivityId,
    this.onActivityTap,
    this.compact = false,
    this.publicStates = const {},
  });

  @override
  State<ActivityMap> createState() => _ActivityMapState();
}

class _ActivityMapState extends State<ActivityMap> {
  MapLibreMapController? _controller;
  final Map<String, Activity> _symbolActivities = {};
  bool _styleReady = false;

  static const _mapStyle = 'https://tiles.openfreemap.org/styles/liberty';
  static const _fallbackCenter = LatLng(58.9690, 5.7331);

  @override
  void didUpdateWidget(covariant ActivityMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_styleReady && (oldWidget.activities != widget.activities || oldWidget.publicStates != widget.publicStates || oldWidget.selectedActivityId != widget.selectedActivityId)) {
      _renderActivities();
    }
  }

  @override
  Widget build(BuildContext context) {
    final routeActivity = widget.activities.where((a) => a.id == widget.selectedActivityId).firstOrNull ?? (widget.activities.length == 1 ? widget.activities.first : null);
    final center = routeActivity != null && routeActivity.routePlan.hasGeometry ? _centerForRoute(routeActivity.routePlan.points) : _centerForActivities(widget.activities);
    final initialZoom = routeActivity != null && routeActivity.routePlan.hasGeometry ? _zoomForRoute(routeActivity.routePlan.points, compact: widget.compact) : (widget.compact ? 9.7 : 8.7);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTokens.radiusLg),
      child: Stack(
        children: [
          Positioned.fill(
            child: MapLibreMap(
              key: const ValueKey('map-liberty'),
              styleString: _mapStyle,
              initialCameraPosition: CameraPosition(
                target: center,
                zoom: initialZoom,
              ),
              compassEnabled: true,
              rotateGesturesEnabled: true,
              tiltGesturesEnabled: false,
              logoEnabled: false,
              attributionButtonPosition: AttributionButtonPosition.bottomLeft,
              onMapCreated: (controller) {
                _controller = controller;
                controller.onSymbolTapped.add(_onSymbolTapped);
              },
              onStyleLoadedCallback: () {
                _styleReady = true;
                _renderActivities();
              },
            ),
          ),
          Positioned(
            right: 12,
            top: 12,
            child: Material(
              color: Theme.of(context).colorScheme.surface.withValues(alpha: .94),
              borderRadius: BorderRadius.circular(12),
              child: IconButton(
                tooltip: 'Vis aktiviteter',
                icon: const Icon(Icons.my_location_rounded),
                onPressed: _fitActivities,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _renderActivities() async {
    final controller = _controller;
    if (controller == null || !_styleReady) return;

    await controller.clearSymbols();
    await controller.clearLines();
    _symbolActivities.clear();

    final selectedActivity = widget.activities.where((a) => a.id == widget.selectedActivityId).firstOrNull;
    final routeActivity = selectedActivity ?? (widget.activities.length == 1 ? widget.activities.first : null);
    if (routeActivity != null && routeActivity.routePlan.hasGeometry) {
      await controller.addLine(LineOptions(
        geometry: [for (final p in routeActivity.routePlan.points) LatLng(p.latitude, p.longitude)],
        lineColor: '#16A34A',
        lineWidth: 5.0,
        lineOpacity: 0.9,
      ));
    }

    for (final activity in widget.activities) {
      final selected = activity.id == widget.selectedActivityId;
      final symbol = await controller.addSymbol(
        SymbolOptions(
          geometry: _locationFor(activity),
          textField: '${activity.kind.label} ${activity.confirmedParticipants}',
          textSize: selected ? 16 : 14,
          textColor: selected ? '#0B5C3B' : '#17202A',
          textHaloColor: '#FFFFFF',
          textHaloWidth: 2.5,
          textAnchor: 'center',
          textOffset: const Offset(0, 0),
          zIndex: selected ? 10 : 5,
        ),
      );
      _symbolActivities[symbol.id] = activity;
    }
  }

  void _onSymbolTapped(Symbol symbol) {
    final activity = _symbolActivities[symbol.id];
    if (activity != null) widget.onActivityTap?.call(activity);
  }

  Future<void> _fitActivities() async {
    final controller = _controller;
    if (controller == null) return;
    final routeActivity = widget.activities.where((a) => a.id == widget.selectedActivityId).firstOrNull ?? (widget.activities.length == 1 ? widget.activities.first : null);
    final hasRoute = routeActivity != null && routeActivity.routePlan.hasGeometry;
    final center = hasRoute ? _centerForRoute(routeActivity.routePlan.points) : _centerForActivities(widget.activities);
    await controller.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(
      target: center,
      zoom: hasRoute ? _zoomForRoute(routeActivity.routePlan.points, compact: widget.compact) : (widget.activities.length <= 1 ? 11.2 : 8.7),
    )));
  }

  LatLng _centerForActivities(List<Activity> items) {
    if (items.isEmpty) return _fallbackCenter;
    var lat = 0.0;
    var lon = 0.0;
    for (final item in items) {
      final point = _locationFor(item);
      lat += point.latitude;
      lon += point.longitude;
    }
    return LatLng(lat / items.length, lon / items.length);
  }

  LatLng _centerForRoute(List<RouteCoordinate> points) {
    if (points.isEmpty) return _fallbackCenter;
    var lat = 0.0, lon = 0.0;
    for (final p in points) { lat += p.latitude; lon += p.longitude; }
    return LatLng(lat / points.length, lon / points.length);
  }

  double _zoomForRoute(List<RouteCoordinate> points, {required bool compact}) {
    if (points.length < 2) return compact ? 11.0 : 10.0;
    var minLat = points.first.latitude, maxLat = points.first.latitude;
    var minLon = points.first.longitude, maxLon = points.first.longitude;
    for (final p in points.skip(1)) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLon) minLon = p.longitude;
      if (p.longitude > maxLon) maxLon = p.longitude;
    }
    final span = (maxLat - minLat).abs() > (maxLon - minLon).abs() ? (maxLat - minLat).abs() : (maxLon - minLon).abs();
    if (span > 12) return 3.2;
    if (span > 6) return 4.2;
    if (span > 3) return 5.0;
    if (span > 1.5) return 5.8;
    if (span > .7) return 6.6;
    if (span > .3) return 7.4;
    if (span > .12) return 8.3;
    if (span > .05) return 9.2;
    return compact ? 10.6 : 11.2;
  }

  LatLng _locationFor(Activity activity) {
    final live = widget.publicStates[activity.id];
    if (live != null && !live.isStale) return LatLng(live.latitude, live.longitude);
    final routeStart = activity.routeStops.where((s) => s.type == 'start').firstOrNull;
    if (routeStart != null) return LatLng(routeStart.latitude, routeStart.longitude);
    if (activity.meetingLatitude != null && activity.meetingLongitude != null) {
      return LatLng(activity.meetingLatitude!, activity.meetingLongitude!);
    }
    return switch (activity.id) {
      'a1' => const LatLng(58.9704, 5.7318),
      'a4' => const LatLng(58.8906, 5.7298),
      'a2' => const LatLng(58.8616, 6.8489),
      'a3' => const LatLng(58.9864, 6.1906),
      _ => _generatedLocation(activity.id),
    };
  }

  LatLng _generatedLocation(String id) {
    final hash = id.codeUnits.fold<int>(0, (value, char) => (value * 31 + char) & 0x7fffffff);
    final latOffset = ((hash % 700) - 350) / 10000;
    final lonOffset = (((hash ~/ 700) % 900) - 450) / 10000;
    return LatLng(_fallbackCenter.latitude + latOffset, _fallbackCenter.longitude + lonOffset);
  }
}

extension _FirstOrNull<E> on Iterable<E> { E? get firstOrNull => isEmpty ? null : first; }

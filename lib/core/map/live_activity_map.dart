import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../app/app_theme.dart';
import '../../domain/models/activity_models.dart';

class LiveActivityMap extends StatefulWidget {
  final List<LiveParticipantPosition> positions;
  final ActivityPublicState? publicState;
  final Map<String, String> participantNames;
  final String? currentUserId;
  final ActivityRoutePlan route;
  final ActivityKind activityKind;

  const LiveActivityMap({
    super.key,
    required this.positions,
    required this.participantNames,
    this.publicState,
    this.currentUserId,
    this.route = const ActivityRoutePlan(),
    this.activityKind = ActivityKind.other,
  });

  @override
  State<LiveActivityMap> createState() => _LiveActivityMapState();
}

class _LiveActivityMapState extends State<LiveActivityMap> {
  static const _mapStyle = 'https://tiles.openfreemap.org/styles/liberty';
  static const _fallbackCenter = LatLng(58.9690, 5.7331);

  MapLibreMapController? _controller;
  bool _styleReady = false;

  @override
  void didUpdateWidget(covariant LiveActivityMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_styleReady && (oldWidget.positions != widget.positions || oldWidget.publicState != widget.publicState || oldWidget.route != widget.route)) {
      _render();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTokens.radiusLg),
      child: Stack(
        children: [
          Positioned.fill(
            child: MapLibreMap(
              key: const ValueKey('live-map-liberty'),
              styleString: _mapStyle,
              initialCameraPosition: CameraPosition(target: _center, zoom: 12.2),
              compassEnabled: true,
              rotateGesturesEnabled: true,
              tiltGesturesEnabled: false,
              logoEnabled: false,
              attributionButtonPosition: AttributionButtonPosition.bottomLeft,
              onMapCreated: (controller) => _controller = controller,
              onStyleLoadedCallback: () {
                _styleReady = true;
                _render();
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
                tooltip: 'Sentrer på gruppen',
                icon: const Icon(Icons.center_focus_strong),
                onPressed: _fit,
              ),
            ),
          ),
        ],
      ),
    );
  }

  LatLng get _center {
    final fresh = widget.positions.where((p) => p.sharing && !p.isStale).toList();
    if (fresh.isNotEmpty) {
      final lat = fresh.fold<double>(0, (sum, p) => sum + p.latitude) / fresh.length;
      final lon = fresh.fold<double>(0, (sum, p) => sum + p.longitude) / fresh.length;
      return LatLng(lat, lon);
    }
    final publicState = widget.publicState;
    if (publicState != null) return LatLng(publicState.latitude, publicState.longitude);
    return _fallbackCenter;
  }

  Future<void> _render() async {
    final controller = _controller;
    if (controller == null || !_styleReady) return;
    await controller.clearSymbols();
    await controller.clearLines();
    if (widget.route.hasGeometry) {
      await controller.addLine(LineOptions(
        geometry: [for (final p in widget.route.points) LatLng(p.latitude, p.longitude)],
        lineColor: '#16A34A',
        lineWidth: 5.0,
        lineOpacity: 0.86,
      ));
    }

    final publicState = widget.publicState;
    if (publicState != null && !publicState.isStale) {
      await controller.addSymbol(SymbolOptions(
        geometry: LatLng(publicState.latitude, publicState.longitude),
        textField: 'Gruppe · ${publicState.participantCount}',
        textSize: 13,
        textColor: '#17202A',
        textHaloColor: '#FFFFFF',
        textHaloWidth: 3,
        textAnchor: 'bottom',
        textOffset: const Offset(0, -1.2),
        zIndex: 4,
      ));
    }

    for (final position in widget.positions.where((p) => p.sharing)) {
      final mine = position.userId == widget.currentUserId;
      final name = widget.participantNames[position.userId] ?? 'Deltaker';
      final role = switch (position.role) {
        ParticipantRole.leader => 'Leder',
        ParticipantRole.sweep => 'Baktropp',
        ParticipantRole.participant => name,
      };
      final freshness = position.isStale ? ' · gammel' : '';
      final displayName = mine ? 'Du' : role;
      await controller.addSymbol(SymbolOptions(
        geometry: LatLng(position.latitude, position.longitude),
        textField: '${_activityMarker(widget.activityKind)}\n$displayName$freshness',
        textSize: mine ? 15 : 13,
        textColor: position.isStale ? '#6B7280' : (mine ? '#0B5C3B' : '#17202A'),
        textHaloColor: '#FFFFFF',
        textHaloWidth: 3,
        textAnchor: 'center',
        zIndex: mine ? 12 : position.role == ParticipantRole.leader ? 10 : 8,
      ));
    }
  }

  String _activityMarker(ActivityKind kind) => switch (kind) {
        ActivityKind.motorcycle => '🏍️',
        ActivityKind.ski => '⛷️',
        ActivityKind.cycling => '🚵',
        ActivityKind.hiking => '🥾',
        ActivityKind.running => '🏃',
        ActivityKind.kayak => '🛶',
        ActivityKind.climbing => '🧗',
        ActivityKind.other => '📍',
      };

  Future<void> _fit() async {
    final controller = _controller;
    if (controller == null) return;
    await controller.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: _center, zoom: 12.2)));
  }
}

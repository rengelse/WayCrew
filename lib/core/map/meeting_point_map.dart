import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

class MeetingPointMap extends StatefulWidget {
  final double latitude;
  final double longitude;
  final ValueChanged<LatLng>? onPositionChanged;

  const MeetingPointMap({
    super.key,
    required this.latitude,
    required this.longitude,
    this.onPositionChanged,
  });

  @override
  State<MeetingPointMap> createState() => _MeetingPointMapState();
}

class _MeetingPointMapState extends State<MeetingPointMap> {
  static const _mapStyle = 'https://tiles.openfreemap.org/styles/liberty';
  MapLibreMapController? _controller;
  bool _styleReady = false;
  Symbol? _pin;

  LatLng get _point => LatLng(widget.latitude, widget.longitude);

  @override
  void didUpdateWidget(covariant MeetingPointMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_styleReady && (oldWidget.latitude != widget.latitude || oldWidget.longitude != widget.longitude)) {
      _showPoint(animate: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 220,
        child: Stack(
          children: [
            Positioned.fill(
              child: MapLibreMap(
                styleString: _mapStyle,
                initialCameraPosition: CameraPosition(target: _point, zoom: 14.5),
                compassEnabled: true,
                tiltGesturesEnabled: false,
                logoEnabled: false,
                attributionButtonPosition: AttributionButtonPosition.bottomLeft,
                onMapCreated: (controller) => _controller = controller,
                onStyleLoadedCallback: () {
                  _styleReady = true;
                  _showPoint();
                },
                onMapClick: (screenPoint, latLng) {
                  widget.onPositionChanged?.call(latLng);
                },
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface.withValues(alpha: .92),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    child: Text('Trykk i kartet for å finjustere oppmøtepunktet', textAlign: TextAlign.center),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPoint({bool animate = false}) async {
    final controller = _controller;
    if (controller == null || !_styleReady) return;
    if (_pin != null) await controller.removeSymbol(_pin!);
    _pin = await controller.addSymbol(SymbolOptions(
      geometry: _point,
      textField: '●',
      textSize: 34,
      textColor: '#168A5B',
      textHaloColor: '#FFFFFF',
      textHaloWidth: 3,
      textAnchor: 'center',
    ));
    if (animate) {
      await controller.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: _point, zoom: 14.5)));
    }
  }
}

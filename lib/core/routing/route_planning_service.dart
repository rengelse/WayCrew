import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../../domain/models/activity_models.dart';
import '../geocoding/place_search_service.dart';

class PlannedRoute {
  final List<RouteCoordinate> points;
  final double distanceKm;
  final int durationMinutes;
  final String profile;
  final String provider;

  const PlannedRoute({
    required this.points,
    required this.distanceKm,
    required this.durationMinutes,
    required this.profile,
    required this.provider,
  });

  Map<String, dynamic> toGeoJson() => {
        'type': 'LineString',
        'coordinates': [for (final p in points) [p.longitude, p.latitude]],
      };
}

class RoutePlanningException implements Exception {
  final String message;
  const RoutePlanningException(this.message);
  @override
  String toString() => message;
}

class RoutePlanningService {
  static const _endpoint = 'https://valhalla1.openstreetmap.de/route';

  Future<PlannedRoute> plan({
    required ActivityKind kind,
    required PlaceSearchResult start,
    required PlaceSearchResult destination,
    List<PlaceSearchResult> waypoints = const [],
  }) async {
    final locations = [start, ...waypoints, destination];
    if (locations.length < 2) throw const RoutePlanningException('Ruten trenger minst start og destinasjon.');

    if (kind == ActivityKind.kayak || kind == ActivityKind.ski) {
      return _manualRoute(locations, kind);
    }

    final costing = _costingFor(kind);
    final payload = {
      'locations': [for (final p in locations) {'lat': p.latitude, 'lon': p.longitude, 'type': 'break'}],
      'costing': costing,
      'units': 'kilometers',
      'shape_format': 'geojson',
      'directions_type': 'none',
    };

    http.Response response;
    try {
      response = await http
          .post(
            Uri.parse(_endpoint),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'User-Agent': 'WayCrew/0.3.0',
              'X-Client-Id': 'waycrew.app',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 18));
    } catch (_) {
      throw const RoutePlanningException('Ruteberegning er ikke tilgjengelig akkurat nå. Prøv igjen.');
    }

    if (response.statusCode != 200) {
      throw RoutePlanningException('Kunne ikke beregne rute (${response.statusCode}).');
    }

    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) throw const RoutePlanningException('Ugyldig svar fra rutetjenesten.');
    final trip = body['trip'];
    if (trip is! Map<String, dynamic>) throw const RoutePlanningException('Rutetjenesten fant ingen rute.');

    final summary = trip['summary'] is Map<String, dynamic> ? trip['summary'] as Map<String, dynamic> : const <String, dynamic>{};
    final distance = (summary['length'] as num?)?.toDouble() ?? 0;
    final seconds = (summary['time'] as num?)?.toDouble() ?? 0;
    final points = _extractGeoJsonPoints(trip);
    if (points.length < 2) throw const RoutePlanningException('Ruten mangler kartgeometri.');

    return PlannedRoute(
      points: points,
      distanceKm: distance,
      durationMinutes: (seconds / 60).round(),
      profile: costing,
      provider: 'Valhalla / OpenStreetMap',
    );
  }

  String _costingFor(ActivityKind kind) => switch (kind) {
        ActivityKind.motorcycle => 'motorcycle',
        ActivityKind.cycling => 'bicycle',
        ActivityKind.hiking || ActivityKind.running || ActivityKind.climbing => 'pedestrian',
        ActivityKind.ski || ActivityKind.kayak => 'pedestrian',
        ActivityKind.other => 'auto',
      };

  PlannedRoute _manualRoute(List<PlaceSearchResult> locations, ActivityKind kind) {
    final points = [for (final p in locations) RouteCoordinate(latitude: p.latitude, longitude: p.longitude)];
    var distance = 0.0;
    for (var i = 1; i < points.length; i++) {
      distance += _haversineKm(points[i - 1], points[i]);
    }
    final speed = kind == ActivityKind.kayak ? 5.0 : 8.0;
    return PlannedRoute(
      points: points,
      distanceKm: distance,
      durationMinutes: ((distance / speed) * 60).round(),
      profile: kind == ActivityKind.kayak ? 'manual_kayak' : 'manual_ski',
      provider: 'WayCrew manuell rute',
    );
  }

  double _haversineKm(RouteCoordinate a, RouteCoordinate b) {
    const radius = 6371.0;
    double rad(double degrees) => degrees * math.pi / 180;
    final dLat = rad(b.latitude - a.latitude);
    final dLon = rad(b.longitude - a.longitude);
    final x = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(rad(a.latitude)) * math.cos(rad(b.latitude)) * math.sin(dLon / 2) * math.sin(dLon / 2);
    return 2 * radius * math.atan2(math.sqrt(x), math.sqrt(1 - x));
  }

  List<RouteCoordinate> _extractGeoJsonPoints(Map<String, dynamic> trip) {
    final out = <RouteCoordinate>[];
    final legs = trip['legs'];
    if (legs is! List) return out;
    for (final rawLeg in legs) {
      if (rawLeg is! Map) continue;
      final shape = rawLeg['shape'];
      if (shape is Map) {
        final coords = shape['coordinates'];
        if (coords is List) {
          for (final c in coords) {
            if (c is List && c.length >= 2 && c[0] is num && c[1] is num) {
              final point = RouteCoordinate(latitude: (c[1] as num).toDouble(), longitude: (c[0] as num).toDouble());
              if (out.isEmpty || out.last.latitude != point.latitude || out.last.longitude != point.longitude) out.add(point);
            }
          }
        }
      }
    }
    return out;
  }
}

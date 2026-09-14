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

List<RouteCoordinate> decodeValhallaPolyline6(String encoded) {
  final points = <RouteCoordinate>[];
  var index = 0;
  var latitude = 0;
  var longitude = 0;

  int nextDelta() {
    var result = 0;
    var shift = 0;
    while (index < encoded.length) {
      final value = encoded.codeUnitAt(index++) - 63;
      if (value < 0) {
        throw const FormatException('Ugyldig Valhalla-polyline.');
      }
      result |= (value & 0x1f) << shift;
      shift += 5;
      if (value < 0x20) {
        return (result & 1) != 0 ? ~(result >> 1) : result >> 1;
      }
      if (shift > 30) {
        throw const FormatException('Ugyldig Valhalla-polyline.');
      }
    }
    throw const FormatException('Ufullstendig Valhalla-polyline.');
  }

  while (index < encoded.length) {
    latitude += nextDelta();
    longitude += nextDelta();
    points.add(RouteCoordinate(
      latitude: latitude / 1000000.0,
      longitude: longitude / 1000000.0,
    ));
  }
  return points;
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
      'shape_format': 'polyline6',
      'directions_type': 'none',
    };

    final response = await _requestRoute(payload);

    if (response.statusCode != 200) {
      final detail = _errorDetail(response.body);
      throw RoutePlanningException(
        'Kunne ikke beregne rute (${response.statusCode})${detail.isEmpty ? '' : ': $detail'}.',
      );
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

  Future<http.Response> _requestRoute(Map<String, dynamic> payload) async {
    Object? lastError;
    http.Response? lastResponse;
    final encodedPayload = jsonEncode(payload);

    for (final endpoint in const [_endpoint]) {
      try {
        final postResponse = await http
            .post(
              Uri.parse(endpoint),
              headers: const {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                'User-Agent': 'WayCrew-Android',
                'X-Client-Id': 'waycrew.app',
              },
              body: encodedPayload,
            )
            .timeout(const Duration(seconds: 18));

        if (postResponse.statusCode == 200) return postResponse;
        lastResponse = postResponse;

        // Some public Valhalla endpoints may reject POST with HTTP 405,
        // while supporting the documented GET form using the `json` query.
        if (postResponse.statusCode == 405) {
          final getUri = Uri.parse(endpoint).replace(queryParameters: {'json': encodedPayload});
          final getResponse = await http
              .get(
                getUri,
                headers: const {
                  'Accept': 'application/json',
                  'User-Agent': 'WayCrew-Android',
                  'X-Client-Id': 'waycrew.app',
                },
              )
              .timeout(const Duration(seconds: 18));
          if (getResponse.statusCode == 200) return getResponse;
          lastResponse = getResponse;
        }
      } catch (error) {
        lastError = error;
      }
    }

    if (lastResponse != null) return lastResponse;
    throw RoutePlanningException(
      'Ruteberegning er ikke tilgjengelig akkurat nå${lastError == null ? '' : ' (${lastError.runtimeType})'}.',
    );
  }

  String _errorDetail(String body) {
    if (body.trim().isEmpty) return '';
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final value = decoded['error'] ?? decoded['message'] ?? decoded['error_code'];
        if (value != null) return value.toString();
      }
    } catch (_) {
      // Fall back to a short plain-text response below.
    }
    final normalized = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized.length <= 140 ? normalized : '${normalized.substring(0, 140)}…';
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
      final legPoints = <RouteCoordinate>[];
      if (shape is Map) {
        final coords = shape['coordinates'];
        if (coords is List) {
          for (final c in coords) {
            if (c is List && c.length >= 2 && c[0] is num && c[1] is num) {
              legPoints.add(RouteCoordinate(
                latitude: (c[1] as num).toDouble(),
                longitude: (c[0] as num).toDouble(),
              ));
            }
          }
        }
      } else if (shape is String && shape.isNotEmpty) {
        legPoints.addAll(decodeValhallaPolyline6(shape));
      }
      for (final point in legPoints) {
        if (out.isEmpty || out.last.latitude != point.latitude || out.last.longitude != point.longitude) {
          out.add(point);
        }
      }
    }
    return out;
  }
}

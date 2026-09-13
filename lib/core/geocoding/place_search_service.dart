import 'dart:convert';

import 'package:http/http.dart' as http;

class PlaceSearchResult {
  final String name;
  final String address;
  final double latitude;
  final double longitude;

  const PlaceSearchResult({
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  String get displayLabel => address.isEmpty || address == name ? name : '$name · $address';
}

class PlaceSearchService {
  static const _endpoint = 'https://photon.komoot.io/api/';
  final http.Client _client;

  PlaceSearchService({http.Client? client}) : _client = client ?? http.Client();

  Future<List<PlaceSearchResult>> search(String query) async {
    final clean = query.trim();
    if (clean.length < 2) return const [];

    Object? lastError;
    const attempts = <({bool restrictToNorway, bool includeLanguage})>[
      (restrictToNorway: true, includeLanguage: true),
      (restrictToNorway: true, includeLanguage: false),
      (restrictToNorway: false, includeLanguage: true),
      (restrictToNorway: false, includeLanguage: false),
    ];

    for (final attempt in attempts) {
      try {
        final results = await _request(
          clean,
          restrictToNorway: attempt.restrictToNorway,
          includeLanguage: attempt.includeLanguage,
        );
        if (results.isNotEmpty) return results;
      } catch (error) {
        lastError = error;
      }
    }

    if (lastError != null) throw lastError;
    return const [];
  }

  Future<List<PlaceSearchResult>> _request(
    String query, {
    required bool restrictToNorway,
    required bool includeLanguage,
  }) async {
    final params = <String, String>{
      'q': query,
      'limit': '8',
      if (includeLanguage) 'lang': 'nb',
      if (restrictToNorway) 'countrycode': 'NO',
    };
    final uri = Uri.parse(_endpoint).replace(queryParameters: params);
    final response = await _client.get(uri, headers: const {
      'Accept': 'application/geo+json, application/json',
      'Accept-Language': 'nb,no;q=0.9,en;q=0.7',
      'User-Agent': 'WayCrew/0.2.15 (place-search)',
    }).timeout(const Duration(seconds: 8));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('place_search_http_${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) return const [];
    final features = decoded['features'];
    if (features is! List) return const [];
    return features.map(_fromFeature).whereType<PlaceSearchResult>().toList(growable: false);
  }

  PlaceSearchResult? _fromFeature(dynamic raw) {
    if (raw is! Map) return null;
    final geometry = raw['geometry'];
    final properties = raw['properties'];
    if (geometry is! Map || properties is! Map) return null;
    final coords = geometry['coordinates'];
    if (coords is! List || coords.length < 2) return null;
    final lon = coords[0] is num ? (coords[0] as num).toDouble() : null;
    final lat = coords[1] is num ? (coords[1] as num).toDouble() : null;
    if (lat == null || lon == null) return null;

    String text(String key) => (properties[key]?.toString() ?? '').trim();
    final name = text('name');
    if (name.isEmpty) return null;

    final street = text('street');
    final number = text('housenumber');
    final parts = <String>[
      if (street.isNotEmpty) '$street${number.isNotEmpty ? ' $number' : ''}',
      text('postcode'),
      text('city').isNotEmpty ? text('city') : text('locality'),
      text('state'),
      text('country'),
    ];
    final deduped = <String>[];
    for (final part in parts) {
      final value = part.trim();
      if (value.isNotEmpty && !deduped.contains(value)) deduped.add(value);
    }
    return PlaceSearchResult(name: name, address: deduped.join(', '), latitude: lat, longitude: lon);
  }
}

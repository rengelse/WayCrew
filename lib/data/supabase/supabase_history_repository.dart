import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/activity_models.dart';
import '../../domain/repositories/repositories.dart';

class SupabaseHistoryRepository implements HistoryRepository {
  final SupabaseClient _client;
  const SupabaseHistoryRepository(this._client);

  String get _userId => _client.auth.currentUser!.id;

  @override
  Future<List<ActivityHistoryEntry>> mine() async {
    final rows = await _client.from('activity_history').select().eq('user_id', _userId).order('finished_at', ascending: false);
    return rows.map<ActivityHistoryEntry>((row) => _history(Map<String, dynamic>.from(row))).toList();
  }

  @override
  Future<ActivityHistoryEntry?> byId(String id) async {
    final row = await _client.from('activity_history').select().eq('id', id).eq('user_id', _userId).maybeSingle();
    if (row == null) return null;
    return _history(Map<String, dynamic>.from(row));
  }

  @override
  Future<List<RouteHistoryPoint>> routePoints(String historyId) async {
    final rows = await _client.from('activity_route_history').select('latitude,longitude,accuracy_m,recorded_at').eq('history_id', historyId).eq('user_id', _userId).order('recorded_at');
    return rows.map<RouteHistoryPoint>((row) {
      final p = Map<String, dynamic>.from(row);
      return RouteHistoryPoint(
        latitude: (p['latitude'] as num).toDouble(),
        longitude: (p['longitude'] as num).toDouble(),
        accuracyMeters: (p['accuracy_m'] as num?)?.toDouble() ?? 0,
        recordedAt: DateTime.parse(p['recorded_at'] as String).toLocal(),
      );
    }).toList();
  }

  @override
  Future<List<ActivityEvent>> eventsForActivity(String activityId) async {
    final rows = await _client.from('activity_events').select().eq('activity_id', activityId).order('created_at');
    return rows.map<ActivityEvent>((row) {
      final e = Map<String, dynamic>.from(row);
      return ActivityEvent(
        id: e['id'] as String,
        activityId: e['activity_id'] as String,
        eventType: e['event_type'] as String,
        actorUserId: e['actor_user_id'] as String?,
        data: Map<String, dynamic>.from(e['data'] as Map? ?? const {}),
        createdAt: DateTime.parse(e['created_at'] as String).toLocal(),
      );
    }).toList();
  }

  @override
  Future<void> remove(String id) async {
    await _client.from('activity_history').delete().eq('id', id).eq('user_id', _userId);
  }

  ActivityHistoryEntry _history(Map<String, dynamic> row) {
    return ActivityHistoryEntry(
      id: row['id'] as String,
      sourceActivityId: row['activity_id'] as String?,
      title: row['title'] as String? ?? 'Aktivitet',
      kind: ActivityKind.values.where((e) => e.name == row['activity_type']).firstOrNull ?? ActivityKind.other,
      date: DateTime.tryParse(row['finished_at'] as String? ?? '')?.toLocal() ?? DateTime.now(),
      distanceKm: (row['distance_km'] as num?)?.toDouble() ?? 0,
      durationMinutes: (row['duration_minutes'] as num?)?.toInt() ?? 0,
      participantCount: (row['participant_count'] as num?)?.toInt() ?? 0,
      role: switch (row['role'] as String?) { 'leader' => 'Turleder', 'sweep' => 'Baktropp', _ => 'Deltaker' },
      routeSaved: row['route_saved'] as bool? ?? false,
      routeLabel: row['route_label'] as String? ?? 'Rute ikke lagret',
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> { E? get firstOrNull => isEmpty ? null : first; }

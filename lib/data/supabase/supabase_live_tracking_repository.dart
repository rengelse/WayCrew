import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/activity_models.dart';
import '../../domain/repositories/repositories.dart';

class SupabaseLiveTrackingRepository implements LiveTrackingRepository {
  final SupabaseClient _client;
  const SupabaseLiveTrackingRepository(this._client);

  @override
  Future<void> ensureSession(String activityId) async {
    await _client.rpc('ensure_live_session', params: {'p_activity_id': activityId});
  }

  @override
  Future<void> publishPosition(String activityId, LivePositionSample sample, {required bool shareWithParticipants, required bool shareWithLeader, required bool publicApproximate}) async {
    await _client.rpc('publish_live_position', params: {
      'p_activity_id': activityId,
      'p_sequence': sample.sequence,
      'p_latitude': sample.latitude,
      'p_longitude': sample.longitude,
      'p_accuracy_m': sample.accuracyMeters,
      'p_heading_deg': sample.headingDegrees,
      'p_speed_mps': sample.speedMetersPerSecond,
      'p_recorded_at': sample.recordedAt.toUtc().toIso8601String(),
      'p_share_participants': shareWithParticipants,
      'p_share_leader': shareWithLeader,
      'p_public_approximate': publicApproximate,
    });
  }

  @override
  Future<void> setRouteHistoryEnabled(String activityId, bool enabled) async {
    await _client.rpc('set_route_history_preference', params: {'p_activity_id': activityId, 'p_enabled': enabled});
  }

  @override
  Future<void> stopSharing(String activityId) async {
    await _client.rpc('stop_live_sharing', params: {'p_activity_id': activityId});
  }

  @override
  Future<void> setPrivacy(String activityId, {required bool shareWithParticipants, required bool shareWithLeader, required bool publicApproximate}) async {
    await _client.rpc('set_live_privacy', params: {
      'p_activity_id': activityId,
      'p_share_participants': shareWithParticipants,
      'p_share_leader': shareWithLeader,
      'p_public_approximate': publicApproximate,
    });
  }

  @override
  Stream<List<LiveParticipantPosition>> watchParticipants(String activityId) {
    return _client
        .from('live_participants')
        .stream(primaryKey: ['session_id', 'user_id'])
        .eq('activity_id', activityId)
        .map((rows) => rows
            .map((raw) => _participant(Map<String, dynamic>.from(raw)))
            .where((item) => item.sharing)
            .toList()
          ..sort((a, b) => a.role.index.compareTo(b.role.index)));
  }

  @override
  Stream<ActivityPublicState?> watchPublicState(String activityId) {
    return _client
        .from('activity_public_state')
        .stream(primaryKey: ['activity_id'])
        .eq('activity_id', activityId)
        .map((rows) => rows.isEmpty ? null : _publicState(Map<String, dynamic>.from(rows.first)));
  }

  @override
  Stream<List<ActivityPublicState>> watchPublicStates() {
    return _client
        .from('activity_public_state')
        .stream(primaryKey: ['activity_id'])
        .map((rows) => rows.map((raw) => _publicState(Map<String, dynamic>.from(raw))).toList());
  }

  LiveParticipantPosition _participant(Map<String, dynamic> row) {
    return LiveParticipantPosition(
      activityId: row['activity_id'] as String,
      userId: row['user_id'] as String,
      role: ParticipantRole.values.where((item) => item.name == row['role']).firstOrNull ?? ParticipantRole.participant,
      latitude: (row['latitude'] as num).toDouble(),
      longitude: (row['longitude'] as num).toDouble(),
      accuracyMeters: (row['accuracy_m'] as num?)?.toDouble() ?? 0,
      headingDegrees: (row['heading_deg'] as num?)?.toDouble(),
      speedMetersPerSecond: (row['speed_mps'] as num?)?.toDouble(),
      recordedAt: DateTime.tryParse(row['recorded_at'] as String? ?? '')?.toLocal() ?? DateTime.now(),
      sharing: row['sharing'] as bool? ?? false,
    );
  }

  ActivityPublicState _publicState(Map<String, dynamic> row) {
    return ActivityPublicState(
      activityId: row['activity_id'] as String,
      latitude: (row['center_latitude'] as num).toDouble(),
      longitude: (row['center_longitude'] as num).toDouble(),
      participantCount: (row['participant_count'] as num?)?.toInt() ?? 0,
      updatedAt: DateTime.tryParse(row['updated_at'] as String? ?? '')?.toLocal() ?? DateTime.now(),
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}

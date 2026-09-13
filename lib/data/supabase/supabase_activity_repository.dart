import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/activity_models.dart';
import '../../domain/repositories/repositories.dart';

class SupabaseActivityRepository implements ActivityRepository {
  final SupabaseClient _client;
  const SupabaseActivityRepository(this._client);

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('Ingen innlogget Supabase-bruker.');
    return id;
  }

  @override
  Future<List<Activity>> discover() async {
    final rows = await _client.from('activities').select().order('starts_at');
    final result = <Activity>[];
    for (final row in rows) {
      result.add(await _hydrate(Map<String, dynamic>.from(row)));
    }
    return result;
  }

  @override
  Future<Activity?> byId(String id) async {
    final row = await _client.from('activities').select().eq('id', id).maybeSingle();
    if (row == null) return null;
    return _hydrate(Map<String, dynamic>.from(row));
  }

  @override
  Future<Activity> create({required String title, required ActivityKind kind, required bool startNow, required ParticipationMode participationMode, String? meetingPoint, String? meetingAddress, double? meetingLatitude, double? meetingLongitude, required String routeStartName, required String routeStartAddress, required double routeStartLatitude, required double routeStartLongitude, required String routeDestinationName, required String routeDestinationAddress, required double routeDestinationLatitude, required double routeDestinationLongitude, String? description, String? groupId}) async {
    final cleanMeeting = (meetingPoint ?? '').trim();
    final startsAt = startNow ? DateTime.now() : DateTime.now().add(const Duration(days: 1));
    final result = await _client.rpc('create_activity', params: {
      'p_activity_type': kind.name,
      'p_title': title.trim().isEmpty ? '${kind.label}-aktivitet' : title.trim(),
      'p_description': (description ?? '').trim(),
      'p_status': startNow ? ActivityStatus.gathering.name : ActivityStatus.planned.name,
      'p_participation_mode': participationMode.name,
      'p_starts_at': startsAt.toUtc().toIso8601String(),
      'p_meeting_point': cleanMeeting,
      'p_meeting_address': (meetingAddress ?? '').trim(),
      'p_meeting_latitude': meetingLatitude,
      'p_meeting_longitude': meetingLongitude,
      'p_route_start_name': routeStartName.trim(),
      'p_route_start_address': routeStartAddress.trim(),
      'p_route_start_latitude': routeStartLatitude,
      'p_route_start_longitude': routeStartLongitude,
      'p_route_destination_name': routeDestinationName.trim(),
      'p_route_destination_address': routeDestinationAddress.trim(),
      'p_route_destination_latitude': routeDestinationLatitude,
      'p_route_destination_longitude': routeDestinationLongitude,
      'p_max_participants': 12,
      'p_pace': 'Normal',
      'p_surface': kind == ActivityKind.motorcycle ? 'Asfalt' : 'Ikke satt',
      'p_group_id': groupId,
    });
    final id = result as String;
    final created = await byId(id);
    if (created == null) {
      throw StateError('Aktiviteten ble opprettet, men kunne ikke lastes inn igjen.');
    }
    return created;
  }

  @override Future<void> requestToJoin(String activityId) async { await _client.rpc('request_to_join_activity', params: {'p_activity_id': activityId}); }
  @override Future<void> joinOpen(String activityId) async { await _client.rpc('join_open_activity', params: {'p_activity_id': activityId}); }
  @override Future<void> approveParticipant(String activityId, String userId) async { await _client.rpc('approve_activity_participant', params: {'p_activity_id': activityId, 'p_user_id': userId}); }
  @override Future<void> setStatus(String activityId, ActivityStatus status) async { await _client.rpc('set_activity_status', params: {'p_activity_id': activityId, 'p_status': status.name}); }
  @override Future<void> updateMeetingPoint(String activityId, String meetingPoint) async { await _client.rpc('update_activity_meeting_point', params: {'p_activity_id': activityId, 'p_meeting_point': meetingPoint}); }
  @override Future<void> leave(String activityId) async { await _client.rpc('leave_activity', params: {'p_activity_id': activityId}); }
  @override Future<void> deleteActivity(String activityId) async { await _client.rpc('delete_activity', params: {'p_activity_id': activityId}); }

  Future<Activity> _hydrate(Map<String, dynamic> row) async {
    final id = row['id'] as String;
    final participantRows = await _client.from('activity_participants').select().eq('activity_id', id).order('joined_at');
    final userIds = participantRows.map((r) => r['user_id'] as String).toSet().toList();
    final profiles = <String, Map<String, dynamic>>{};
    if (userIds.isNotEmpty) {
      final profileRows = await _client.from('profiles').select('id,display_name,region').inFilter('id', userIds);
      for (final p in profileRows) {
        profiles[p['id'] as String] = Map<String, dynamic>.from(p);
      }
    }
    final participants = participantRows.map<ActivityParticipant>((raw) {
      final p = Map<String, dynamic>.from(raw);
      final userId = p['user_id'] as String;
      final profile = profiles[userId];
      return ActivityParticipant(
        user: AppUser(id: userId, name: (profile?['display_name'] as String?)?.trim().isNotEmpty == true ? profile!['display_name'] as String : 'Deltaker', region: profile?['region'] as String? ?? '', interests: const []),
        role: _participantRole(p['role'] as String?),
        status: _participantStatus(p['status'] as String?),
      );
    }).toList();
    final mineParticipant = participants.where((p) => p.user.id == _userId && !{ParticipantStatus.rejected, ParticipantStatus.left, ParticipantStatus.removed, ParticipantStatus.withdrawn}.contains(p.status)).toList();
    final myPending = mineParticipant.any((p) => p.status == ParticipantStatus.requested);
    final stops = await _client.from('activity_stops').select().eq('activity_id', id).order('sort_order');
    final meetingStops = stops.where((s) => s['stop_type'] == 'meeting').cast<Map<String, dynamic>>().toList();
    final meetingStop = meetingStops.isEmpty ? null : meetingStops.first;
    final destinationStops = stops.where((s) => s['stop_type'] == 'destination').cast<Map<String, dynamic>>().toList();
    final nextStop = destinationStops.isNotEmpty ? destinationStops : stops.where((s) => s['stop_type'] != 'meeting').cast<Map<String, dynamic>>().toList();
    return Activity(
      id: id,
      title: row['title'] as String? ?? 'Aktivitet',
      kind: _activityKind(row['activity_type'] as String?),
      status: _activityStatus(row['status'] as String?),
      participationMode: _participationMode(row['participation_mode'] as String?),
      routeLabel: row['route_label'] as String? ?? 'Rute ikke satt',
      meetingPoint: row['meeting_point'] as String? ?? '',
      meetingAddress: meetingStop?['address'] as String?,
      meetingLatitude: (meetingStop?['latitude'] as num?)?.toDouble(),
      meetingLongitude: (meetingStop?['longitude'] as num?)?.toDouble(),
      startsAt: DateTime.tryParse(row['starts_at'] as String? ?? '')?.toLocal() ?? DateTime.now(),
      maxParticipants: (row['max_participants'] as num?)?.toInt() ?? 12,
      distanceKm: (row['distance_km'] as num?)?.toDouble() ?? 0,
      pace: row['pace'] as String? ?? 'Normal',
      surface: row['surface'] as String? ?? 'Ikke satt',
      description: row['description'] as String? ?? '',
      groupId: row['group_id'] as String?,
      nextStopName: nextStop.isEmpty ? null : nextStop.first['name'] as String?,
      nextStopEtaMinutes: nextStop.isEmpty ? null : (nextStop.first['eta_minutes'] as num?)?.toInt(),
      participants: participants,
      mine: mineParticipant.isNotEmpty,
      requestPending: myPending,
    );
  }

  ActivityKind _activityKind(String? value) => ActivityKind.values.where((e) => e.name == value).firstOrNull ?? ActivityKind.other;
  ActivityStatus _activityStatus(String? value) => ActivityStatus.values.where((e) => e.name == value).firstOrNull ?? ActivityStatus.planned;
  ParticipationMode _participationMode(String? value) => ParticipationMode.values.where((e) => e.name == value).firstOrNull ?? ParticipationMode.request;
  ParticipantRole _participantRole(String? value) => ParticipantRole.values.where((e) => e.name == value).firstOrNull ?? ParticipantRole.participant;
  ParticipantStatus _participantStatus(String? value) => ParticipantStatus.values.where((e) => e.name == value).firstOrNull ?? ParticipantStatus.requested;
}

extension _FirstOrNull<E> on Iterable<E> { E? get firstOrNull => isEmpty ? null : first; }

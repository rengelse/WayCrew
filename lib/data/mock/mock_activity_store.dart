import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/activity_models.dart';
import 'mock_data.dart';

class MockActivityStore extends StateNotifier<List<Activity>> {
  MockActivityStore() : super(activities());

  Activity? byId(String id) {
    for (final activity in state) { if (activity.id == id) return activity; }
    return null;
  }

  bool _currentUserIsLeader(Activity activity) => activity.participants.any(
    (p) => p.user.id == currentUser.id && p.role == ParticipantRole.leader &&
      (p.status == ParticipantStatus.approved || p.status == ParticipantStatus.active),
  );

  void replace(Activity activity) {
    state = [for (final item in state) if (item.id == activity.id) activity else item];
  }

  Activity create({required String title, required ActivityKind kind, required bool startNow, required ParticipationMode participationMode,
    String? meetingPoint, required String routeStartName, required String routeDestinationName, required ActivityRoutePlan routePlan, List<ActivityRouteStop> routeStops = const [], String? description, String? groupId}) {
    final activity = Activity(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}', title: title.trim().isEmpty ? '${kind.label}-aktivitet' : title.trim(), kind: kind,
      status: startNow ? ActivityStatus.gathering : ActivityStatus.planned, participationMode: participationMode,
      routeLabel: '${routeStartName.trim()} → ${routeDestinationName.trim()}',
      meetingPoint: meetingPoint?.trim().isNotEmpty == true ? meetingPoint!.trim() : 'Møtepunkt ikke satt',
      startsAt: startNow ? DateTime.now() : DateTime.now().add(const Duration(days: 1)), maxParticipants: 12, distanceKm: routePlan.distanceKm,
      pace: 'Normal', surface: kind == ActivityKind.motorcycle ? 'Asfalt' : 'Ikke satt',
      description: description?.trim().isNotEmpty == true ? description!.trim() : 'Ny aktivitet opprettet lokalt med mockdata.',
      groupId: groupId, nextStopName: routeDestinationName.trim(), nextStopEtaMinutes: startNow ? 15 : null,
      participants: const [ActivityParticipant(user: currentUser, role: ParticipantRole.leader, status: ParticipantStatus.approved)], mine: true, routePlan: routePlan, routeStops: routeStops,
    );
    state = [activity, ...state];
    return activity;
  }

  void requestToJoin(String id) {
    final activity = byId(id); if (activity == null || activity.requestPending) return;
    replace(activity.copyWith(requestPending: true));
  }

  void joinOpen(String id) {
    final activity = byId(id); if (activity == null || activity.isFull) return;
    if (activity.participants.any((p) => p.user.id == currentUser.id)) return;
    replace(activity.copyWith(mine: true, participants: [...activity.participants,
      const ActivityParticipant(user: currentUser, role: ParticipantRole.participant, status: ParticipantStatus.approved)]));
  }

  void approveParticipant(String id, String userId) {
    final activity = byId(id); if (activity == null || activity.isFull || !_currentUserIsLeader(activity)) return;
    replace(activity.copyWith(participants: [for (final p in activity.participants) if (p.user.id == userId) p.copyWith(status: ParticipantStatus.approved) else p]));
  }

  void setStatus(String id, ActivityStatus status) {
    final activity = byId(id); if (activity == null || !_currentUserIsLeader(activity)) return;
    final participants = status == ActivityStatus.active
        ? activity.participants.map((p) => p.status == ParticipantStatus.approved ? p.copyWith(status: ParticipantStatus.active, lastUpdated: DateTime.now()) : p).toList()
        : activity.participants;
    replace(activity.copyWith(status: status, participants: participants));
  }

  void updateMeetingPoint(String id, String meetingPoint) {
    final activity = byId(id);
    if (activity == null || !_currentUserIsLeader(activity)) return;
    final clean = meetingPoint.trim();
    if (clean.isEmpty) return;
    replace(activity.copyWith(meetingPoint: clean, nextStopName: clean, nextStopEtaMinutes: 15));
  }

  void leave(String id) {
    final activity = byId(id); if (activity == null) return;
    replace(activity.copyWith(mine: false, requestPending: false,
      participants: activity.participants.where((p) => p.user.id != currentUser.id).toList()));
  }

  void deleteActivity(String id) {
    final activity = byId(id);
    if (activity == null || !_currentUserIsLeader(activity)) return;
    state = state.where((item) => item.id != id).toList();
  }

  void reset() => state = activities();
}

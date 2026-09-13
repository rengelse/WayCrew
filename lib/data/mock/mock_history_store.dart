import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/activity_models.dart';
import 'mock_data.dart';

class MockHistoryStore extends StateNotifier<List<ActivityHistoryEntry>> {
  MockHistoryStore() : super([
    ActivityHistoryEntry(id: 'h1', title: 'Jæren rundt', kind: ActivityKind.motorcycle, date: mockNow.subtract(const Duration(days: 6)), distanceKm: 278, durationMinutes: 342, participantCount: 8, role: 'Turleder', routeSaved: true, routeLabel: 'Stavanger → Jæren → Egersund → Stavanger'),
    ActivityHistoryEntry(id: 'h2', title: 'Preikestolen', kind: ActivityKind.hiking, date: mockNow.subtract(const Duration(days: 13)), distanceKm: 8, durationMinutes: 192, participantCount: 5, role: 'Deltaker', routeSaved: true, routeLabel: 'Preikestolen tur/retur'),
  ]);

  ActivityHistoryEntry? byId(String id) {
    for (final item in state) {
      if (item.id == id) return item;
    }
    return null;
  }

  void remove(String id) => state = state.where((e) => e.id != id).toList();

  void addFromFinishedActivity(Activity activity, {bool routeSaved = true}) {
    if (state.any((e) => e.id == 'activity-${activity.id}')) return;
    state = [
      ActivityHistoryEntry(
        id: 'activity-${activity.id}',
        title: activity.title,
        kind: activity.kind,
        date: DateTime.now(),
        distanceKm: activity.distanceKm,
        durationMinutes: 180,
        participantCount: activity.confirmedParticipants,
        role: activity.participants.any((p) => p.user.id == currentUser.id && p.role == ParticipantRole.leader) ? 'Turleder' : 'Deltaker',
        routeSaved: routeSaved,
        routeLabel: activity.routeLabel,
        sourceActivityId: activity.id,
      ),
      ...state,
    ];
  }
}

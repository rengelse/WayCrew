import 'package:activity_network/domain/models/activity_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('history entry keeps immutable summary fields', () {
    final entry = ActivityHistoryEntry(
      id: 'h',
      sourceActivityId: 'a',
      title: 'Tur',
      kind: ActivityKind.motorcycle,
      date: DateTime(2026, 9, 13),
      distanceKm: 120,
      durationMinutes: 95,
      participantCount: 4,
      role: 'Turleder',
      routeSaved: true,
      routeLabel: 'A → B',
    );
    expect(entry.routeSaved, isTrue);
    expect(entry.participantCount, 4);
    expect(entry.sourceActivityId, 'a');
  });

  test('notification read state can be copied without mutating identity', () {
    final n = AppNotification(
      id: 'n',
      title: 'Tittel',
      body: 'Tekst',
      category: NotificationCategory.activities,
      priority: NotificationPriority.normal,
      createdAt: DateTime(2026, 9, 13),
    );
    final read = n.copyWith(read: true);
    expect(read.id, n.id);
    expect(read.read, isTrue);
    expect(n.read, isFalse);
  });
}

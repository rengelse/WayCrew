import 'package:activity_network/domain/models/activity_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('live participant marks old samples as stale', () {
    final fresh = LiveParticipantPosition(
      activityId: 'a',
      userId: 'u',
      role: ParticipantRole.participant,
      latitude: 58.97,
      longitude: 5.73,
      accuracyMeters: 8,
      recordedAt: DateTime.now().subtract(const Duration(seconds: 20)),
    );
    final stale = LiveParticipantPosition(
      activityId: 'a',
      userId: 'u',
      role: ParticipantRole.participant,
      latitude: 58.97,
      longitude: 5.73,
      accuracyMeters: 8,
      recordedAt: DateTime.now().subtract(const Duration(minutes: 3)),
    );
    expect(fresh.isStale, isFalse);
    expect(stale.isStale, isTrue);
  });

  test('public state marks old group position as stale', () {
    final state = ActivityPublicState(
      activityId: 'a',
      latitude: 58.97,
      longitude: 5.73,
      participantCount: 4,
      updatedAt: DateTime.now().subtract(const Duration(minutes: 4)),
    );
    expect(state.isStale, isTrue);
  });
}

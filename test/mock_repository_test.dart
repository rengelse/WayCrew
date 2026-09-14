import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:activity_network/app/app_theme.dart';
import 'package:activity_network/core/dev/dev_scenario.dart';
import 'package:activity_network/data/mock/mock_activity_store.dart';
import 'package:activity_network/data/mock/mock_chat_store.dart';
import 'package:activity_network/data/mock/mock_group_store.dart';
import 'package:activity_network/data/mock/mock_notification_store.dart';
import 'package:activity_network/data/mock/mock_profile_store.dart';
import 'package:activity_network/data/mock/mock_settings_store.dart';
import 'package:activity_network/data/mock/mock_history_store.dart';
import 'package:activity_network/data/mock/mock_repositories.dart';
import 'package:activity_network/data/mock/mock_data.dart';
import 'package:activity_network/domain/models/activity_models.dart';

void main() {
  test('empty scenario returns no activities', () async {
    final store = MockActivityStore();
    final repo = MockActivityRepository(DevScenario.empty, store.state, store);
    expect(await repo.discover(), isEmpty);
  });

  test('create activity adds local gathering activity', () {
    final store = MockActivityStore();
    final before = store.state.length;
    final created = store.create(title: 'Testtur', kind: ActivityKind.motorcycle, startNow: true, startsAt: mockNow, participationMode: ParticipationMode.request, meetingPoint: 'Forus', routeStartName: 'Forus', routeDestinationName: 'Bryne', routePlan: const ActivityRoutePlan(), description: 'Test');
    expect(store.state.length, before + 1);
    expect(created.status, ActivityStatus.gathering);
    expect(created.startsAt, mockNow);
    expect(created.participants.single.role, ParticipantRole.leader);
  });

  test('leader can approve requested participant', () {
    final store = MockActivityStore();
    store.approveParticipant('a4', linn.id);
    final participant = store.byId('a4')!.participants.firstWhere((p) => p.user.id == linn.id);
    expect(participant.status, ParticipantStatus.approved);
  });

  test('activity lifecycle updates state', () {
    final store = MockActivityStore();
    store.setStatus('a4', ActivityStatus.active);
    expect(store.byId('a4')!.status, ActivityStatus.active);
    store.setStatus('a4', ActivityStatus.paused);
    expect(store.byId('a4')!.status, ActivityStatus.paused);
    store.setStatus('a4', ActivityStatus.finished);
    expect(store.byId('a4')!.status, ActivityStatus.finished);
  });

  test('group membership request mutates group state', () {
    final store = MockGroupStore();
    expect(store.byId('g3')!.requestPending, isFalse);
    store.requestMembership('g3');
    expect(store.byId('g3')!.requestPending, isTrue);
  });

  test('activity chat can append local message', () {
    final store = MockChatStore();
    final before = store.activityMessages('a1').length;
    store.sendActivity('a1', 'Ny testmelding');
    expect(store.activityMessages('a1').length, before + 1);
    expect(store.activityMessages('a1').last.text, 'Ny testmelding');
  });

  test('group creation produces owned mutable group', () {
    final store = MockGroupStore();
    final created = store.create(
      name: 'Ny testgruppe',
      kind: ActivityKind.hiking,
      region: 'Rogaland',
      description: 'Test',
      visibility: GroupVisibility.public,
      joinMode: GroupJoinMode.request,
    );
    expect(created.member, isTrue);
    expect(created.myRole, GroupRole.owner);
    expect(store.byId(created.id), isNotNull);
  });

  test('group post can be added and removed', () {
    final store = MockGroupStore();
    final before = store.posts('g1').length;
    final post = store.addPost('g1', 'Nytt innlegg');
    expect(store.posts('g1').length, before + 1);
    store.deletePost('g1', post.id);
    expect(store.posts('g1').length, before);
  });

  test('owner can approve pending group member', () {
    final store = MockGroupStore();
    expect(store.pendingMembers('g1').any((m) => m.user.id == linn.id), isTrue);
    store.approveMembership('g1', linn.id);
    expect(store.pendingMembers('g1').any((m) => m.user.id == linn.id), isFalse);
    expect(store.members('g1').firstWhere((m) => m.user.id == linn.id).status, GroupMembershipStatus.active);
  });

  test('notification store marks all as read', () {
    final store = MockNotificationStore();
    expect(store.state.any((n) => !n.read), isTrue);
    store.markAllRead();
    expect(store.state.every((n) => n.read), isTrue);
  });


  test('profile state can edit basic fields and interests', () {
    final store = MockProfileStore();
    store.updateBasic(name: 'Ny bruker', region: 'Rogaland', bio: 'Tur og MC');
    expect(store.state.name, 'Ny bruker');
    store.toggleInterest(ActivityKind.kayak);
    expect(store.state.interests.contains(ActivityKind.kayak), isTrue);
  });

  test('privacy and tracking settings are mutable', () {
    final store = MockSettingsStore();
    store.setParticipantLocation(false);
    store.setHistoryVisibility(VisibilityLevel.onlyMe);
    expect(store.state.participantLocation, isFalse);
    expect(store.state.historyVisibility, VisibilityLevel.onlyMe);
  });

  test('history can add finished activity and remove entry', () {
    final history = MockHistoryStore();
    final activity = activities().first;
    final before = history.state.length;
    history.addFromFinishedActivity(activity.copyWith(status: ActivityStatus.finished));
    expect(history.state.length, before + 1);
    final id = 'activity-${activity.id}';
    expect(history.byId(id), isNotNull);
    history.remove(id);
    expect(history.byId(id), isNull);
  });

  test('activity can be linked to group and meeting point updates', () {
    final store = MockActivityStore();
    final created = store.create(
      title: 'Gruppetur',
      kind: ActivityKind.motorcycle,
      startNow: true,
      startsAt: mockNow,
      participationMode: ParticipationMode.groupOnly,
      meetingPoint: 'Forus',
      routeStartName: 'Forus',
      routeDestinationName: 'Sandnes',
      routePlan: const ActivityRoutePlan(),
      description: 'Test',
      groupId: 'g1',
    );
    expect(created.groupId, 'g1');
    store.updateMeetingPoint(created.id, 'Sandnes');
    expect(store.byId(created.id)!.meetingPoint, 'Sandnes');
    expect(store.byId(created.id)!.nextStopName, 'Sandnes');
  });

  test('chat can use edited profile display name', () {
    final store = MockChatStore();
    store.sendActivity('a1', 'Hei', senderName: 'Nytt navn');
    expect(store.activityMessages('a1').last.sender, 'Nytt navn');
  });

  test('finished history respects route history setting', () {
    final history = MockHistoryStore();
    final activity = activities().first;
    history.addFromFinishedActivity(activity.copyWith(status: ActivityStatus.finished), routeSaved: false);
    expect(history.byId('activity-${activity.id}')!.routeSaved, isFalse);
    expect(history.byId('activity-${activity.id}')!.sourceActivityId, activity.id);
  });

  test('theme uses neutral surfaces with green reserved for accent', () {
    expect(AppTheme.light.scaffoldBackgroundColor, AppColors.lightBackground);
    expect(AppTheme.light.colorScheme.surface, AppColors.lightSurface);
    expect(AppTheme.dark.scaffoldBackgroundColor, AppColors.darkBackground);
    expect(AppTheme.dark.colorScheme.surface, AppColors.darkSurface);
  });

  test('non leader cannot administer another activity', () {
    final store = MockActivityStore();
    final before = store.byId('a2')!;
    store.setStatus('a2', ActivityStatus.active);
    store.updateMeetingPoint('a2', 'Skal ikke endres');
    store.approveParticipant('a2', currentUser.id);
    final after = store.byId('a2')!;
    expect(after.status, before.status);
    expect(after.meetingPoint, before.meetingPoint);
  });

  test('profile can store and remove mock avatar bytes', () {
    final store = MockProfileStore();
    store.setAvatar(Uint8List.fromList([1, 2, 3]));
    expect(store.state.avatarBytes, isNotNull);
    store.removeAvatar();
    expect(store.state.avatarBytes, isNull);
  });

  test('chat repository exposes message streams', () async {
    final store = MockChatStore();
    final repo = MockChatRepository(store);
    final messages = await repo.watchActivityMessages('a1').first;
    expect(messages, isNotEmpty);
  });

  test('chat message can carry stable sender id', () {
    final message = ChatMessage(
      id: 'm1',
      senderId: 'u1',
      sender: 'Test',
      text: 'Hei',
      sentAt: DateTime(2026, 9, 13),
    );
    expect(message.senderId, 'u1');
  });

  test('chat message can be soft deleted in mock store', () {
    final store = MockChatStore();
    store.sendActivity('a1', 'Skal slettes', senderName: 'Nytt navn');
    final id = store.activityMessages('a1').last.id;
    store.deleteMessage(id);
    final deleted = store.activityMessages('a1').last;
    expect(deleted.id, id);
    expect(deleted.isDeleted, isTrue);
    expect(deleted.text, isEmpty);
  });


}


import '../../core/dev/dev_scenario.dart';
import '../../domain/models/activity_models.dart';
import '../../domain/repositories/repositories.dart';
import 'mock_activity_store.dart';
import 'mock_chat_store.dart';
import 'mock_group_store.dart';
import 'mock_data.dart';

class MockActivityRepository implements ActivityRepository {
  final DevScenario scenario;
  final List<Activity> state;
  final MockActivityStore store;
  const MockActivityRepository(this.scenario, this.state, this.store);

  List<Activity> _scenarioView() {
    if (scenario == DevScenario.empty) return [];
    return state.map((item) {
      var result = item;
      if (scenario == DevScenario.pendingRequest && item.id == 'a2') result = result.copyWith(requestPending: true);
      if (scenario == DevScenario.fullActivity && item.id == 'a2') result = result.copyWith(maxParticipants: item.participants.length);
      if (scenario == DevScenario.staleGps && item.id == 'a1') {
        result = result.copyWith(participants: item.participants.map((p) => p.user.id == 'u3' ? p.copyWith(lastUpdated: mockNow.subtract(const Duration(minutes: 8))) : p).toList());
      }
      return result;
    }).toList();
  }

  @override Future<List<Activity>> discover() async { await Future<void>.delayed(const Duration(milliseconds: 100)); return _scenarioView(); }
  @override Future<Activity?> byId(String id) async { for (final a in _scenarioView()) { if (a.id == id) return a; } return null; }
  @override Future<Activity> create({required String title, required ActivityKind kind, required bool startNow, required ParticipationMode participationMode, String? meetingPoint, String? meetingAddress, double? meetingLatitude, double? meetingLongitude, required String routeStartName, required String routeStartAddress, required double routeStartLatitude, required double routeStartLongitude, required String routeDestinationName, required String routeDestinationAddress, required double routeDestinationLatitude, required double routeDestinationLongitude, String? description, String? groupId}) async => store.create(title: title, kind: kind, startNow: startNow, participationMode: participationMode, meetingPoint: meetingPoint, routeStartName: routeStartName, routeDestinationName: routeDestinationName, description: description, groupId: groupId);
  @override Future<void> requestToJoin(String activityId) async => store.requestToJoin(activityId);
  @override Future<void> joinOpen(String activityId) async => store.joinOpen(activityId);
  @override Future<void> approveParticipant(String activityId, String userId) async => store.approveParticipant(activityId, userId);
  @override Future<void> setStatus(String activityId, ActivityStatus status) async => store.setStatus(activityId, status);
  @override Future<void> updateMeetingPoint(String activityId, String meetingPoint) async => store.updateMeetingPoint(activityId, meetingPoint);
  @override Future<void> leave(String activityId) async => store.leave(activityId);
  @override Future<void> deleteActivity(String activityId) async => store.deleteActivity(activityId);
}

class MockGroupRepository implements GroupRepository {
  final List<Group> state;
  final MockGroupStore store;
  const MockGroupRepository(this.state, this.store);
  @override Future<List<Group>> discover() async => state.where((g) => !g.member).toList();
  @override Future<List<Group>> mine() async => state.where((g) => g.member).toList();
  @override Future<Group?> byId(String id) async { for (final g in state) { if (g.id == id) return g; } return null; }
  @override Future<Group> create({required String name, required ActivityKind kind, required String region, required String description, required GroupVisibility visibility, required GroupJoinMode joinMode}) async => store.create(name: name, kind: kind, region: region, description: description, visibility: visibility, joinMode: joinMode);
  @override Future<List<GroupMember>> members(String groupId) async => store.members(groupId);
  @override Future<List<GroupMember>> pendingMembers(String groupId) async => store.pendingMembers(groupId);
  @override Future<List<GroupPost>> posts(String groupId) async => store.posts(groupId);
  @override Future<void> addPost(String groupId, String body) async => store.addPost(groupId, body);
  @override Future<void> deletePost(String groupId, String postId) async => store.deletePost(groupId, postId);
  @override Future<void> updateGroup(String groupId, {String? name, String? description, String? region, GroupVisibility? visibility, GroupJoinMode? joinMode, bool? membersCanCreateActivities}) async => store.updateGroup(groupId, name: name, description: description, region: region, visibility: visibility, joinMode: joinMode, membersCanCreateActivities: membersCanCreateActivities);
  @override Future<void> joinOpen(String groupId) async => store.joinOpen(groupId);
  @override Future<void> requestMembership(String groupId) async => store.requestMembership(groupId);
  @override Future<void> approveMembership(String groupId, String userId) async => store.approveMembership(groupId, userId);
  @override Future<void> rejectMembership(String groupId, String userId) async => store.rejectMembership(groupId, userId);
  @override Future<void> changeRole(String groupId, String userId, GroupRole role) async => store.changeRole(groupId, userId, role);
  @override Future<void> removeMember(String groupId, String userId) async => store.removeMember(groupId, userId);
  @override Future<void> leave(String groupId) async => store.leave(groupId);
  @override Future<void> deleteGroup(String groupId) async => store.deleteGroup(groupId);
}

class MockChatRepository implements ChatRepository {
  final MockChatStore store;
  const MockChatRepository(this.store);
  @override Future<List<ChatMessage>> activityMessages(String activityId) async => store.activityMessages(activityId);
  @override Future<List<ChatMessage>> groupMessages(String groupId) async => store.groupMessages(groupId);
  @override Stream<List<ChatMessage>> watchActivityMessages(String activityId) => Stream.value(store.activityMessages(activityId));
  @override Stream<List<ChatMessage>> watchGroupMessages(String groupId) => Stream.value(store.groupMessages(groupId));
  @override Future<void> sendActivityMessage(String activityId, String text, {bool important = false, String? senderName}) async => store.sendActivity(activityId, text, important: important, senderName: senderName);
  @override Future<void> sendGroupMessage(String groupId, String text, {String? senderName}) async => store.sendGroup(groupId, text, senderName: senderName);
}

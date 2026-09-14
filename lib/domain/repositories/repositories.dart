import '../models/activity_models.dart';

abstract interface class ActivityRepository {
  Future<List<Activity>> discover();
  Future<Activity?> byId(String id);
  Future<Activity> create({required String title, required ActivityKind kind, required bool startNow, required DateTime startsAt, required ParticipationMode participationMode, String? meetingPoint, String? meetingAddress, double? meetingLatitude, double? meetingLongitude, required String routeStartName, required String routeStartAddress, required double routeStartLatitude, required double routeStartLongitude, required String routeDestinationName, required String routeDestinationAddress, required double routeDestinationLatitude, required double routeDestinationLongitude, required ActivityRoutePlan routePlan, List<ActivityRouteStop> routeStops = const [], String? description, String? groupId});
  Future<void> requestToJoin(String activityId);
  Future<void> joinOpen(String activityId);
  Future<void> approveParticipant(String activityId, String userId);
  Future<void> setStatus(String activityId, ActivityStatus status);
  Future<void> updateMeetingPoint(String activityId, String meetingPoint);
  Future<void> leave(String activityId);
  Future<void> deleteActivity(String activityId);
}

abstract interface class GroupRepository {
  Future<List<Group>> mine();
  Future<List<Group>> discover();
  Future<Group?> byId(String id);
  Future<Group> create({required String name, required ActivityKind kind, required String region, required String description, required GroupVisibility visibility, required GroupJoinMode joinMode});
  Future<List<GroupMember>> members(String groupId);
  Future<List<GroupMember>> pendingMembers(String groupId);
  Future<List<GroupPost>> posts(String groupId);
  Future<void> addPost(String groupId, String body);
  Future<void> deletePost(String groupId, String postId);
  Future<void> updateGroup(String groupId, {String? name, String? description, String? region, GroupVisibility? visibility, GroupJoinMode? joinMode, bool? membersCanCreateActivities});
  Future<void> joinOpen(String groupId);
  Future<void> requestMembership(String groupId);
  Future<void> approveMembership(String groupId, String userId);
  Future<void> rejectMembership(String groupId, String userId);
  Future<void> changeRole(String groupId, String userId, GroupRole role);
  Future<void> removeMember(String groupId, String userId);
  Future<void> leave(String groupId);
  Future<void> deleteGroup(String groupId);
}

abstract interface class ChatRepository {
  Future<List<ChatMessage>> activityMessages(String activityId);
  Future<List<ChatMessage>> groupMessages(String groupId);
  Stream<List<ChatMessage>> watchActivityMessages(String activityId);
  Stream<List<ChatMessage>> watchGroupMessages(String groupId);
  Future<void> sendActivityMessage(String activityId, String text, {bool important = false, String? senderName});
  Future<void> sendGroupMessage(String groupId, String text, {String? senderName});
}

abstract interface class NotificationRepository {
  Stream<List<AppNotification>> watchMine();
  Future<void> markRead(String id);
  Future<void> markAllRead();
  Future<void> remove(String id);
}

abstract interface class HistoryRepository {
  Future<List<ActivityHistoryEntry>> mine();
  Future<ActivityHistoryEntry?> byId(String id);
  Future<List<RouteHistoryPoint>> routePoints(String historyId);
  Future<List<ActivityEvent>> eventsForActivity(String activityId);
  Future<void> remove(String id);
}

abstract interface class LiveTrackingRepository {
  Future<void> ensureSession(String activityId);
  Future<void> publishPosition(String activityId, LivePositionSample sample, {required bool shareWithParticipants, required bool shareWithLeader, required bool publicApproximate});
  Future<void> stopSharing(String activityId);
  Future<void> setPrivacy(String activityId, {required bool shareWithParticipants, required bool shareWithLeader, required bool publicApproximate});
  Future<void> setRouteHistoryEnabled(String activityId, bool enabled);
  Stream<List<LiveParticipantPosition>> watchParticipants(String activityId);
  Stream<ActivityPublicState?> watchPublicState(String activityId);
  Stream<List<ActivityPublicState>> watchPublicStates();
}

abstract interface class SafetyRepository {
  Future<List<BlockedUserEntry>> blockedUsers();
  Future<void> blockUser(String userId);
  Future<void> unblockUser(String userId);
  Future<void> submitReport({required String category, required String description, String? targetType, String? targetId});
  Future<List<UserReportEntry>> myReports();
}

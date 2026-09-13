import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/activity_models.dart';
import 'mock_data.dart';

class MockGroupStore extends StateNotifier<List<Group>> {
  MockGroupStore()
      : _members = initialGroupMembers(),
        _posts = initialGroupPosts(),
        super(initialGroups());

  final Map<String, List<GroupMember>> _members;
  final Map<String, List<GroupPost>> _posts;
  int _groupCounter = 10;
  int _postCounter = 10;

  Group? byId(String id) {
    for (final group in state) {
      if (group.id == id) return group;
    }
    return null;
  }

  List<GroupMember> members(String groupId) => List.unmodifiable(_members[groupId] ?? const []);
  List<GroupMember> pendingMembers(String groupId) => members(groupId).where((m) => m.status == GroupMembershipStatus.requested).toList();
  List<GroupPost> posts(String groupId) => List.unmodifiable(_posts[groupId] ?? const []);

  void _replace(Group group) {
    state = [for (final item in state) if (item.id == group.id) group else item];
  }

  Group create({
    required String name,
    required ActivityKind kind,
    required String region,
    required String description,
    required GroupVisibility visibility,
    required GroupJoinMode joinMode,
  }) {
    final id = 'g${_groupCounter++}';
    final group = Group(
      id: id,
      name: name,
      kind: kind,
      region: region,
      memberCount: 1,
      upcomingCount: 0,
      member: true,
      myRole: GroupRole.owner,
      description: description,
      visibility: visibility,
      joinMode: joinMode,
    );
    _members[id] = const [GroupMember(user: currentUser, role: GroupRole.owner, status: GroupMembershipStatus.active)];
    _posts[id] = [];
    state = [group, ...state];
    return group;
  }

  void updateGroup(
    String id, {
    String? name,
    String? description,
    String? region,
    GroupVisibility? visibility,
    GroupJoinMode? joinMode,
    bool? membersCanCreateActivities,
  }) {
    final group = byId(id);
    if (group == null || (group.myRole != GroupRole.owner && group.myRole != GroupRole.admin)) return;
    _replace(group.copyWith(
      name: name,
      description: description,
      region: region,
      visibility: visibility,
      joinMode: joinMode,
      membersCanCreateActivities: membersCanCreateActivities,
    ));
  }

  void joinOpen(String id) {
    final group = byId(id);
    if (group == null || group.member || group.joinMode != GroupJoinMode.open) return;
    _members[id] = [...members(id), const GroupMember(user: currentUser, role: GroupRole.member, status: GroupMembershipStatus.active)];
    _replace(group.copyWith(member: true, requestPending: false, memberCount: group.memberCount + 1, myRole: GroupRole.member));
  }

  void requestMembership(String id) {
    final group = byId(id);
    if (group == null || group.member || group.requestPending || group.joinMode != GroupJoinMode.request) return;
    _replace(group.copyWith(requestPending: true));
  }

  void approveMembership(String groupId, String userId) {
    final group = byId(groupId);
    if (group == null || (group.myRole != GroupRole.owner && group.myRole != GroupRole.admin)) return;
    final list = members(groupId);
    var changed = false;
    _members[groupId] = [
      for (final member in list)
        if (member.user.id == userId && member.status == GroupMembershipStatus.requested)
          (() {
            changed = true;
            return member.copyWith(status: GroupMembershipStatus.active);
          })()
        else
          member,
    ];
    if (changed) _replace(group.copyWith(memberCount: group.memberCount + 1));
  }

  void rejectMembership(String groupId, String userId) {
    final group = byId(groupId);
    if (group == null || (group.myRole != GroupRole.owner && group.myRole != GroupRole.admin)) return;
    _members[groupId] = [
      for (final member in members(groupId))
        if (member.user.id == userId && member.status == GroupMembershipStatus.requested)
          member.copyWith(status: GroupMembershipStatus.removed)
        else
          member,
    ];
    state = [...state];
  }

  void changeRole(String groupId, String userId, GroupRole role) {
    final group = byId(groupId);
    if (group == null || group.myRole != GroupRole.owner || userId == currentUser.id) return;
    _members[groupId] = [
      for (final member in members(groupId))
        if (member.user.id == userId && member.status == GroupMembershipStatus.active) member.copyWith(role: role) else member,
    ];
    state = [...state];
  }

  void removeMember(String groupId, String userId) {
    final group = byId(groupId);
    if (group == null || (group.myRole != GroupRole.owner && group.myRole != GroupRole.admin)) return;
    final before = members(groupId);
    final removed = before.any((m) => m.user.id == userId && m.status == GroupMembershipStatus.active && m.role != GroupRole.owner);
    _members[groupId] = before.where((m) => m.user.id != userId || m.role == GroupRole.owner).toList();
    if (removed) _replace(group.copyWith(memberCount: group.memberCount > 0 ? group.memberCount - 1 : 0));
  }

  void leave(String id) {
    final group = byId(id);
    if (group == null || !group.member || group.myRole == GroupRole.owner) return;
    _members[id] = members(id).where((m) => m.user.id != currentUser.id).toList();
    _replace(group.copyWith(member: false, requestPending: false, memberCount: group.memberCount > 0 ? group.memberCount - 1 : 0, clearRole: true));
  }


  void deleteGroup(String id) {
    final group = byId(id);
    if (group == null || group.myRole != GroupRole.owner) return;
    _members.remove(id);
    _posts.remove(id);
    state = state.where((g) => g.id != id).toList();
  }

  GroupPost addPost(String groupId, String body) {
    final post = GroupPost(id: 'p${_postCounter++}', groupId: groupId, author: currentUser, body: body.trim(), createdAt: DateTime.now());
    _posts[groupId] = [...posts(groupId), post];
    state = [...state];
    return post;
  }

  void deletePost(String groupId, String postId) {
    final group = byId(groupId);
    if (group == null) return;
    _posts[groupId] = posts(groupId).where((p) => p.id != postId || (p.author.id != currentUser.id && group.myRole != GroupRole.owner && group.myRole != GroupRole.admin)).toList();
    state = [...state];
  }
}

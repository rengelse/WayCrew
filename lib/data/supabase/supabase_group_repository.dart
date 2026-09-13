import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/activity_models.dart';
import '../../domain/repositories/repositories.dart';

class SupabaseGroupRepository implements GroupRepository {
  final SupabaseClient _client;
  const SupabaseGroupRepository(this._client);

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('Ingen innlogget Supabase-bruker.');
    return id;
  }

  @override
  Future<List<Group>> mine() async {
    final memberships = await _client
        .from('group_members')
        .select('group_id')
        .eq('user_id', _userId)
        .eq('status', 'active');
    final ids = memberships.map((row) => row['group_id'] as String).toList();
    if (ids.isEmpty) return const [];
    final rows = await _client.from('groups').select().inFilter('id', ids).order('name');
    final result = <Group>[];
    for (final raw in rows) {
      result.add(await _hydrate(Map<String, dynamic>.from(raw)));
    }
    return result;
  }

  @override
  Future<List<Group>> discover() async {
    final rows = await _client.from('groups').select().eq('visibility', 'public').order('name');
    final result = <Group>[];
    for (final raw in rows) {
      final group = await _hydrate(Map<String, dynamic>.from(raw));
      if (!group.member) result.add(group);
    }
    return result;
  }

  @override
  Future<Group?> byId(String id) async {
    final row = await _client.from('groups').select().eq('id', id).maybeSingle();
    if (row == null) return null;
    return _hydrate(Map<String, dynamic>.from(row));
  }

  @override
  Future<Group> create({
    required String name,
    required ActivityKind kind,
    required String region,
    required String description,
    required GroupVisibility visibility,
    required GroupJoinMode joinMode,
  }) async {
    final raw = await _client.rpc('create_group', params: {
      'p_name': name.trim(),
      'p_activity_type': kind.name,
      'p_region': region.trim(),
      'p_description': description.trim(),
      'p_visibility': visibility.name,
      'p_join_mode': joinMode.name,
    });
    final id = raw as String?;
    if (id == null || id.isEmpty) {
      throw StateError('Supabase returnerte ingen gruppe-ID.');
    }
    final group = await byId(id);
    if (group == null) {
      throw StateError('Gruppen ble opprettet, men kunne ikke lastes inn.');
    }
    return group;
  }

  @override
  Future<List<GroupMember>> members(String groupId) async {
    final rows = await _client.from('group_members').select().eq('group_id', groupId).order('joined_at');
    return _hydrateMembers(rows);
  }

  @override
  Future<List<GroupMember>> pendingMembers(String groupId) async {
    final rows = await _client
        .from('group_members')
        .select()
        .eq('group_id', groupId)
        .eq('status', 'requested')
        .order('requested_at');
    return _hydrateMembers(rows);
  }

  Future<List<GroupMember>> _hydrateMembers(List<dynamic> rows) async {
    final ids = rows.map((row) => row['user_id'] as String).toSet().toList();
    final profiles = <String, Map<String, dynamic>>{};
    if (ids.isNotEmpty) {
      final profileRows = await _client.from('profiles').select('id,display_name,region').inFilter('id', ids);
      for (final raw in profileRows) {
        final row = Map<String, dynamic>.from(raw);
        profiles[row['id'] as String] = row;
      }
    }
    return rows.map<GroupMember>((raw) {
      final row = Map<String, dynamic>.from(raw);
      final userId = row['user_id'] as String;
      final profile = profiles[userId];
      final name = (profile?['display_name'] as String?)?.trim();
      return GroupMember(
        user: AppUser(
          id: userId,
          name: name?.isNotEmpty == true ? name! : 'Medlem',
          region: profile?['region'] as String? ?? '',
          interests: const [],
        ),
        role: _groupRole(row['role'] as String?),
        status: _membershipStatus(row['status'] as String?),
      );
    }).toList();
  }

  @override
  Future<List<GroupPost>> posts(String groupId) async {
    final rows = await _client.from('group_posts').select().eq('group_id', groupId).order('created_at');
    final ids = rows.map((row) => row['author_id'] as String).toSet().toList();
    final profiles = <String, Map<String, dynamic>>{};
    if (ids.isNotEmpty) {
      final profileRows = await _client.from('profiles').select('id,display_name,region').inFilter('id', ids);
      for (final raw in profileRows) {
        final row = Map<String, dynamic>.from(raw);
        profiles[row['id'] as String] = row;
      }
    }
    return rows.map<GroupPost>((raw) {
      final row = Map<String, dynamic>.from(raw);
      final authorId = row['author_id'] as String;
      final profile = profiles[authorId];
      final name = (profile?['display_name'] as String?)?.trim();
      return GroupPost(
        id: row['id'] as String,
        groupId: groupId,
        author: AppUser(
          id: authorId,
          name: name?.isNotEmpty == true ? name! : 'Medlem',
          region: profile?['region'] as String? ?? '',
          interests: const [],
        ),
        body: row['body'] as String? ?? '',
        createdAt: DateTime.tryParse(row['created_at'] as String? ?? '')?.toLocal() ?? DateTime.now(),
      );
    }).toList();
  }

  @override
  Future<void> addPost(String groupId, String body) async {
    final text = body.trim();
    if (text.isEmpty) return;
    await _client.from('group_posts').insert({'group_id': groupId, 'author_id': _userId, 'body': text});
  }

  @override
  Future<void> deletePost(String groupId, String postId) async {
    await _client.from('group_posts').delete().eq('id', postId).eq('group_id', groupId);
  }

  @override
  Future<void> updateGroup(
    String groupId, {
    String? name,
    String? description,
    String? region,
    GroupVisibility? visibility,
    GroupJoinMode? joinMode,
    bool? membersCanCreateActivities,
  }) async {
    final current = await byId(groupId);
    if (current == null) throw StateError('Gruppen finnes ikke.');
    await _client.rpc('update_group', params: {
      'p_group_id': groupId,
      'p_name': (name ?? current.name).trim(),
      'p_region': (region ?? current.region).trim(),
      'p_description': (description ?? current.description).trim(),
      'p_visibility': (visibility ?? current.visibility).name,
      'p_join_mode': (joinMode ?? current.joinMode).name,
      'p_members_can_create_activities': membersCanCreateActivities ?? current.membersCanCreateActivities,
    });
  }

  @override
  Future<void> joinOpen(String groupId) async {
    await _client.rpc('join_open_group', params: {'p_group_id': groupId});
  }

  @override
  Future<void> requestMembership(String groupId) async {
    await _client.rpc('request_group_membership', params: {'p_group_id': groupId});
  }

  @override
  Future<void> approveMembership(String groupId, String userId) async {
    await _client.rpc('approve_group_membership', params: {'p_group_id': groupId, 'p_user_id': userId});
  }

  @override
  Future<void> rejectMembership(String groupId, String userId) async {
    await _client.rpc('reject_group_membership', params: {'p_group_id': groupId, 'p_user_id': userId});
  }

  @override
  Future<void> changeRole(String groupId, String userId, GroupRole role) async {
    await _client.rpc('change_group_member_role', params: {
      'p_group_id': groupId,
      'p_user_id': userId,
      'p_role': role.name,
    });
  }

  @override
  Future<void> removeMember(String groupId, String userId) async {
    await _client.rpc('remove_group_member', params: {'p_group_id': groupId, 'p_user_id': userId});
  }

  @override
  Future<void> leave(String groupId) async {
    await _client.rpc('leave_group', params: {'p_group_id': groupId});
  }

  @override
  Future<void> deleteGroup(String groupId) async {
    await _client.rpc('delete_group', params: {'p_group_id': groupId});
  }

  Future<Group> _hydrate(Map<String, dynamic> row) async {
    final id = row['id'] as String;
    final membership = await _client
        .from('group_members')
        .select('role,status')
        .eq('group_id', id)
        .eq('user_id', _userId)
        .maybeSingle();
    final memberCountRaw = await _client.rpc('group_active_member_count', params: {'p_group_id': id});
    final upcomingRaw = await _client.rpc('group_upcoming_count', params: {'p_group_id': id});
    final memberCount = (memberCountRaw as num?)?.toInt() ?? 0;
    final upcoming = (upcomingRaw as num?)?.toInt() ?? 0;
    final status = membership?['status'] as String?;
    return Group(
      id: id,
      name: row['name'] as String? ?? 'Gruppe',
      kind: _activityKind(row['activity_type'] as String?),
      region: row['region'] as String? ?? '',
      memberCount: memberCount,
      upcomingCount: upcoming,
      member: status == 'active',
      requestPending: status == 'requested',
      myRole: status == 'active' ? _groupRole(membership?['role'] as String?) : null,
      description: row['description'] as String? ?? '',
      visibility: _visibility(row['visibility'] as String?),
      joinMode: _joinMode(row['join_mode'] as String?),
      membersCanCreateActivities: row['members_can_create_activities'] as bool? ?? false,
    );
  }

  ActivityKind _activityKind(String? value) => ActivityKind.values.where((e) => e.name == value).firstOrNull ?? ActivityKind.other;
  GroupRole _groupRole(String? value) => GroupRole.values.where((e) => e.name == value).firstOrNull ?? GroupRole.member;
  GroupMembershipStatus _membershipStatus(String? value) => GroupMembershipStatus.values.where((e) => e.name == value).firstOrNull ?? GroupMembershipStatus.requested;
  GroupVisibility _visibility(String? value) => GroupVisibility.values.where((e) => e.name == value).firstOrNull ?? GroupVisibility.public;
  GroupJoinMode _joinMode(String? value) => GroupJoinMode.values.where((e) => e.name == value).firstOrNull ?? GroupJoinMode.request;
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}

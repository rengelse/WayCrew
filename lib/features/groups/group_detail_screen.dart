import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design_system/app_widgets.dart';
import '../../data/providers.dart';
import '../../domain/models/activity_models.dart';
import '../../core/errors_user_facing.dart';

class GroupDetailScreen extends ConsumerStatefulWidget {
  final String groupId;
  const GroupDetailScreen({super.key, required this.groupId});

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen> {
  final postController = TextEditingController();
  bool posting = false;

  @override
  void dispose() {
    postController.dispose();
    super.dispose();
  }

  void _refreshGroup() {
    ref.invalidate(groupByIdProvider(widget.groupId));
    ref.invalidate(groupMembersProvider(widget.groupId));
    ref.invalidate(pendingGroupMembersProvider(widget.groupId));
    ref.invalidate(groupPostsProvider(widget.groupId));
    ref.invalidate(groupActivitiesProvider(widget.groupId));
    ref.invalidate(myGroupsProvider);
    ref.invalidate(discoverGroupsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final groupAsync = ref.watch(groupByIdProvider(widget.groupId));
    final membersAsync = ref.watch(groupMembersProvider(widget.groupId));
    final postsAsync = ref.watch(groupPostsProvider(widget.groupId));
    final currentUserId = ref.watch(currentActivityUserIdProvider);

    return Scaffold(
      appBar: AppBar(leading: const AppBackButton(fallbackLocation: '/groups'), title: const Text('Gruppe')),
      body: SafeArea(
        top: false,
        child: groupAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Kunne ikke laste gruppen: $e')),
        data: (group) {
          if (group == null) return const EmptyState(title: 'Gruppen finnes ikke', body: 'Gruppen kan ha blitt slettet eller du mangler tilgang.');
          final canAdmin = group.myRole == GroupRole.owner || group.myRole == GroupRole.admin;
          return RefreshIndicator(
            onRefresh: () async {
              _refreshGroup();
              await ref.read(groupByIdProvider(widget.groupId).future);
            },
            child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
              AppSection(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(children: [
                      CircleAvatar(radius: 36, child: Text(group.kind.emoji, style: const TextStyle(fontSize: 28))),
                      const SizedBox(height: 12),
                      Text(group.name, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                      Text('${group.region} · ${group.memberCount} medlemmer'),
                      const SizedBox(height: 8),
                      Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.center, children: [StatusBadge(group.visibility.label), StatusBadge(group.joinMode.label)]),
                      if (group.description.trim().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(group.description, textAlign: TextAlign.center),
                      ],
                      const SizedBox(height: 14),
                      _MembershipAction(group: group, onChanged: _refreshGroup),
                      if (group.member) ...[
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => context.push('/group/${widget.groupId}/chat'),
                              icon: const Icon(Icons.chat_bubble_outline),
                              label: const Text('Chat'),
                            ),
                          ),
                          if (canAdmin) ...[
                            const SizedBox(width: 8),
                            Expanded(child: OutlinedButton.icon(onPressed: () => context.push('/group/${widget.groupId}/admin'), icon: const Icon(Icons.tune), label: const Text('Administrer'))),
                          ],
                        ]),
                      ],
                    ]),
                  ),
                ),
              ),
              if (group.member)
                AppSection(title: 'Aktiviteter', child: _GroupActivities(group: group)),
              if (group.member)
                AppSection(
                  title: 'Innlegg',
                  child: Column(children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(children: [
                          CircleAvatar(child: Text((currentUserId == null ? '?' : 'D'))),
                          const SizedBox(width: 10),
                          Expanded(child: TextField(controller: postController, minLines: 1, maxLines: 3, decoration: const InputDecoration(hintText: 'Skriv et innlegg…'))),
                          const SizedBox(width: 8),
                          IconButton.filled(onPressed: posting ? null : _sendPost, icon: posting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send_rounded)),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 8),
                    postsAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => Text('Kunne ikke laste innlegg: $e'),
                      data: (posts) => posts.isEmpty
                          ? const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Ingen innlegg ennå.')))
                          : Column(children: posts.reversed.map((post) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Card(
                                  child: ListTile(
                                    leading: CircleAvatar(child: Text(post.author.name.isEmpty ? '?' : post.author.name.substring(0, 1).toUpperCase())),
                                    title: Text(post.author.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                                    subtitle: Text(post.body),
                                    trailing: (post.author.id == currentUserId || canAdmin)
                                        ? PopupMenuButton<String>(
                                            onSelected: (value) async {
                                              if (value == 'delete') {
                                                await ref.read(groupRepositoryProvider).deletePost(widget.groupId, post.id);
                                                ref.invalidate(groupPostsProvider(widget.groupId));
                                              }
                                            },
                                            itemBuilder: (_) => const [PopupMenuItem(value: 'delete', child: Text('Slett innlegg'))],
                                          )
                                        : null,
                                  ),
                                ),
                              )).toList()),
                    ),
                  ]),
                ),
              AppSection(
                title: 'Medlemmer',
                child: membersAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Kunne ikke laste medlemmer: $e'),
                  data: (members) => Card(
                    child: Column(children: members.where((m) => m.status == GroupMembershipStatus.active).take(8).map((member) => ListTile(
                          leading: CircleAvatar(child: Text(member.user.name.isEmpty ? '?' : member.user.name.substring(0, 1).toUpperCase())),
                          title: Text(member.user.name),
                          subtitle: Text(member.role.label),
                        )).toList()),
                  ),
                ),
              ),
            ]),
          );
        },
      ),
      ),
    );
  }

  Future<void> _sendPost() async {
    final text = postController.text.trim();
    if (text.isEmpty) return;
    setState(() => posting = true);
    try {
      await ref.read(groupRepositoryProvider).addPost(widget.groupId, text);
      postController.clear();
      ref.invalidate(groupPostsProvider(widget.groupId));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(userFacingError(error, fallback: 'Kunne ikke publisere innlegget. Prøv igjen.'))));
    } finally {
      if (mounted) setState(() => posting = false);
    }
  }
}

class _GroupActivities extends ConsumerWidget {
  final Group group;
  const _GroupActivities({required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activitiesAsync = ref.watch(groupActivitiesProvider(group.id));
    final canCreate = group.myRole == GroupRole.owner || group.myRole == GroupRole.admin || group.membersCanCreateActivities;
    return Column(children: [
      activitiesAsync.when(
        loading: () => const LinearProgressIndicator(),
        error: (e, _) => Text('Kunne ikke laste aktiviteter: $e'),
        data: (activities) {
          final visible = activities.where((a) => a.status != ActivityStatus.finished).take(3).toList();
          if (visible.isEmpty) return const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Ingen kommende aktiviteter i gruppen.')));
          return Column(children: visible.map((activity) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  child: ListTile(
                    leading: Text(activity.kind.emoji, style: const TextStyle(fontSize: 24)),
                    title: Text(activity.title),
                    subtitle: Text('${activity.status.label} · ${activity.confirmedParticipants}/${activity.maxParticipants} deltakere'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/activity/${activity.id}'),
                  ),
                ),
              )).toList());
        },
      ),
      if (canCreate)
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => context.push('/activity/new?groupId=${group.id}'),
            icon: const Icon(Icons.add),
            label: const Text('Ny aktivitet for gruppen'),
          ),
        ),
    ]);
  }
}

class _MembershipAction extends ConsumerWidget {
  final Group group;
  final VoidCallback onChanged;
  const _MembershipAction({required this.group, required this.onChanged});

  Future<void> _run(BuildContext context, WidgetRef ref, Future<void> Function() action) async {
    try {
      await action();
      onChanged();
    } catch (error) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(userFacingError(error, fallback: 'Kunne ikke oppdatere medlemskapet. Prøv igjen.'))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(groupRepositoryProvider);
    if (group.member) {
      if (group.myRole == GroupRole.owner) return const StatusBadge('Eier');
      return Row(children: [
        const Expanded(child: FilledButton.tonal(onPressed: null, child: Text('Du er medlem'))),
        const SizedBox(width: 8),
        OutlinedButton(onPressed: () => _run(context, ref, () => repo.leave(group.id)), child: const Text('Forlat')),
      ]);
    }
    if (group.requestPending) return const FilledButton(onPressed: null, child: Text('Forespørsel sendt'));
    if (group.joinMode == GroupJoinMode.open) {
      return FilledButton(onPressed: () => _run(context, ref, () => repo.joinOpen(group.id)), child: const Text('Bli med'));
    }
    if (group.joinMode == GroupJoinMode.inviteOnly) return const FilledButton(onPressed: null, child: Text('Kun invitasjon'));
    return FilledButton(onPressed: () => _run(context, ref, () => repo.requestMembership(group.id)), child: const Text('Be om medlemskap'));
  }
}

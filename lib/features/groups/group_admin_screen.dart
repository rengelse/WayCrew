import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/app_theme.dart';
import '../../core/design_system/app_widgets.dart';
import '../../data/mock/providers.dart';
import '../../domain/models/activity_models.dart';

class GroupAdminScreen extends ConsumerStatefulWidget {
  final String groupId;
  const GroupAdminScreen({super.key, required this.groupId});
  @override
  ConsumerState<GroupAdminScreen> createState() => _GroupAdminScreenState();
}

class _GroupAdminScreenState extends ConsumerState<GroupAdminScreen> {
  final name = TextEditingController();
  final region = TextEditingController();
  final description = TextEditingController();
  bool initialized = false;
  GroupVisibility visibility = GroupVisibility.public;
  GroupJoinMode joinMode = GroupJoinMode.request;
  bool membersCanCreate = false;

  @override
  void dispose() {
    name.dispose();
    region.dispose();
    description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groupAsync = ref.watch(groupByIdProvider(widget.groupId));
    final membersAsync = ref.watch(groupMembersProvider(widget.groupId));
    final pendingAsync = ref.watch(pendingGroupMembersProvider(widget.groupId));
    return Scaffold(
      appBar: AppBar(leading: AppBackButton(fallbackLocation: '/group/${widget.groupId}'), title: const Text('Administrer gruppe')),
      body: SafeArea(
        top: false,
        child: groupAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (group) {
          if (group == null) return const EmptyState(title: 'Gruppen finnes ikke', body: 'Kunne ikke åpne administrasjonen.');
          if (!initialized) {
            name.text = group.name;
            region.text = group.region;
            description.text = group.description;
            visibility = group.visibility;
            joinMode = group.joinMode;
            membersCanCreate = group.membersCanCreateActivities;
            initialized = true;
          }
          if (group.myRole != GroupRole.owner && group.myRole != GroupRole.admin) {
            return const EmptyState(title: 'Ingen tilgang', body: 'Kun eier og administrator kan endre gruppen.');
          }
          return ListView(padding: const EdgeInsets.only(bottom: 24), children: [
            AppSection(
              title: 'Gruppeinnstillinger',
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    TextField(controller: name, decoration: const InputDecoration(labelText: 'Navn')),
                    const SizedBox(height: 10),
                    TextField(controller: region, decoration: const InputDecoration(labelText: 'Område')),
                    const SizedBox(height: 10),
                    TextField(controller: description, maxLines: 3, decoration: const InputDecoration(labelText: 'Beskrivelse')),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<GroupVisibility>(
                      initialValue: visibility,
                      decoration: const InputDecoration(labelText: 'Synlighet'),
                      items: GroupVisibility.values.map((item) => DropdownMenuItem(value: item, child: Text(item.label))).toList(),
                      onChanged: (value) => setState(() => visibility = value ?? visibility),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<GroupJoinMode>(
                      initialValue: joinMode,
                      decoration: const InputDecoration(labelText: 'Medlemskap'),
                      items: GroupJoinMode.values.map((item) => DropdownMenuItem(value: item, child: Text(item.label))).toList(),
                      onChanged: (value) => setState(() => joinMode = value ?? joinMode),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Medlemmer kan opprette aktiviteter'),
                      value: membersCanCreate,
                      onChanged: (value) => setState(() => membersCanCreate = value),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(width: double.infinity, child: FilledButton(onPressed: _save, child: const Text('Lagre endringer'))),
                  ]),
                ),
              ),
            ),
            AppSection(
              title: 'Medlemsforespørsler',
              child: pendingAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('$e'),
                data: (items) => items.isEmpty
                    ? const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Ingen ventende forespørsler.')))
                    : Card(
                        child: Column(
                          children: items.map((member) => ListTile(
                            leading: CircleAvatar(child: Text(member.user.name.substring(0, 1))),
                            title: Text(member.user.name),
                            subtitle: Text(member.user.region),
                            trailing: Wrap(spacing: 6, children: [
                              TextButton(
                                onPressed: () async { await ref.read(groupRepositoryProvider).rejectMembership(widget.groupId, member.user.id); _refresh(); },
                                child: const Text('Avslå'),
                              ),
                              FilledButton.tonal(
                                onPressed: () async { await ref.read(groupRepositoryProvider).approveMembership(widget.groupId, member.user.id); _refresh(); },
                                child: const Text('Godkjenn'),
                              ),
                            ]),
                          )).toList(),
                        ),
                      ),
              ),
            ),
            AppSection(
              title: 'Medlemmer',
              child: membersAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('$e'),
                data: (items) => Card(
                  child: Column(
                    children: items.where((m) => m.status == GroupMembershipStatus.active).map((member) => ListTile(
                      leading: CircleAvatar(child: Text(member.user.name.substring(0, 1))),
                      title: Text(member.user.name),
                      subtitle: Text(member.role.label),
                      trailing: member.role == GroupRole.owner
                          ? const StatusBadge('Eier')
                          : (group.myRole == GroupRole.admin && member.role == GroupRole.admin)
                              ? const StatusBadge('Administrator')
                              : PopupMenuButton<String>(
                                  onSelected: (value) async {
                                    if (value == 'admin') await ref.read(groupRepositoryProvider).changeRole(widget.groupId, member.user.id, GroupRole.admin);
                                    if (value == 'member') await ref.read(groupRepositoryProvider).changeRole(widget.groupId, member.user.id, GroupRole.member);
                                    if (value == 'remove') await ref.read(groupRepositoryProvider).removeMember(widget.groupId, member.user.id);
                                    _refresh();
                                  },
                                  itemBuilder: (_) => [
                                    if (group.myRole == GroupRole.owner) ...const [
                                      PopupMenuItem(value: 'admin', child: Text('Gjør til administrator')),
                                      PopupMenuItem(value: 'member', child: Text('Gjør til medlem')),
                                      PopupMenuDivider(),
                                    ],
                                    const PopupMenuItem(value: 'remove', child: Text('Fjern medlem')),
                                  ],
                                ),
                    )).toList(),
                  ),
                ),
              ),
            ),
            if (group.myRole == GroupRole.owner)
              AppSection(
                title: 'Slett gruppe',
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Dette sletter gruppen permanent. Gruppechat, innlegg og medlemskap fjernes. Aktiviteter beholdes, men koblingen til gruppen fjernes.'),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _deleteGroup,
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Slett gruppe permanent'),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            const SizedBox(height: AppTokens.page),
          ]);
        },
      ),
      ),
    );
  }


  void _refresh() {
    ref.invalidate(groupByIdProvider(widget.groupId));
    ref.invalidate(groupMembersProvider(widget.groupId));
    ref.invalidate(pendingGroupMembersProvider(widget.groupId));
    ref.invalidate(myGroupsProvider);
    ref.invalidate(discoverGroupsProvider);
  }

  Future<void> _save() async {
    final cleanName = name.text.trim();
    if (cleanName.length < 2 || cleanName.length > 120) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gruppenavnet må være mellom 2 og 120 tegn.')));
      return;
    }
    try {
      await ref.read(groupRepositoryProvider).updateGroup(
            widget.groupId,
            name: cleanName,
            region: region.text.trim(),
            description: description.text.trim(),
            visibility: visibility,
            joinMode: joinMode,
            membersCanCreateActivities: membersCanCreate,
          );
      _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gruppeinnstillingene er lagret.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Kunne ikke lagre gruppeinnstillingene: $error')));
    }
  }

  Future<void> _deleteGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Slett gruppe?'),
        content: const Text('Gruppen slettes permanent. Dette kan ikke angres.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Avbryt')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Slett gruppe')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(groupRepositoryProvider).deleteGroup(widget.groupId);
      ref.invalidate(myGroupsProvider);
      ref.invalidate(discoverGroupsProvider);
      if (!mounted) return;
      context.go('/groups');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gruppen er slettet.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Kunne ikke slette gruppen: $error')));
    }
  }

}

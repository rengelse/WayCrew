import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/app_theme.dart';
import '../../core/design_system/app_widgets.dart';
import '../../data/providers.dart';
import '../../domain/models/activity_models.dart';

class GroupsScreen extends ConsumerStatefulWidget {
  const GroupsScreen({super.key});
  @override
  ConsumerState<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends ConsumerState<GroupsScreen> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final mine = ref.watch(myGroupsProvider);
    final discover = ref.watch(discoverGroupsProvider);
    bool match(dynamic g) => query.trim().isEmpty || '${g.name} ${g.region} ${g.kind.label}'.toLowerCase().contains(query.trim().toLowerCase());
    return Scaffold(
      appBar: AppBar(
        title: const Text('Grupper'),
        actions: [IconButton(onPressed: () => context.push('/group/new'), icon: const Icon(Icons.add_rounded))],
      ),
      body: ListView(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTokens.page),
          child: TextField(
            onChanged: (v) => setState(() => query = v),
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Søk etter gruppe'),
          ),
        ),
        AppSection(
          title: 'Mine grupper',
          child: mine.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('$e'),
            data: (items) {
              final filtered = items.where(match).toList();
              return filtered.isEmpty
                  ? const Text('Ingen grupper matcher søket.')
                  : Column(children: filtered.map((g) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        child: ListTile(
                          onTap: () => context.push('/group/${g.id}'),
                          leading: CircleAvatar(child: Text(g.kind.emoji)),
                          title: Text(g.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text('${g.memberCount} medlemmer · ${g.upcomingCount} kommende'),
                          trailing: g.myRole != null ? StatusBadge(g.myRole!.label) : const Icon(Icons.chevron_right_rounded),
                        ),
                      ),
                    )).toList());
            },
          ),
        ),
        AppSection(
          title: 'Oppdag grupper',
          child: discover.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('$e'),
            data: (items) {
              final filtered = items.where(match).toList();
              return filtered.isEmpty
                  ? const Text('Ingen nye grupper matcher søket.')
                  : Column(children: filtered.map((g) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        child: ListTile(
                          onTap: () => context.push('/group/${g.id}'),
                          leading: CircleAvatar(child: Text(g.kind.emoji)),
                          title: Text(g.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text('${g.region} · ${g.memberCount} medlemmer · ${g.joinMode.label}'),
                          trailing: g.requestPending ? const StatusBadge('Venter') : const Icon(Icons.chevron_right_rounded),
                        ),
                      ),
                    )).toList());
            },
          ),
        ),
      ]),
    );
  }
}

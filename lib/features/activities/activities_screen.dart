import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/app_theme.dart';
import '../../core/design_system/app_widgets.dart';
import '../../data/providers.dart';
import '../../domain/models/activity_models.dart';

class ActivitiesScreen extends ConsumerWidget {
  const ActivitiesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activities = ref.watch(filteredActivitiesProvider);
    final filter = ref.watch(activityFilterProvider);
    final filters = ref.read(activityFilterProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('Aktiviteter'), actions: [IconButton(onPressed: () => _showFilterSheet(context, ref), icon: const Icon(Icons.tune_rounded))]),
      body: Column(children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: AppTokens.page), child: TextField(onChanged: filters.setQuery, decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: 'Søk aktivitet, sted eller gruppe', suffixIcon: filter.query.isEmpty ? null : IconButton(onPressed: () => filters.setQuery(''), icon: const Icon(Icons.close))))),
        const SizedBox(height: 8),
        _TimeTabs(filter: filter),
        if (filter.kind != null || filter.openOnly) Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 0), child: Align(alignment: Alignment.centerLeft, child: Wrap(spacing: 6, children: [if (filter.kind != null) InputChip(label: Text(filter.kind!.label), onDeleted: () => filters.setKind(null)), if (filter.openOnly) InputChip(label: const Text('Åpen for flere'), onDeleted: () => filters.setOpenOnly(false))]))),
        Expanded(child: activities.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (items) => items.isEmpty
              ? EmptyState(title: 'Ingen aktiviteter passer filtrene dine', body: 'Nullstill filtrene eller prøv et annet tidsrom.', action: 'Nullstill filtre', onAction: filters.reset)
              : ListView(padding: const EdgeInsets.all(AppTokens.page), children: [
                  if (items.any((a) => a.mine)) ...[Text('Dine aktiviteter', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)), const SizedBox(height: 10), ...items.where((a) => a.mine).map((a) => Padding(padding: const EdgeInsets.only(bottom: 10), child: ActivityCard(activity: a, onTap: () => context.push('/activity/${a.id}')))), const SizedBox(height: 8)],
                  Text('Oppdag', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  ...items.where((a) => !a.mine).map((a) => Padding(padding: const EdgeInsets.only(bottom: 10), child: ActivityCard(activity: a, onTap: () => context.push('/activity/${a.id}')))),
                ]),
        )),
      ]),
    );
  }

  void _showFilterSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(context: context, showDragHandle: true, builder: (context) => Consumer(builder: (context, sheetRef, _) {
      final filter = sheetRef.watch(activityFilterProvider);
      final store = sheetRef.read(activityFilterProvider.notifier);
      return SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 20), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Filtrer aktiviteter', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)), const SizedBox(height: 14),
        const Text('Aktivitetstype'), const SizedBox(height: 8), Wrap(spacing: 8, runSpacing: 8, children: [ChoiceChip(label: const Text('Alle'), selected: filter.kind == null, onSelected: (_) => store.setKind(null)), ...ActivityKind.values.where((k) => k != ActivityKind.other).map((k) => ChoiceChip(label: Text(k.label), selected: filter.kind == k, onSelected: (_) => store.setKind(k)))]),
        const SizedBox(height: 14), SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Kun aktiviteter du kan bli med på'), value: filter.openOnly, onChanged: store.setOpenOnly),
        const SizedBox(height: 8), Row(children: [Expanded(child: OutlinedButton(onPressed: () { store.reset(); Navigator.pop(context); }, child: const Text('Nullstill'))), const SizedBox(width: 8), Expanded(child: FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Vis resultater')))]),
      ])));
    }));
  }
}

class _TimeTabs extends ConsumerWidget {
  final ActivityFilterState filter;
  const _TimeTabs({required this.filter});
  @override
  Widget build(BuildContext context, WidgetRef ref) => SizedBox(height: 42, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: ActivityTimeFilter.values.map((t) => Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(t.label), selected: filter.time == t, onSelected: (_) => ref.read(activityFilterProvider.notifier).setTime(t)))).toList()));
}

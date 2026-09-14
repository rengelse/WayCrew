import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design_system/app_widgets.dart';
import '../../core/map/history_route_map.dart';
import '../../data/providers.dart';
import '../../domain/models/activity_models.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncActivities = ref.watch(activitiesProvider);
    final asyncHistory = ref.watch(activityHistoryProvider);
    return Scaffold(
      appBar: AppBar(leading: const AppBackButton(fallbackLocation: '/profile'), title: const Text('Mine aktiviteter')),
      body: asyncActivities.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Kunne ikke laste aktivitetene: $e')),
        data: (activities) {
          final mine = activities.where((a) => a.mine).toList();
          final upcoming = mine.where((a) => a.status == ActivityStatus.planned || a.status == ActivityStatus.gathering).toList();
          final active = mine.where((a) => a.status == ActivityStatus.active || a.status == ActivityStatus.paused).toList();
          return DefaultTabController(length: 3, child: Column(children: [
            const TabBar(tabs: [Tab(text: 'Kommende'), Tab(text: 'Aktive'), Tab(text: 'Historikk')]),
            Expanded(child: TabBarView(children: [
              _ActivityList(items: upcoming, empty: 'Ingen kommende aktiviteter.'),
              _ActivityList(items: active, empty: 'Ingen aktive aktiviteter.'),
              asyncHistory.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Kunne ikke laste historikk: $e')),
                data: (history) => history.isEmpty
                    ? const Center(child: Text('Ingen lagret historikk.'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: history.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final h = history[index];
                          return Card(child: ListTile(
                            leading: Text(h.kind.emoji, style: const TextStyle(fontSize: 26)),
                            title: Text(h.title),
                            subtitle: Text('${_date(h.date)} · ${h.distanceKm.toStringAsFixed(0)} km · ${_duration(h.durationMinutes)} · ${h.role}'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => context.push('/history/${h.id}'),
                          ));
                        },
                      ),
              ),
            ])),
          ]));
        },
      ),
    );
  }

  static String _date(DateTime d) => '${d.day}.${d.month}.${d.year}';
  static String _duration(int minutes) => '${minutes ~/ 60} t ${minutes % 60} min';
}

class _ActivityList extends StatelessWidget {
  final List<Activity> items; final String empty;
  const _ActivityList({required this.items, required this.empty});
  @override Widget build(BuildContext context) => items.isEmpty ? Center(child: Text(empty)) : ListView.separated(
    padding: const EdgeInsets.all(16),
    itemCount: items.length,
    separatorBuilder: (_, __) => const SizedBox(height: 10),
    itemBuilder: (context, index) {
      final a = items[index];
      return Card(child: ListTile(leading: Text(a.kind.emoji, style: const TextStyle(fontSize: 26)), title: Text(a.title), subtitle: Text('${a.status.label} · ${a.routeLabel}'), trailing: const Icon(Icons.chevron_right), onTap: () => context.push(a.isLive ? '/activity/${a.id}/live' : '/activity/${a.id}')));
    },
  );
}

class HistoryDetailScreen extends ConsumerWidget {
  final String historyId;
  const HistoryDetailScreen({super.key, required this.historyId});

  @override Widget build(BuildContext context, WidgetRef ref) {
    final entryAsync = ref.watch(historyByIdProvider(historyId));
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallbackLocation: '/history'),
        title: const Text('Historikk'),
        actions: [IconButton(tooltip: 'Slett fra min historikk', onPressed: () => _delete(context, ref), icon: const Icon(Icons.delete_outline))],
      ),
      body: entryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Kunne ikke laste historikken: $e')),
        data: (entry) {
          if (entry == null) {
            return SafeArea(top: false, child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Historikken finnes ikke lenger.'), const SizedBox(height: 12),
              FilledButton.icon(onPressed: () => context.go('/history'), icon: const Icon(Icons.arrow_back), label: const Text('Til historikk')),
            ])));
          }
          final route = ref.watch(routeHistoryProvider(historyId));
          final events = entry.sourceActivityId == null ? const AsyncData<List<ActivityEvent>>(<ActivityEvent>[]) : ref.watch(activityEventsProvider(entry.sourceActivityId!));
          return SafeArea(top: false, child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 28), children: [
            Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Text(entry.kind.emoji, style: const TextStyle(fontSize: 34)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(entry.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                Text('${entry.date.day}.${entry.date.month}.${entry.date.year} · ${entry.role}'),
              ]))]),
              const SizedBox(height: 18),
              Row(children: [Expanded(child: _Metric('${entry.distanceKm.toStringAsFixed(0)} km', 'Distanse')), Expanded(child: _Metric('${entry.durationMinutes ~/ 60} t ${entry.durationMinutes % 60} min', 'Varighet')), Expanded(child: _Metric('${entry.participantCount}', 'Deltakere'))]),
            ]))),
            const SizedBox(height: 12),
            route.when(
              loading: () => const Card(child: Padding(padding: EdgeInsets.all(18), child: LinearProgressIndicator())),
              error: (_, __) => Card(child: ListTile(leading: const Icon(Icons.route), title: const Text('Rute'), subtitle: Text(entry.routeLabel))),
              data: (points) => Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.route), title: const Text('Rutehistorikk'), subtitle: Text(points.isEmpty ? 'Ingen GPS-rute ble lagret' : '${points.length} GPS-punkter · ${entry.routeLabel}')),
                if (points.length >= 2) SizedBox(height: 280, child: HistoryRouteMap(points: points)),
              ]))),
            ),
            const SizedBox(height: 12),
            if (entry.sourceActivityId != null) Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Aktivitetslogg', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              events.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const Text('Kunne ikke laste aktivitetsloggen.'),
                data: (items) => items.isEmpty ? const Text('Ingen hendelser lagret.') : Column(children: items.reversed.take(12).map((e) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(Icons.circle, size: 10),
                  title: Text(_eventLabel(e)),
                  subtitle: Text('${e.createdAt.hour.toString().padLeft(2, '0')}:${e.createdAt.minute.toString().padLeft(2, '0')}'),
                )).toList()),
              ),
            ]))),
          ]));
        },
      ),
    );
  }

  String _eventLabel(ActivityEvent event) => switch (event.eventType) {
    'activity_created' => 'Aktiviteten ble opprettet',
    'status_changed' => 'Status: ${event.data['from'] ?? ''} → ${event.data['to'] ?? ''}',
    'meeting_point_changed' => 'Møtepunkt ble endret',
    'participant_requested' => 'Ny deltakelsesforespørsel',
    'participant_status_changed' => 'Deltakerstatus ble oppdatert',
    _ => event.eventType.replaceAll('_', ' '),
  };

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Slett fra min historikk?'),
      content: const Text('Dette fjerner historikkposten og din lagrede rute fra kontoen din.'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Avbryt')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Slett'))],
    ));
    if (confirmed != true) return;
    await ref.read(historyRepositoryProvider)?.remove(historyId);
    ref.invalidate(activityHistoryProvider);
    if (!context.mounted) return;
    if (context.canPop()) { context.pop(); } else { context.go('/history'); }
  }
}

class _Metric extends StatelessWidget { final String value; final String label; const _Metric(this.value, this.label); @override Widget build(BuildContext context) => Column(children: [Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)), Text(label, style: Theme.of(context).textTheme.bodySmall)]); }

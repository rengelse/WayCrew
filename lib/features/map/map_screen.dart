import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/app_theme.dart';
import '../../core/design_system/app_widgets.dart';
import '../../core/map/activity_map.dart';
import '../../data/providers.dart';
import '../../domain/models/activity_models.dart';

class MapScreen extends ConsumerWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activities = ref.watch(filteredActivitiesProvider);
    final filter = ref.watch(activityFilterProvider);
    final filterStore = ref.read(activityFilterProvider.notifier);
    final unread = (ref.watch(notificationsProvider).valueOrNull ?? const <AppNotification>[]).where((n) => !n.read).length;
    final publicStates = ref.watch(activityPublicStatesProvider).valueOrNull ?? const <ActivityPublicState>[];
    final publicStateMap = {for (final state in publicStates) state.activityId: state};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Utforsk'),
        actions: [
          _NotificationButton(unread: unread),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppTokens.page, 4, AppTokens.page, 8),
          child: TextField(
            onChanged: filterStore.setQuery,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Søk etter sted, aktivitet eller gruppe',
              suffixIcon: IconButton(onPressed: () => context.push('/activities'), icon: const Icon(Icons.tune_rounded)),
            ),
          ),
        ),
        SizedBox(
          height: 42,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: AppTokens.page),
            scrollDirection: Axis.horizontal,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(label: const Text('Alle'), selected: filter.kind == null, onSelected: (_) => filterStore.setKind(null)),
              ),
              ...[ActivityKind.motorcycle, ActivityKind.cycling, ActivityKind.ski, ActivityKind.hiking, ActivityKind.kayak].map(
                (k) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(label: Text(k.label), selected: filter.kind == k, onSelected: (_) => filterStore.setKind(k)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: activities.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Kunne ikke laste aktiviteter: $e')),
            data: (items) {
              if (items.isEmpty) {
                return EmptyState(
                  title: 'Ingen aktiviteter her akkurat nå',
                  body: 'Prøv et annet filter eller start din egen aktivitet.',
                  action: '+ Start aktivitet',
                  onAction: () => context.push('/activity/new'),
                );
              }
              final ownLive = items.where((a) => a.mine && (a.isLive || a.status == ActivityStatus.gathering)).toList();
              final selected = ownLive.isNotEmpty ? ownLive.first : items.first;
              return Stack(children: [
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: ActivityMap(
                      activities: items,
                      selectedActivityId: selected.id,
                      onActivityTap: (activity) => context.push('/activity/${activity.id}'),
                      publicStates: publicStateMap,
                    ),
                  ),
                ),
                Positioned(
                  left: 22,
                  right: 22,
                  bottom: 22,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        if (selected.mine)
                          Text(
                            'DIN AKTIVITET',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1, color: Theme.of(context).colorScheme.primary),
                          ),
                        Row(children: [
                          Expanded(child: Text(selected.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
                          StatusBadge(selected.status.label),
                        ]),
                        const SizedBox(height: 6),
                        Text('${selected.routeLabel} · ${selected.confirmedParticipants} deltakere'),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(child: OutlinedButton(onPressed: () => context.push('/activity/${selected.id}'), child: const Text('Se tur'))),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton(
                              onPressed: selected.isLive || selected.status == ActivityStatus.gathering
                                  ? () => context.push('/activity/${selected.id}/live')
                                  : () => context.push('/activity/${selected.id}'),
                              child: Text(selected.isLive || selected.status == ActivityStatus.gathering ? 'Åpne live' : 'Se aktivitet'),
                            ),
                          ),
                        ]),
                      ]),
                    ),
                  ),
                ),
              ]);
            },
          ),
        ),
      ]),
    );
  }
}

class _NotificationButton extends StatelessWidget {
  final int unread;
  const _NotificationButton({required this.unread});
  @override
  Widget build(BuildContext context) => Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(onPressed: () => context.push('/notifications'), icon: const Icon(Icons.notifications_none_rounded)),
          if (unread > 0)
            Positioned(
              right: 7,
              top: 7,
              child: Container(
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.error, borderRadius: BorderRadius.circular(99)),
                alignment: Alignment.center,
                child: Text('$unread', style: TextStyle(color: Theme.of(context).colorScheme.onError, fontSize: 10, fontWeight: FontWeight.w800)),
              ),
            ),
        ],
      );
}

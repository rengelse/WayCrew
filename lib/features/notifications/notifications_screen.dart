import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design_system/app_widgets.dart';
import '../../data/mock/providers.dart';
import '../../domain/models/activity_models.dart';
import '../auth/auth_controller.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});
  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  NotificationCategory? filter;

  @override
  Widget build(BuildContext context) {
    final demo = ref.watch(localDemoModeProvider);
    final asyncItems = ref.watch(notificationsProvider);
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallbackLocation: '/map'),
        title: const Text('Varsler'),
        actions: [TextButton(onPressed: () => _markAllRead(demo), child: const Text('Merk alle lest'))],
      ),
      body: SafeArea(
        top: false,
        child: asyncItems.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.sync_problem_outlined, size: 42),
              const SizedBox(height: 12),
              const Text('Kunne ikke laste varsler.'),
              const SizedBox(height: 6),
              Text('$e', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () => ref.invalidate(notificationsProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Prøv igjen'),
              ),
            ]),
          ),
        ),
        data: (items) {
          final visible = items.where((item) => filter == null || item.category == filter).toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return ListView(padding: const EdgeInsets.only(bottom: 16), children: [
            const SizedBox(height: 8),
            SizedBox(height: 42, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
              _filterChip('Alle', null),
              _filterChip('Aktiviteter', NotificationCategory.activities),
              _filterChip('Grupper', NotificationCategory.groups),
              _filterChip('Meldinger', NotificationCategory.messages),
              _filterChip('Viktig', NotificationCategory.important),
            ])),
            if (visible.isEmpty)
              const EmptyState(title: 'Ingen varsler her', body: 'Nye hendelser dukker opp når noe relevant skjer.')
            else
              AppSection(child: Card(child: Column(children: [
                for (var i = 0; i < visible.length; i++) ...[
                  _notificationTile(visible[i], demo),
                  if (i != visible.length - 1) const Divider(height: 1),
                ],
              ]))),
          ]);
        },
      ),
      ),
    );
  }

  Widget _filterChip(String label, NotificationCategory? value) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(label: Text(label), selected: filter == value, onSelected: (_) => setState(() => filter = value)),
  );

  Widget _notificationTile(AppNotification item, bool demo) {
    final icon = switch (item.category) {
      NotificationCategory.activities => Icons.explore_outlined,
      NotificationCategory.groups => Icons.groups_outlined,
      NotificationCategory.messages => Icons.chat_bubble_outline,
      NotificationCategory.important => Icons.priority_high_rounded,
    };
    return ListTile(
      tileColor: item.read ? null : Theme.of(context).colorScheme.primaryContainer.withValues(alpha: .16),
      leading: CircleAvatar(child: Icon(icon)),
      title: Text(item.title, style: TextStyle(fontWeight: item.read ? FontWeight.w600 : FontWeight.w800)),
      subtitle: Text(item.body),
      trailing: item.priority == NotificationPriority.critical ? const StatusBadge('Viktig') : const Icon(Icons.chevron_right),
      onTap: () async {
        await _markRead(item.id, demo);
        if (mounted && item.route != null) context.push(item.route!);
      },
      onLongPress: () => _remove(item.id, demo),
    );
  }

  Future<void> _markRead(String id, bool demo) async {
    if (demo) {
      ref.read(mockNotificationStoreProvider.notifier).markRead(id);
    } else {
      await ref.read(notificationRepositoryProvider)?.markRead(id);
    }
  }

  Future<void> _markAllRead(bool demo) async {
    if (demo) {
      ref.read(mockNotificationStoreProvider.notifier).markAllRead();
    } else {
      await ref.read(notificationRepositoryProvider)?.markAllRead();
    }
  }

  Future<void> _remove(String id, bool demo) async {
    if (demo) {
      ref.read(mockNotificationStoreProvider.notifier).remove(id);
    } else {
      await ref.read(notificationRepositoryProvider)?.remove(id);
    }
  }
}

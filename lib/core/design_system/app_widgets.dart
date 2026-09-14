import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../app/app_theme.dart';
import '../../domain/models/activity_models.dart';


class AppBackButton extends StatelessWidget {
  final String fallbackLocation;
  const AppBackButton({super.key, required this.fallbackLocation});

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Tilbake',
    icon: const Icon(Icons.arrow_back),
    onPressed: () {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(fallbackLocation);
      }
    },
  );
}

class AppPage extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget>? actions;
  const AppPage({super.key, required this.title, required this.child, this.actions});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title), actions: actions),
    body: SafeArea(child: child),
  );
}

class AppSection extends StatelessWidget {
  final String? title;
  final Widget child;
  final Widget? trailing;
  const AppSection({super.key, this.title, this.trailing, required this.child});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(AppTokens.page, 8, AppTokens.page, 8),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (title != null) ...[
        Row(children: [
          Expanded(child: Text(title!, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
          if (trailing != null) trailing!,
        ]),
        const SizedBox(height: 10),
      ],
      child,
    ]),
  );
}

class StatusBadge extends StatelessWidget {
  final String label;
  const StatusBadge(this.label, {super.key});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer, fontWeight: FontWeight.w700, fontSize: 12)),
  );
}

class ActivityCard extends StatelessWidget {
  final Activity activity;
  final VoidCallback onTap;
  const ActivityCard({super.key, required this.activity, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(activity.kind.emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 8),
              Expanded(child: Text(activity.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
              StatusBadge(activity.status.label),
            ]),
            const SizedBox(height: 10),
            Text(activity.routeLabel),
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.schedule_outlined, size: 16),
              const SizedBox(width: 6),
              Text(DateFormat('dd.MM.yyyy HH:mm').format(activity.startsAt), style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 6),
            Text('${activity.confirmedParticipants}/${activity.maxParticipants} deltakere · ${activity.distanceKm.toStringAsFixed(0)} km unna', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 6, children: [
              Chip(label: Text(activity.pace)),
              Chip(label: Text(activity.surface)),
              Chip(label: Text(switch (activity.participationMode) {
                ParticipationMode.open => 'Åpen',
                ParticipationMode.request => 'Forespørsel',
                ParticipationMode.groupOnly => 'Kun gruppe',
                ParticipationMode.private => 'Privat',
              })),
            ]),
          ]),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final String title;
  final String body;
  final String? action;
  final VoidCallback? onAction;
  const EmptyState({super.key, required this.title, required this.body, this.action, this.onAction});
  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.explore_outlined, size: 52),
      const SizedBox(height: 16),
      Text(title, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
      const SizedBox(height: 8),
      Text(body, textAlign: TextAlign.center),
      if (action != null) ...[const SizedBox(height: 16), FilledButton(onPressed: onAction, child: Text(action!))],
    ]),
  ));
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/design_system/app_widgets.dart';
import '../../core/map/activity_map.dart';
import '../../core/map/meeting_point_map.dart';
import '../../data/mock/providers.dart';
import '../../domain/models/activity_models.dart';
import '../auth/auth_controller.dart';

class ActivityDetailScreen extends ConsumerWidget {
  final String activityId;
  const ActivityDetailScreen({super.key, required this.activityId});

  Future<void> _join(BuildContext context, WidgetRef ref, Activity a) async {
    final repo = ref.read(activityRepositoryProvider);
    if (a.participationMode == ParticipationMode.open) {
      await repo.joinOpen(a.id);
      ref.invalidate(activityByIdProvider(a.id));
      ref.invalidate(activitiesProvider);
      ref.invalidate(filteredActivitiesProvider);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Du er nå med på aktiviteten.')));
    } else {
      await repo.requestToJoin(a.id);
      ref.invalidate(activityByIdProvider(a.id));
      ref.invalidate(activitiesProvider);
      ref.invalidate(filteredActivitiesProvider);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Forespørselen er sendt.')));
    }
  }

  @override Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(activityByIdProvider(activityId));
    final publicState = ref.watch(activityPublicStateProvider(activityId)).valueOrNull;
    return async.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Kunne ikke laste aktivitet: $e'))),
      data: (a) {
        if (a == null) return const Scaffold(body: Center(child: Text('Aktiviteten er ikke tilgjengelig.')));
        final currentUserId = ref.watch(currentActivityUserIdProvider);
        final currentParticipant = a.participants.where((p) => p.user.id == currentUserId).firstOrNull;
        final isLeader = currentParticipant?.role == ParticipantRole.leader;
        final isParticipant = currentParticipant != null &&
            (currentParticipant.status == ParticipantStatus.approved || currentParticipant.status == ParticipantStatus.active);
        final button = _primaryButton(context, ref, a, isLeader, isParticipant);
        return Scaffold(
          appBar: AppBar(
            leading: const AppBackButton(fallbackLocation: '/activities'),
            title: Text(a.title),
            actions: [
              if (isLeader)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: 'Administrer aktivitet',
                  onSelected: (value) => _handleLeaderAction(context, ref, a, value),
                  itemBuilder: (_) => [
                    if (a.status == ActivityStatus.planned)
                      const PopupMenuItem(value: 'gathering', child: ListTile(leading: Icon(Icons.groups_outlined), title: Text('Start samling'))),
                    if (a.status == ActivityStatus.gathering)
                      const PopupMenuItem(value: 'active', child: ListTile(leading: Icon(Icons.play_arrow), title: Text('Start aktivitet'))),
                    if (a.status == ActivityStatus.active)
                      const PopupMenuItem(value: 'paused', child: ListTile(leading: Icon(Icons.pause), title: Text('Pause aktivitet'))),
                    if (a.status == ActivityStatus.paused)
                      const PopupMenuItem(value: 'active', child: ListTile(leading: Icon(Icons.play_arrow), title: Text('Fortsett aktivitet'))),
                    if (a.isLive || a.status == ActivityStatus.gathering)
                      const PopupMenuItem(value: 'finished', child: ListTile(leading: Icon(Icons.stop_circle_outlined), title: Text('Avslutt aktivitet'))),
                    const PopupMenuDivider(),
                    const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_outline), title: Text('Slett aktivitet'))),
                  ],
                ),
            ],
          ),
          bottomNavigationBar: SafeArea(child: Padding(padding: const EdgeInsets.all(12), child: button)),
          body: ListView(children: [
            SizedBox(
              height: 220,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ActivityMap(activities: [a], selectedActivityId: a.id, compact: true, publicStates: publicState == null ? const {} : {a.id: publicState}),
              ),
            ),
            Padding(padding: const EdgeInsets.all(16), child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(a.title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)), Text(a.routeLabel)])), StatusBadge(a.status.label)])),
            _section(context, 'Nøkkelinformasjon', Card(child: Padding(padding: const EdgeInsets.all(14), child: Wrap(spacing: 18, runSpacing: 12, children: [Text('📅 ${DateFormat('dd.MM.yyyy HH:mm').format(a.startsAt)}'), Text('📍 ${a.meetingPoint}'), Text('👥 ${a.participants.length}/${a.maxParticipants}'), if (a.routePlan.distanceKm > 0) Text('🧭 ${a.routePlan.distanceKm.toStringAsFixed(1)} km'), if (a.routePlan.durationMinutes > 0) Text('⏱️ ca. ${a.routePlan.durationMinutes} min'), Text('⚡ ${a.pace}'), Text('🛣️ ${a.surface}')])))),
            if (a.routeStops.isNotEmpty)
              _section(context, 'Planlagt rute', Card(child: Column(children: [
                for (final stop in a.routeStops.where((s) => s.type != 'meeting'))
                  ListTile(
                    leading: Icon(stop.type == 'start' ? Icons.trip_origin : stop.type == 'destination' ? Icons.flag_outlined : Icons.location_on_outlined),
                    title: Text(stop.name),
                    subtitle: stop.address.trim().isEmpty ? null : Text(stop.address),
                    trailing: Text(stop.type == 'start' ? 'Start' : stop.type == 'destination' ? 'Mål' : 'Stopp'),
                  ),
                if (a.routePlan.provider.isNotEmpty)
                  Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 14), child: Align(alignment: Alignment.centerLeft, child: Text('Rute: ${a.routePlan.provider}', style: Theme.of(context).textTheme.labelSmall))),
              ]))),
            _section(context, 'Om turen', Text(a.description)),
            if (a.groupId != null) _GroupLink(groupId: a.groupId!),
            if (isLeader && a.participants.any((p) => p.status == ParticipantStatus.requested))
              _section(context, 'Forespørsler', Card(child: Column(children: a.participants.where((p) => p.status == ParticipantStatus.requested).map((p) => ListTile(
                leading: CircleAvatar(child: Text(p.user.name.characters.first)), title: Text(p.user.name), subtitle: const Text('Ønsker å bli med'),
                trailing: FilledButton.tonal(onPressed: a.isFull ? null : () async { await ref.read(activityRepositoryProvider).approveParticipant(a.id, p.user.id); ref.invalidate(activityByIdProvider(a.id)); ref.invalidate(activitiesProvider); ref.invalidate(filteredActivitiesProvider); }, child: const Text('Godkjenn')),
              )).toList()))),
            _section(context, 'Deltakere', Card(child: Column(children: a.participants.where((p) => p.status != ParticipantStatus.requested).map((p) => ListTile(leading: CircleAvatar(child: Text(p.user.name.characters.first)), title: Text(p.user.name), subtitle: Text('${_roleLabel(p.role)} · ${p.status.name}'))).toList()))),
            _section(context, 'Møtepunkt', Card(child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.place_outlined),
                  title: Text(a.meetingPoint.isEmpty ? 'Ikke satt' : a.meetingPoint),
                  subtitle: Text(a.meetingAddress?.trim().isNotEmpty == true ? a.meetingAddress! : 'Oppmøte før avreise'),
                ),
                if (a.meetingLatitude != null && a.meetingLongitude != null) ...[
                  const SizedBox(height: 8),
                  MeetingPointMap(latitude: a.meetingLatitude!, longitude: a.meetingLongitude!),
                ],
              ]),
            ))),
            if (isParticipant) _section(context, 'Aktivitetschat', Card(child: ListTile(leading: const Icon(Icons.chat_bubble_outline), title: const Text('Åpne chat'), onTap: () => context.push('/activity/${a.id}/chat'), trailing: const Icon(Icons.chevron_right)))),
            const SizedBox(height: 80),
          ]),
        );
      },
    );
  }

  Widget _primaryButton(BuildContext context, WidgetRef ref, Activity a, bool isLeader, bool isParticipant) {
    if (a.status == ActivityStatus.finished) return const FilledButton.tonal(onPressed: null, child: Text('Aktiviteten er avsluttet'));
    if (isLeader && a.status == ActivityStatus.gathering) return FilledButton.icon(onPressed: () async { await ref.read(activityRepositoryProvider).setStatus(a.id, ActivityStatus.active); ref.invalidate(activityByIdProvider(a.id)); ref.invalidate(activitiesProvider); ref.invalidate(filteredActivitiesProvider); }, icon: const Icon(Icons.play_arrow), label: const Text('Start aktivitet'));
    if (isLeader && a.isLive) return FilledButton.icon(onPressed: () => context.push('/activity/${a.id}/live'), icon: const Icon(Icons.navigation), label: const Text('Åpne liveaktivitet'));
    if (isParticipant && a.isLive) return FilledButton.icon(onPressed: () => context.push('/activity/${a.id}/live'), icon: const Icon(Icons.navigation), label: const Text('Åpne liveaktivitet'));
    if (isParticipant) return const FilledButton.tonal(onPressed: null, child: Text('Du deltar'));
    if (a.isFull) return const FilledButton(onPressed: null, child: Text('Full'));
    if (a.requestPending) return const FilledButton(onPressed: null, child: Text('Venter på godkjenning'));
    if (a.participationMode == ParticipationMode.private) return const FilledButton.tonal(onPressed: null, child: Text('Kun invitasjon'));
    if (a.participationMode == ParticipationMode.groupOnly) return const FilledButton.tonal(onPressed: null, child: Text('Kun gruppe'));
    return FilledButton(onPressed: () => _join(context, ref, a), child: Text(a.participationMode == ParticipationMode.open ? 'Bli med' : 'Be om å bli med'));
  }

  Future<void> _handleLeaderAction(BuildContext context, WidgetRef ref, Activity a, String action) async {
    if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Slett aktivitet?'),
          content: const Text('Aktiviteten slettes permanent. Dette kan ikke angres.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Avbryt')),
            FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Slett aktivitet')),
          ],
        ),
      );
      if (confirmed != true) return;
      try {
        await ref.read(activityRepositoryProvider).deleteActivity(a.id);
        ref.invalidate(activitiesProvider);
        ref.invalidate(filteredActivitiesProvider);
        if (!context.mounted) return;
        context.go('/activities');
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aktiviteten er slettet.')));
      } catch (error) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Kunne ikke slette aktiviteten: $error')));
      }
      return;
    }

    final status = switch (action) {
      'gathering' => ActivityStatus.gathering,
      'active' => ActivityStatus.active,
      'paused' => ActivityStatus.paused,
      'finished' => ActivityStatus.finished,
      _ => null,
    };
    if (status == null) return;
    try {
      await ref.read(activityRepositoryProvider).setStatus(a.id, status);
      ref.invalidate(activityByIdProvider(a.id));
      ref.invalidate(activitiesProvider);
      ref.invalidate(filteredActivitiesProvider);
      if (status == ActivityStatus.finished && ref.read(localDemoModeProvider)) {
        final saveRoute = ref.read(mockSettingsStoreProvider).routeHistory;
        ref.read(mockHistoryStoreProvider.notifier).addFromFinishedActivity(a.copyWith(status: ActivityStatus.finished), routeSaved: saveRoute);
      }
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Kunne ikke oppdatere aktiviteten: $error')));
    }
  }

  Widget _section(BuildContext context, String title, Widget child) => Padding(padding: const EdgeInsets.fromLTRB(16, 6, 16, 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)), const SizedBox(height: 8), child]));
  String _roleLabel(ParticipantRole role) => switch (role) { ParticipantRole.leader => 'Turleder', ParticipantRole.sweep => 'Baktropp', ParticipantRole.participant => 'Deltaker' };
}


class _GroupLink extends ConsumerWidget {
  final String groupId;
  const _GroupLink({required this.groupId});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final group = ref.watch(groupByIdProvider(groupId)).valueOrNull;
    if (group == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Arrangert av', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: CircleAvatar(child: Text(group.kind.emoji)),
            title: Text(group.name),
            subtitle: Text('${group.region} · ${group.memberCount} medlemmer'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/group/${group.id}'),
          ),
        ),
      ]),
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> { E? get firstOrNull => isEmpty ? null : first; }

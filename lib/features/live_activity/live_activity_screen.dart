import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/design_system/app_widgets.dart';
import '../../core/map/activity_map.dart';
import '../../core/map/live_activity_map.dart';
import '../../core/dev/dev_scenario.dart';
import '../../core/dev/dev_scenario_provider.dart';
import '../../data/mock/providers.dart';
import '../../domain/models/activity_models.dart';
import '../auth/auth_controller.dart';
import 'live_tracking_controller.dart';

class LiveActivityScreen extends ConsumerWidget {
  final String activityId;
  const LiveActivityScreen({super.key, required this.activityId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(activityByIdProvider(activityId));
    final settings = ref.watch(mockSettingsStoreProvider);
    final scenario = ref.watch(devScenarioProvider);
    final demoMode = ref.watch(localDemoModeProvider);
    final livePositionsAsync = ref.watch(liveParticipantsProvider(activityId));
    final publicStateAsync = ref.watch(activityPublicStateProvider(activityId));
    final trackingState = ref.watch(liveTrackingControllerProvider(activityId));
    return async.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Kunne ikke laste liveaktivitet: $e'))),
      data: (a) {
        if (a == null) return const Scaffold(body: Center(child: Text('Liveaktiviteten er ikke tilgjengelig.')));
        if (!a.isLive) {
          if (!demoMode && trackingState.tracking) {
            Future.microtask(() => ref.read(liveTrackingControllerProvider(activityId).notifier).stop(notifyServer: false));
          }
          return Scaffold(
            appBar: AppBar(leading: AppBackButton(fallbackLocation: '/activity/${a.id}'), title: Text(a.title)),
            body: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(a.status == ActivityStatus.finished ? 'Aktiviteten er avsluttet.' : 'Aktiviteten er ikke startet ennå.'),
                const SizedBox(height: 12),
                FilledButton(onPressed: () => context.go('/activity/${a.id}'), child: const Text('Til aktivitet')),
              ]),
            ),
          );
        }
        final trackingEnabled = settings.participantLocation || settings.leaderLocation || settings.publicApproximateLocation;
        if (!demoMode && trackingEnabled && !trackingState.tracking && !trackingState.starting && !trackingState.permissionDenied && !trackingState.serviceDisabled) {
          Future.microtask(() => ref.read(liveTrackingControllerProvider(activityId).notifier).start());
        } else if (!demoMode && !trackingEnabled && trackingState.tracking) {
          Future.microtask(() => ref.read(liveTrackingControllerProvider(activityId).notifier).stop());
        } else if (!demoMode && trackingState.tracking) {
          Future.microtask(() => ref.read(liveTrackingControllerProvider(activityId).notifier).syncPrivacy());
        }
        final livePositions = livePositionsAsync.valueOrNull ?? const <LiveParticipantPosition>[];
        final publicState = publicStateAsync.valueOrNull;
        final currentUserId = ref.watch(currentActivityUserIdProvider);
        final me = a.participants.where((p) => p.user.id == currentUserId).firstOrNull;
        final isLeader = me?.role == ParticipantRole.leader;
        final nextStop = a.nextStopName ?? a.meetingPoint;
        final nextEta = a.nextStopEtaMinutes;
        return Scaffold(
          appBar: AppBar(
            leading: AppBackButton(fallbackLocation: '/activity/${a.id}'),
            title: Text(a.title),
            actions: [IconButton(onPressed: () => context.push('/activity/$activityId/chat'), icon: const Icon(Icons.chat_bubble_outline))],
          ),
          body: SafeArea(
            top: false,
            child: Stack(children: [
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: demoMode
                      ? ActivityMap(activities: [a], selectedActivityId: a.id)
                      : LiveActivityMap(
                          positions: livePositions,
                          publicState: publicState,
                          currentUserId: currentUserId,
                          participantNames: {for (final participant in a.participants) participant.user.id: participant.user.name},
                        ),
                ),
              ),
              Positioned(
                top: 22,
                left: 24,
                right: 24,
                child: Column(children: [
                  Row(children: [StatusBadge(a.status.label), const Spacer(), FilledButton.tonalIcon(onPressed: () => _participants(context, a, livePositions), icon: const Icon(Icons.my_location), label: const Text('Vis gruppen'))]),
                  if (!trackingEnabled || (!demoMode && !trackingState.tracking))
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Material(
                        color: Theme.of(context).colorScheme.tertiaryContainer,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Row(children: [
                            Icon(trackingEnabled ? Icons.gps_off : Icons.location_off_outlined),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_trackingMessage(demoMode, trackingEnabled, trackingState))),
                            if (!demoMode && (trackingState.permissionDenied || trackingState.serviceDisabled))
                              TextButton(
                                onPressed: () => trackingState.permissionDenied
                                    ? ref.read(liveTrackingControllerProvider(activityId).notifier).openAppSettings()
                                    : ref.read(liveTrackingControllerProvider(activityId).notifier).openLocationSettings(),
                                child: const Text('Åpne'),
                              ),
                          ]),
                        ),
                      ),
                    ),
                  if (scenario == DevScenario.offline)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Material(
                        color: Theme.of(context).colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                        child: const Padding(padding: EdgeInsets.all(10), child: Text('Begrenset tilkobling · liveoppdateringer kan være forsinket.')),
                      ),
                    ),
                ]),
              ),
              DraggableScrollableSheet(
                initialChildSize: .34,
                minChildSize: .24,
                maxChildSize: .64,
                snap: true,
                builder: (sheetContext, scrollController) => Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 18),
                      children: [
                        Center(
                          child: Container(
                            width: 42,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(color: Theme.of(context).colorScheme.outlineVariant, borderRadius: BorderRadius.circular(99)),
                          ),
                        ),
                        Row(children: [
                          Expanded(child: Text('Neste stopp: $nextStop', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800))),
                          if (nextEta != null) Text('ca. $nextEta min'),
                        ]),
                        const SizedBox(height: 8),
                        Text('${a.confirmedParticipants} deltakere · møtepunkt ${a.meetingPoint}', style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 64,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: a.participants.where((p) => p.status == ParticipantStatus.active || p.status == ParticipantStatus.approved).map((p) => Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: Column(children: [CircleAvatar(child: Text(p.user.name.characters.first)), Text(_participantLabel(p), style: const TextStyle(fontSize: 11))]),
                            )).toList(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(child: OutlinedButton.icon(onPressed: () => _participants(context, a, livePositions), icon: const Icon(Icons.people_outline), label: const Text('Deltakere'))),
                          const SizedBox(width: 8),
                          Expanded(child: FilledButton.tonalIcon(onPressed: trackingEnabled ? () => _catchUp(context, a, demoMode) : null, icon: const Icon(Icons.route), label: const Text('Ta meg igjen'))),
                        ]),
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(child: OutlinedButton.icon(onPressed: () => context.push('/activity/$activityId/chat'), icon: const Icon(Icons.chat_outlined), label: const Text('Chat'))),
                          if (isLeader) ...[
                            const SizedBox(width: 8),
                            Expanded(child: FilledButton.icon(onPressed: () => _leaderControls(context, ref, a), icon: const Icon(Icons.tune), label: const Text('Administrer'))),
                          ],
                        ]),
                        if (!isLeader) ...[
                          const SizedBox(height: 10),
                          Text('Administrasjon er kun tilgjengelig for turleder.', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ]),
          ),
        );
      },
    );
  }

  String _participantLabel(ActivityParticipant p) => p.role == ParticipantRole.leader ? 'Leder' : p.role == ParticipantRole.sweep ? 'Baktropp' : p.user.name;

  void _participants(BuildContext context, Activity a, List<LiveParticipantPosition> livePositions) => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: ListView(shrinkWrap: true, padding: const EdgeInsets.only(bottom: 20), children: [
            Padding(padding: const EdgeInsets.all(16), child: Text('Deltakere', style: Theme.of(context).textTheme.titleLarge)),
            ...a.participants.map((p) => ListTile(
                  leading: CircleAvatar(child: Text(p.user.name.characters.first)),
                  title: Text(p.user.name),
                  subtitle: Text(_liveParticipantSubtitle(p, livePositions)),
                  trailing: _liveParticipantTrailing(p, livePositions),
                )),
          ]),
        ),
      );

  String _trackingMessage(bool demoMode, bool locationEnabled, LiveTrackingState trackingState) {
    if (demoMode) return locationEnabled ? 'Demo-posisjon er aktiv.' : 'Din liveposisjon er satt på pause.';
    if (!locationEnabled) return 'Din liveposisjon er satt på pause.';
    if (trackingState.starting) return 'Starter GPS og live-sporing …';
    if (trackingState.permissionDenied || trackingState.serviceDisabled) return trackingState.error ?? 'GPS er ikke tilgjengelig.';
    if (trackingState.error != null) return trackingState.error!;
    return trackingState.tracking ? 'Liveposisjon deles med deltakerne.' : 'Live-sporing er ikke startet.';
  }

  LiveParticipantPosition? _positionFor(ActivityParticipant participant, List<LiveParticipantPosition> positions) {
    for (final position in positions) {
      if (position.userId == participant.user.id) return position;
    }
    return null;
  }

  String _liveParticipantSubtitle(ActivityParticipant participant, List<LiveParticipantPosition> positions) {
    final position = _positionFor(participant, positions);
    if (position == null) return 'Ingen liveoppdatering';
    return 'Sist oppdatert ${_age(position.recordedAt)}${position.isStale ? ' · posisjonen kan være gammel' : ''}';
  }

  Widget? _liveParticipantTrailing(ActivityParticipant participant, List<LiveParticipantPosition> positions) {
    final position = _positionFor(participant, positions);
    if (position == null) return null;
    final accuracy = position.accuracyMeters.round();
    return Text('±$accuracy m');
  }

  String _age(DateTime time) {
    final d = DateTime.now().difference(time);
    if (d.inMinutes < 1) return 'nå';
    if (d.inMinutes < 60) return '${d.inMinutes} min siden';
    return '${d.inHours} t siden';
  }

  void _catchUp(BuildContext context, Activity a, bool demoMode) {
    final target = a.nextStopName ?? a.meetingPoint;
    if (!demoMode) {
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Ta meg igjen', style: Theme.of(sheetContext).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text('Gruppens liveposisjon er tilgjengelig. Rutevalg og reell ETA kobles på sammen med routingmotoren; appen viser derfor ikke en beregnet demotid.'),
              const SizedBox(height: 12),
              Text('Neste registrerte punkt: $target'),
            ]),
          ),
        ),
      );
      return;
    }
    final groupEta = a.nextStopEtaMinutes ?? 30;
    final myEta = groupEta > 4 ? groupEta - 4 : groupEta;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Møt gruppen her', style: Theme.of(sheetContext).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(target),
          Text('Du: ca. $myEta min · Gruppen: ca. $groupEta min'),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () { Navigator.pop(sheetContext); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Navigasjon til $target åpnes når kart/routing kobles på.'))); }, icon: const Icon(Icons.navigation), label: const Text('Naviger'))),
          ]),
        ),
      ),
    );
  }

  void _leaderControls(BuildContext context, WidgetRef ref, Activity a) => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (a.status == ActivityStatus.active)
                ListTile(
                  leading: const Icon(Icons.pause_circle_outline),
                  title: const Text('Pause aktivitet'),
                  onTap: () async {
                    await ref.read(activityRepositoryProvider).setStatus(a.id, ActivityStatus.paused);
                    ref.invalidate(activityByIdProvider(a.id)); ref.invalidate(activitiesProvider); ref.invalidate(filteredActivitiesProvider);
                    if (sheetContext.mounted) Navigator.pop(sheetContext);
                  },
                ),
              if (a.status == ActivityStatus.paused)
                ListTile(
                  leading: const Icon(Icons.play_circle_outline),
                  title: const Text('Fortsett aktivitet'),
                  onTap: () async {
                    await ref.read(activityRepositoryProvider).setStatus(a.id, ActivityStatus.active);
                    ref.invalidate(activityByIdProvider(a.id)); ref.invalidate(activitiesProvider); ref.invalidate(filteredActivitiesProvider);
                    if (sheetContext.mounted) Navigator.pop(sheetContext);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.place_outlined),
                title: const Text('Endre møtepunkt'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _changeMeetingPoint(context, ref, a);
                },
              ),
              ListTile(
                leading: const Icon(Icons.record_voice_over_outlined),
                title: const Text('Send viktig melding'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.push('/activity/${a.id}/chat');
                },
              ),
              ListTile(
                leading: Icon(Icons.stop_circle_outlined, color: Theme.of(context).colorScheme.error),
                title: const Text('Avslutt aktivitet'),
                onTap: () async {
                  await ref.read(activityRepositoryProvider).setStatus(a.id, ActivityStatus.finished);
                  await ref.read(liveTrackingControllerProvider(a.id).notifier).stop(notifyServer: false);
                  ref.invalidate(activityByIdProvider(a.id)); ref.invalidate(activitiesProvider); ref.invalidate(filteredActivitiesProvider);
                  if (ref.read(localDemoModeProvider)) {
                    final saveRoute = ref.read(mockSettingsStoreProvider).routeHistory;
                    ref.read(mockHistoryStoreProvider.notifier).addFromFinishedActivity(a.copyWith(status: ActivityStatus.finished), routeSaved: saveRoute);
                  }
                  if (sheetContext.mounted) { Navigator.pop(sheetContext); context.go('/activity/${a.id}'); }
                },
              ),
            ]),
          ),
        ),
      );

  Future<void> _changeMeetingPoint(BuildContext context, WidgetRef ref, Activity a) async {
    final controller = TextEditingController(text: a.meetingPoint);
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Endre møtepunkt'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: 'Møtepunkt')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Avbryt')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: const Text('Lagre')),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.isEmpty) return;
    await ref.read(activityRepositoryProvider).updateMeetingPoint(a.id, value);
    ref.invalidate(activityByIdProvider(a.id)); ref.invalidate(activitiesProvider); ref.invalidate(filteredActivitiesProvider);
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design_system/app_widgets.dart';
import '../../core/geocoding/place_search_field.dart';
import '../../core/geocoding/place_search_service.dart';
import '../../core/map/planned_route_map.dart';
import '../../core/routing/route_planning_service.dart';
import '../../data/mock/providers.dart';
import '../../domain/models/activity_models.dart';

class CreateActivityScreen extends ConsumerStatefulWidget {
  final String? initialGroupId;
  const CreateActivityScreen({super.key, this.initialGroupId});

  @override
  ConsumerState<CreateActivityScreen> createState() => _CreateActivityScreenState();
}

class _CreateActivityScreenState extends ConsumerState<CreateActivityScreen> {
  int step = 0;
  ActivityKind kind = ActivityKind.motorcycle;
  bool startNow = true;
  ParticipationMode mode = ParticipationMode.request;
  String? groupId;
  final title = TextEditingController();
  final description = TextEditingController();
  PlaceSearchResult? meetingPoint;
  PlaceSearchResult? routeStart;
  PlaceSearchResult? routeDestination;
  final List<PlaceSearchResult?> routeWaypoints = [];
  final RoutePlanningService _routing = RoutePlanningService();
  PlannedRoute? plannedRoute;
  bool routeLoading = false;
  String? routeError;
  int _routeGeneration = 0;
  bool publishing = false;

  bool get _hasValidRoute =>
      routeStart != null &&
      routeDestination != null &&
      !routeWaypoints.any((p) => p == null) &&
      !routeLoading &&
      plannedRoute != null &&
      plannedRoute!.points.length >= 2;

  @override
  void initState() {
    super.initState();
    groupId = widget.initialGroupId;
  }

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    super.dispose();
  }

  Future<void> _recalculateRoute() async {
    final start = routeStart;
    final destination = routeDestination;
    final waypoints = routeWaypoints.whereType<PlaceSearchResult>().toList();
    final generation = ++_routeGeneration;
    if (start == null || destination == null) {
      if (mounted) setState(() { plannedRoute = null; routeError = null; routeLoading = false; });
      return;
    }
    setState(() { routeLoading = true; routeError = null; plannedRoute = null; });
    try {
      final route = await _routing.plan(kind: kind, start: start, destination: destination, waypoints: waypoints);
      if (!mounted || generation != _routeGeneration) return;
      setState(() { plannedRoute = route; routeLoading = false; });
    } catch (error) {
      if (!mounted || generation != _routeGeneration) return;
      setState(() { routeLoading = false; routeError = error.toString(); plannedRoute = null; });
    }
  }

  List<ActivityRouteStop> _routeStopsForSave() {
    final result = <ActivityRouteStop>[];
    if (routeStart != null) {
      result.add(ActivityRouteStop(name: routeStart!.name, address: routeStart!.address, type: 'start', sortOrder: 10, latitude: routeStart!.latitude, longitude: routeStart!.longitude));
    }
    var order = 20;
    for (final waypoint in routeWaypoints.whereType<PlaceSearchResult>()) {
      result.add(ActivityRouteStop(name: waypoint.name, address: waypoint.address, type: 'waypoint', sortOrder: order, latitude: waypoint.latitude, longitude: waypoint.longitude));
      order += 10;
    }
    if (routeDestination != null) {
      result.add(ActivityRouteStop(name: routeDestination!.name, address: routeDestination!.address, type: 'destination', sortOrder: 100, latitude: routeDestination!.latitude, longitude: routeDestination!.longitude));
    }
    if (meetingPoint != null) {
      result.add(ActivityRouteStop(name: meetingPoint!.name, address: meetingPoint!.address, type: 'meeting', sortOrder: 0, latitude: meetingPoint!.latitude, longitude: meetingPoint!.longitude));
    }
    return result;
  }

  Future<void> _publish() async {
    if (publishing) return;
    if (!_hasValidRoute) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ruten må være ferdig beregnet før aktiviteten kan publiseres.')));
      return;
    }
    setState(() => publishing = true);
    try {
      final created = await ref.read(activityRepositoryProvider).create(
        title: title.text,
        kind: kind,
        startNow: startNow,
        participationMode: mode,
        meetingPoint: meetingPoint?.name,
        meetingAddress: meetingPoint?.address,
        meetingLatitude: meetingPoint?.latitude,
        meetingLongitude: meetingPoint?.longitude,
        routeStartName: routeStart!.name,
        routeStartAddress: routeStart!.address,
        routeStartLatitude: routeStart!.latitude,
        routeStartLongitude: routeStart!.longitude,
        routeDestinationName: routeDestination!.name,
        routeDestinationAddress: routeDestination!.address,
        routeDestinationLatitude: routeDestination!.latitude,
        routeDestinationLongitude: routeDestination!.longitude,
        routePlan: ActivityRoutePlan(
          points: plannedRoute!.points,
          distanceKm: plannedRoute!.distanceKm,
          durationMinutes: plannedRoute!.durationMinutes,
          profile: plannedRoute!.profile,
          provider: plannedRoute!.provider,
        ),
        routeStops: _routeStopsForSave(),
        description: description.text,
        groupId: groupId,
      );
      ref.invalidate(activitiesProvider);
      ref.invalidate(filteredActivitiesProvider);
      if (!mounted) return;
      context.go('/activity/${created.id}');
    } catch (error) {
      if (!mounted) return;
      setState(() => publishing = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Kunne ikke opprette aktiviteten: $error')));
    }
  }

  void _next() {
    if (step == 2 && !_hasValidRoute) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Velg start og mål, og vent til ruten er beregnet.')));
      return;
    }
    setState(() => step++);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [_kindStep(), _timingStep(), _detailsStep(), _participationStep(), _reviewStep()];
    return Scaffold(
      appBar: AppBar(leading: const AppBackButton(fallbackLocation: '/map'), title: const Text('Start aktivitet')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            LinearProgressIndicator(value: (step + 1) / pages.length),
            const SizedBox(height: 18),
            Expanded(child: SingleChildScrollView(child: pages[step])),
            const SizedBox(height: 14),
            Row(children: [
              if (step > 0)
                Expanded(child: OutlinedButton(onPressed: publishing ? null : () => setState(() => step--), child: const Text('Tilbake'))),
              if (step > 0) const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: publishing || (step == pages.length - 1 && !_hasValidRoute) ? null : () => step == pages.length - 1 ? _publish() : _next(),
                  child: Text(publishing ? 'Lagrer…' : step == pages.length - 1 ? (startNow ? 'Start samling' : 'Publiser aktivitet') : 'Fortsett'),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _kindStep() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Hva skal du gjøre?', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: ActivityKind.values.map((k) => ChoiceChip(label: Text('${k.emoji} ${k.label}'), selected: k == kind, onSelected: (_) { setState(() => kind = k); _recalculateRoute(); })).toList(),
        ),
      ]);

  Widget _timingStep() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Når skal aktiviteten skje?', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        RadioGroup<bool>(
          groupValue: startNow,
          onChanged: (v) { if (v != null) setState(() => startNow = v); },
          child: const Column(children: [
            RadioListTile<bool>(value: true, title: Text('Start nå'), subtitle: Text('Aktiviteten går til Samling')),
            RadioListTile<bool>(value: false, title: Text('Planlegg'), subtitle: Text('Aktiviteten planlegges til i morgen')),
          ]),
        ),
      ]);

  Widget _detailsStep() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Tur og detaljer', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        TextField(controller: title, decoration: const InputDecoration(labelText: 'Tittel')),
        const SizedBox(height: 12),
        TextField(controller: description, maxLines: 3, decoration: const InputDecoration(labelText: 'Kort beskrivelse')),
        const SizedBox(height: 18),
        Text('Rute', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        PlaceSearchField(
          key: const ValueKey('route-start'),
          label: 'Startpunkt',
          hint: 'Søk etter sted, adresse, butikk eller stasjon',
          requiredSelection: true,
          onChanged: (value) { setState(() => routeStart = value); _recalculateRoute(); },
        ),
        const SizedBox(height: 16),
        PlaceSearchField(
          key: const ValueKey('route-destination'),
          label: 'Destinasjon',
          hint: 'Hvor skal turen ende?',
          requiredSelection: true,
          onChanged: (value) { setState(() => routeDestination = value); _recalculateRoute(); },
        ),
        const SizedBox(height: 12),
        for (var index = 0; index < routeWaypoints.length; index++) ...[
          Row(children: [
            Expanded(
              child: PlaceSearchField(
                key: ValueKey('route-waypoint-$index-${routeWaypoints.length}'),
                label: 'Mellomstopp ${index + 1}',
                hint: 'Søk etter mellomstopp',
                requiredSelection: true,
                onChanged: (value) { setState(() => routeWaypoints[index] = value); _recalculateRoute(); },
              ),
            ),
            IconButton(
              tooltip: 'Fjern mellomstopp',
              onPressed: () { setState(() => routeWaypoints.removeAt(index)); _recalculateRoute(); },
              icon: const Icon(Icons.remove_circle_outline),
            ),
          ]),
          const SizedBox(height: 10),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: routeWaypoints.length >= 6 ? null : () => setState(() => routeWaypoints.add(null)),
            icon: const Icon(Icons.add_location_alt_outlined),
            label: const Text('Legg til mellomstopp'),
          ),
        ),
        if (routeLoading) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(),
          const SizedBox(height: 6),
          const Text('Beregner rute langs veinett/sti …'),
        ],
        if (routeError != null) ...[
          const SizedBox(height: 8),
          Text(routeError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          TextButton.icon(onPressed: _recalculateRoute, icon: const Icon(Icons.refresh), label: const Text('Prøv ruteberegning igjen')),
        ],
        if (plannedRoute != null) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 250,
            child: PlannedRouteMap(
              route: ActivityRoutePlan(
                points: plannedRoute!.points,
                distanceKm: plannedRoute!.distanceKm,
                durationMinutes: plannedRoute!.durationMinutes,
                profile: plannedRoute!.profile,
                provider: plannedRoute!.provider,
              ),
              stops: _routeStopsForSave().where((s) => s.type != 'meeting').toList(),
              compact: true,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 12, runSpacing: 6, children: [
            Text('${plannedRoute!.distanceKm.toStringAsFixed(1)} km'),
            Text('ca. ${plannedRoute!.durationMinutes} min'),
            Text(plannedRoute!.provider),
          ]),
        ],
        const SizedBox(height: 18),
        Text('Oppmøte', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text('Valgfritt. Bruk dette hvis gruppen møtes et annet sted enn selve startpunktet.', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 10),
        PlaceSearchField(
          key: const ValueKey('meeting-point'),
          label: 'Oppmøte før avreise',
          hint: 'Søk etter oppmøtested',
          onChanged: (value) => setState(() => meetingPoint = value),
        ),
        const SizedBox(height: 8),
        Text('Stedsøk: Photon / OpenStreetMap', style: Theme.of(context).textTheme.labelSmall),
      ]);

  Widget _participationStep() {
    final groups = (ref.watch(myGroupsProvider).valueOrNull ?? const <Group>[])
        .where((g) => g.myRole == GroupRole.owner || g.myRole == GroupRole.admin || g.membersCanCreateActivities)
        .toList();
    final validGroupId = groups.any((g) => g.id == groupId) ? groupId : null;
    if (groupId != null && validGroupId == null) groupId = null;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Hvem kan bli med?', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      RadioGroup<ParticipationMode>(
        groupValue: mode,
        onChanged: (v) { if (v != null) setState(() => mode = v); },
        child: Column(children: ParticipationMode.values.map((m) => RadioListTile<ParticipationMode>(
          value: m,
          enabled: m != ParticipationMode.groupOnly || validGroupId != null,
          title: Text(switch (m) { ParticipationMode.open => 'Åpen', ParticipationMode.request => 'Forespørsel', ParticipationMode.groupOnly => 'Kun gruppe', ParticipationMode.private => 'Privat' }),
          subtitle: m == ParticipationMode.groupOnly && validGroupId == null ? const Text('Velg en gruppe først.') : null,
        )).toList()),
      ),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(
        initialValue: validGroupId ?? '',
        decoration: const InputDecoration(labelText: 'Opprett for gruppe', prefixIcon: Icon(Icons.groups_outlined)),
        items: [const DropdownMenuItem<String>(value: '', child: Text('Ingen gruppe')), ...groups.map((g) => DropdownMenuItem<String>(value: g.id, child: Text(g.name)))],
        onChanged: (value) => setState(() {
          groupId = value == null || value.isEmpty ? null : value;
          if (groupId == null && mode == ParticipationMode.groupOnly) mode = ParticipationMode.request;
        }),
      ),
      const SizedBox(height: 8),
      const SwitchListTile(value: true, onChanged: null, contentPadding: EdgeInsets.zero, title: Text('Vis aktiviteten offentlig'), subtitle: Text('Offentlig aktivitet følger gjeldende personvernregler.')),
    ]);
  }

  Widget _reviewStep() {
    final groups = ref.watch(myGroupsProvider).valueOrNull ?? const <Group>[];
    final groupName = groupId == null ? null : groups.where((g) => g.id == groupId).map((g) => g.name).firstOrNull;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Se over aktiviteten', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 16),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${kind.emoji} ${title.text}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(startNow ? 'Starter nå · Samling' : 'Planlagt aktivitet'),
            Text('Rute: ${routeStart?.name ?? 'Ikke satt'} → ${routeDestination?.name ?? 'Ikke satt'}'),
            if (!_hasValidRoute) Text('Ruten er ikke ferdig beregnet og kan ikke publiseres.', style: TextStyle(color: Theme.of(context).colorScheme.error)),
            if (routeWaypoints.whereType<PlaceSearchResult>().isNotEmpty) Text('Mellomstopp: ${routeWaypoints.whereType<PlaceSearchResult>().map((p) => p.name).join(' · ')}'),
            if (plannedRoute != null) Text('${plannedRoute!.distanceKm.toStringAsFixed(1)} km · ca. ${plannedRoute!.durationMinutes} min'),
            if (meetingPoint != null) Text('Oppmøte: ${meetingPoint!.name}'),
            Text('Deltakelse: ${_modeLabel(mode)}'),
            if (groupName != null) Text('Gruppe: $groupName'),
            const Text('Aktiviteten lagres i Supabase'),
          ]),
        ),
      ),
    ]);
  }

  String _modeLabel(ParticipationMode value) => switch (value) {
        ParticipationMode.open => 'Åpen',
        ParticipationMode.request => 'Forespørsel',
        ParticipationMode.groupOnly => 'Kun gruppe',
        ParticipationMode.private => 'Privat',
      };
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design_system/app_widgets.dart';
import '../../core/geocoding/place_search_field.dart';
import '../../core/geocoding/place_search_service.dart';
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
  bool publishing = false;

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

  Future<void> _publish() async {
    if (publishing) return;
    if (routeStart == null || routeDestination == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Velg både startpunkt og destinasjon fra stedsforslagene.')));
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
    if (step == 2 && (routeStart == null || routeDestination == null)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Velg startpunkt og destinasjon før du fortsetter.')));
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
                  onPressed: publishing ? null : () => step == pages.length - 1 ? _publish() : _next(),
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
          children: ActivityKind.values.map((k) => ChoiceChip(label: Text('${k.emoji} ${k.label}'), selected: k == kind, onSelected: (_) => setState(() => kind = k))).toList(),
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
          onChanged: (value) => setState(() => routeStart = value),
        ),
        const SizedBox(height: 16),
        PlaceSearchField(
          key: const ValueKey('route-destination'),
          label: 'Destinasjon',
          hint: 'Hvor skal turen ende?',
          requiredSelection: true,
          onChanged: (value) => setState(() => routeDestination = value),
        ),
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

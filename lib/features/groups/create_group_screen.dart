import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/app_theme.dart';
import '../../core/design_system/app_widgets.dart';
import '../../data/providers.dart';
import '../../domain/models/activity_models.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});
  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final name = TextEditingController();
  final region = TextEditingController(text: 'Rogaland');
  final description = TextEditingController();
  ActivityKind kind = ActivityKind.motorcycle;
  GroupVisibility visibility = GroupVisibility.public;
  GroupJoinMode joinMode = GroupJoinMode.request;
  bool saving = false;

  @override
  void dispose() {
    name.dispose();
    region.dispose();
    description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(leading: const AppBackButton(fallbackLocation: '/groups'), title: const Text('Opprett gruppe')),
        body: SafeArea(
          top: false,
          minimum: const EdgeInsets.only(bottom: 16),
          child: ListView(
            padding: const EdgeInsets.all(AppTokens.page),
            children: [
            Text('Ny gruppe', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text('Lag et fast samlingspunkt for aktiviteter, medlemmer og chat.', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 22),
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Navn', hintText: 'Rogaland MC')),
            const SizedBox(height: 12),
            TextField(controller: region, decoration: const InputDecoration(labelText: 'Område', hintText: 'Rogaland')),
            const SizedBox(height: 12),
            TextField(controller: description, maxLines: 3, decoration: const InputDecoration(labelText: 'Kort beskrivelse')),
            const SizedBox(height: 20),
            Text('Aktivitetstype', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ActivityKind.values.map((item) => ChoiceChip(
                avatar: Text(item.emoji),
                label: Text(item.label),
                selected: kind == item,
                onSelected: (_) => setState(() => kind = item),
              )).toList(),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<GroupVisibility>(
              initialValue: visibility,
              decoration: const InputDecoration(labelText: 'Synlighet'),
              items: GroupVisibility.values.map((item) => DropdownMenuItem(value: item, child: Text(item.label))).toList(),
              onChanged: (value) => setState(() => visibility = value ?? visibility),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<GroupJoinMode>(
              initialValue: joinMode,
              decoration: const InputDecoration(labelText: 'Medlemskap'),
              items: GroupJoinMode.values.map((item) => DropdownMenuItem(value: item, child: Text(item.label))).toList(),
              onChanged: (value) => setState(() => joinMode = value ?? joinMode),
            ),
            const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: saving ? null : _create,
                icon: const Icon(Icons.groups_rounded),
                label: Text(saving ? 'Oppretter…' : 'Opprett gruppe'),
              ),
            ],
          ),
        ),
      );

  Future<void> _create() async {
    if (name.text.trim().length < 2 || name.text.trim().length > 120 || region.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Navn må være 2–120 tegn, og område må fylles ut.')));
      return;
    }
    setState(() => saving = true);
    try {
      final group = await ref.read(groupRepositoryProvider).create(
            name: name.text.trim(),
            kind: kind,
            region: region.text.trim(),
            description: description.text.trim(),
            visibility: visibility,
            joinMode: joinMode,
          );
      ref.invalidate(myGroupsProvider);
      ref.invalidate(discoverGroupsProvider);
      if (!mounted) return;
      context.go('/group/${group.id}');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyCreateError(error))),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  String _friendlyCreateError(Object error) {
    final text = error.toString();
    if (text.contains('auth_required')) return 'Du må være innlogget for å opprette en gruppe.';
    if (text.contains('profile_required')) return 'Profilen din må være opprettet før du kan lage en gruppe.';
    if (text.contains('invalid_group_name')) return 'Gruppenavnet må være mellom 2 og 120 tegn.';
    if (text.contains('invalid_activity_type')) return 'Ugyldig aktivitetstype.';
    if (text.contains('invalid_visibility')) return 'Ugyldig synlighetsvalg.';
    if (text.contains('invalid_join_mode')) return 'Ugyldig medlemskapsvalg.';
    return 'Kunne ikke opprette gruppen. Prøv igjen.\n$text';
  }
}

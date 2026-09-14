import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/design_system/app_widgets.dart';
import '../../domain/models/profile_models.dart';
import '../../data/providers.dart';
import '../../data/supabase/providers.dart';
import '../../domain/models/activity_models.dart';
import '../../core/errors_user_facing.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncProfile = ref.watch(supabaseProfileControllerProvider);
    return asyncProfile.when(
      loading: () => const Scaffold(
        appBar: _ProfileAppBar(),
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: const _ProfileAppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.cloud_off_outlined, size: 46),
              const SizedBox(height: 12),
              const Text('Kunne ikke laste profilen.'),
              const SizedBox(height: 8),
              Text(userFacingError(error, fallback: 'Kunne ikke hente profilen. Prøv igjen.'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => ref.read(supabaseProfileControllerProvider.notifier).refresh(),
                icon: const Icon(Icons.refresh),
                label: const Text('Prøv igjen'),
              ),
            ]),
          ),
        ),
      ),
      data: (profile) => _ProfileScaffold(profile: profile),
    );
  }
}

class _ProfileAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _ProfileAppBar();
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
  @override
  Widget build(BuildContext context) => AppBar(
        title: const Text('Profil'),
        actions: [IconButton(onPressed: () => context.push('/settings'), icon: const Icon(Icons.settings_outlined))],
      );
}

class _ProfileScaffold extends ConsumerWidget {
  final ProfileState profile;
  const _ProfileScaffold({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(activityHistoryProvider).valueOrNull ?? const <ActivityHistoryEntry>[];
    final groups = ref.watch(myGroupsProvider).valueOrNull?.length ?? 0;
    final mcKm = history.where((h) => h.kind == ActivityKind.motorcycle).fold<double>(0, (sum, h) => sum + h.distanceKm);

    return Scaffold(
      appBar: const _ProfileAppBar(),
      body: SafeArea(
        top: false,
        child: ListView(children: [
          AppSection(child: Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                _ProfileAvatar(profile: profile, radius: 42),
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: Material(
                    color: Theme.of(context).colorScheme.primary,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => _pickAvatar(context, ref),
                      child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.camera_alt_outlined, size: 18, color: Colors.white)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(profile.name.isEmpty ? 'Ny bruker' : profile.name, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
            if (profile.region.isNotEmpty) Text(profile.region),
            if (profile.bio.isNotEmpty) ...[const SizedBox(height: 8), Text(profile.bio, textAlign: TextAlign.center)],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              alignment: WrapAlignment.center,
              children: [
                OutlinedButton.icon(onPressed: () => _editProfile(context, ref), icon: const Icon(Icons.edit_outlined), label: const Text('Rediger profil')),
                if (profile.avatarBytes != null || profile.avatarUrl != null)
                  OutlinedButton.icon(onPressed: () => _removeAvatar(context, ref), icon: const Icon(Icons.person_off_outlined), label: const Text('Fjern bilde')),
              ],
            ),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.cloud_done_outlined, size: 16, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 6),
              Text('Lagret i WayCrew', style: Theme.of(context).textTheme.labelMedium),
            ]),
          ])))),
          AppSection(title: 'Aktivitet', child: Row(children: [
            Expanded(child: _Stat(value: '${history.length}', label: 'historikk')),
            const SizedBox(width: 8),
            Expanded(child: _Stat(value: mcKm.toStringAsFixed(0), label: 'km MC')),
            const SizedBox(width: 8),
            Expanded(child: _Stat(value: '$groups', label: 'grupper')),
          ])),
          AppSection(
            title: 'Interesser',
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ActivityKind.values.map((kind) => FilterChip(
                    selected: profile.interests.contains(kind),
                    label: Text('${kind.emoji} ${kind.label}'),
                    onSelected: (_) => _toggleInterest(context, ref, kind),
                  )).toList(),
                ),
              ),
            ),
          ),
          AppSection(
            title: 'Aktivitetsprofiler',
            trailing: TextButton.icon(onPressed: () => _editActivityProfile(context, ref, null), icon: const Icon(Icons.add), label: const Text('Legg til')),
            child: Card(
              child: profile.activityProfiles.isEmpty
                  ? const Padding(padding: EdgeInsets.all(18), child: Text('Ingen aktivitetsprofiler ennå.'))
                  : Column(children: profile.activityProfiles.map((p) => ListTile(
                      leading: Text(p.kind.emoji, style: const TextStyle(fontSize: 24)),
                      title: Text(p.kind.label),
                      subtitle: Text('${p.experience}${p.summary.isEmpty ? '' : ' · ${p.summary}'}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _editActivityProfile(context, ref, p),
                    )).toList()),
            ),
          ),
          AppSection(title: 'Mine aktiviteter', child: Card(child: Column(children: [
            ListTile(leading: const Icon(Icons.history), title: const Text('Kommende, aktive og historikk'), trailing: const Icon(Icons.chevron_right), onTap: () => context.push('/history')),
            ListTile(leading: const Icon(Icons.groups_outlined), title: const Text('Mine grupper'), trailing: const Icon(Icons.chevron_right), onTap: () => context.go('/groups')),
          ]))),
          const SizedBox(height: 80),
        ]),
      ),
    );
  }

  Future<void> _pickAvatar(BuildContext context, WidgetRef ref) async {
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1024, imageQuality: 85);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final extension = file.name.contains('.') ? file.name.split('.').last : 'jpg';
      final ok = await ref.read(supabaseProfileControllerProvider.notifier).uploadAvatar(bytes, extension: extension);
      if (!ok && context.mounted) _showError(context, 'Kunne ikke laste opp profilbildet.');
    } catch (_) {
      if (context.mounted) _showError(context, 'Kunne ikke velge profilbilde.');
    }
  }

  Future<void> _removeAvatar(BuildContext context, WidgetRef ref) async {
    final ok = await ref.read(supabaseProfileControllerProvider.notifier).removeAvatar();
    if (!ok && context.mounted) _showError(context, 'Kunne ikke fjerne profilbildet.');
  }

  void _editProfile(BuildContext context, WidgetRef ref) {
    final name = TextEditingController(text: profile.name);
    final region = TextEditingController(text: profile.region);
    final bio = TextEditingController(text: profile.bio);
    showModalBottomSheet<void>(context: context, isScrollControlled: true, showDragHandle: true, builder: (ctx) => SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.viewInsetsOf(ctx).bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Rediger profil', style: Theme.of(ctx).textTheme.titleLarge), const SizedBox(height: 16),
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Navn')), const SizedBox(height: 10),
          TextField(controller: region, decoration: const InputDecoration(labelText: 'Område')), const SizedBox(height: 10),
          TextField(controller: bio, maxLines: 3, decoration: const InputDecoration(labelText: 'Kort bio')), const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: FilledButton(
            onPressed: () async {
              if (name.text.trim().length < 2) return;
              final ok = await ref.read(supabaseProfileControllerProvider.notifier).updateBasic(name: name.text, region: region.text, bio: bio.text);
              if (ctx.mounted && ok) Navigator.pop(ctx);
              if (context.mounted && !ok) _showError(context, 'Kunne ikke lagre profilen.');
            },
            child: const Text('Lagre profil'),
          )),
        ]),
      ),
    ));
  }

  Future<void> _toggleInterest(BuildContext context, WidgetRef ref, ActivityKind kind) async {
    final ok = await ref.read(supabaseProfileControllerProvider.notifier).toggleInterest(kind);
    if (!ok && context.mounted) _showError(context, 'Kunne ikke oppdatere interessen.');
  }

  void _editActivityProfile(BuildContext context, WidgetRef ref, ActivityProfileData? existing) {
    var kind = existing?.kind ?? ActivityKind.motorcycle;
    final experience = TextEditingController(text: existing?.experience ?? 'Middels');
    final summary = TextEditingController(text: existing?.summary ?? '');
    showModalBottomSheet<void>(context: context, isScrollControlled: true, showDragHandle: true, builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) => SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.viewInsetsOf(ctx).bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(existing == null ? 'Ny aktivitetsprofil' : 'Rediger aktivitetsprofil', style: Theme.of(ctx).textTheme.titleLarge), const SizedBox(height: 16),
          DropdownButtonFormField<ActivityKind>(
            initialValue: kind,
            items: ActivityKind.values.map((k) => DropdownMenuItem(value: k, child: Text('${k.emoji} ${k.label}'))).toList(),
            onChanged: existing == null ? (v) => setLocal(() => kind = v ?? kind) : null,
            decoration: const InputDecoration(labelText: 'Aktivitet'),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _normalizedExperience(experience.text),
            items: const [
              DropdownMenuItem(value: 'Nybegynner', child: Text('Nybegynner')),
              DropdownMenuItem(value: 'Litt erfaring', child: Text('Litt erfaring')),
              DropdownMenuItem(value: 'Erfaren', child: Text('Erfaren')),
              DropdownMenuItem(value: 'Svært erfaren', child: Text('Svært erfaren')),
            ],
            onChanged: (value) => experience.text = value ?? experience.text,
            decoration: const InputDecoration(labelText: 'Erfaring'),
          ),
          const SizedBox(height: 10),
          TextField(controller: summary, maxLines: 2, decoration: const InputDecoration(labelText: 'Kort beskrivelse')),
          const SizedBox(height: 16),
          Row(children: [
            if (existing != null)
              Expanded(child: OutlinedButton(onPressed: () async {
                final ok = await ref.read(supabaseProfileControllerProvider.notifier).removeActivityProfile(kind);
                if (ctx.mounted && ok) Navigator.pop(ctx);
              }, child: const Text('Fjern'))),
            if (existing != null) const SizedBox(width: 8),
            Expanded(child: FilledButton(onPressed: () async {
              final ok = await ref.read(supabaseProfileControllerProvider.notifier).upsertActivityProfile(kind, experience: experience.text, summary: summary.text);
              if (ctx.mounted && ok) Navigator.pop(ctx);
              if (context.mounted && !ok) _showError(context, 'Kunne ikke lagre aktivitetsprofilen.');
            }, child: const Text('Lagre'))),
          ]),
        ]),
      ),
    )));
  }

  String _normalizedExperience(String value) {
    final lower = value.toLowerCase();
    if (lower.contains('svært')) return 'Svært erfaren';
    if (lower.contains('erfaren')) return 'Erfaren';
    if (lower.contains('litt') || lower.contains('middels')) return 'Litt erfaring';
    return 'Nybegynner';
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ProfileAvatar extends StatelessWidget {
  final ProfileState profile;
  final double radius;
  const _ProfileAvatar({required this.profile, required this.radius});

  @override
  Widget build(BuildContext context) {
    if (profile.avatarBytes != null) {
      return CircleAvatar(radius: radius, backgroundImage: MemoryImage(profile.avatarBytes!));
    }
    if (profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(profile.avatarUrl!),
        onBackgroundImageError: (_, __) {},
      );
    }
    return CircleAvatar(radius: radius, child: Text(profile.name.isEmpty ? '?' : profile.name.characters.first, style: TextStyle(fontSize: radius * .68)));
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  const _Stat({required this.value, required this.label});
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(children: [
            Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            Text(label, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
          ]),
        ),
      );
}

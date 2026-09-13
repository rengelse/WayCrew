import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/design_system/app_widgets.dart';
import '../../data/mock/mock_settings_store.dart';
import '../../data/mock/providers.dart';
import '../../core/supabase/supabase_providers.dart';
import '../auth/auth_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(mockSettingsStoreProvider);
    final store = ref.read(mockSettingsStoreProvider.notifier);
    return Scaffold(
      appBar: AppBar(leading: const AppBackButton(fallbackLocation: '/profile'), title: const Text('Innstillinger')),
      body: ListView(children: [
        _AccountSection(),
        AppSection(title: 'Personvern', child: Card(child: Column(children: [
          _VisibilityTile(title: 'Profil og synlighet', value: s.profileVisibility, onChanged: store.setProfileVisibility),
          _VisibilityTile(title: 'Aktivitetshistorikk', value: s.historyVisibility, onChanged: store.setHistoryVisibility),
        ]))),
        AppSection(title: 'Posisjon og tracking', child: Card(child: Column(children: [
          const ListTile(leading: Icon(Icons.shield_outlined), title: Text('Ingen aktivitet = ingen offentlig liveposisjon'), subtitle: Text('Offentlig kart viser bare omtrentlig gruppeposisjon.')),
          SwitchListTile(value: s.participantLocation, onChanged: store.setParticipantLocation, title: const Text('Del liveposisjon med deltakere')),
          SwitchListTile(value: s.leaderLocation, onChanged: store.setLeaderLocation, title: const Text('Del nøyaktig posisjon med turleder')),
          SwitchListTile(value: s.publicApproximateLocation, onChanged: store.setPublicApproximateLocation, title: const Text('Vis omtrentlig gruppeposisjon offentlig')),
        ]))),
        AppSection(title: 'Varsler', child: Card(child: Column(children: [
          SwitchListTile(value: s.nearbyNotifications, onChanged: store.setNearbyNotifications, title: const Text('Aktiviteter i nærheten'), subtitle: Text('Radius: ${s.nearbyRadiusKm} km')),
          if (s.nearbyNotifications) Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Slider(value: s.nearbyRadiusKm.toDouble(), min: 10, max: 100, divisions: 9, label: '${s.nearbyRadiusKm} km', onChanged: (v) => store.setNearbyRadius(v.round()))),
          SwitchListTile(value: s.chatNotifications, onChanged: store.setChatNotifications, title: const Text('Chatvarsler')),
          SwitchListTile(value: s.importantNotifications, onChanged: store.setImportantNotifications, title: const Text('Viktige livevarsler')),
        ]))),
        AppSection(title: 'Data og lagring', child: Card(child: Column(children: [
          SwitchListTile(value: s.routeHistory, onChanged: store.setRouteHistory, title: const Text('Lagre rutehistorikk'), subtitle: const Text('Separat fra midlertidig live tracking')),
          const ListTile(title: Text('Last ned mine data'), subtitle: Text('Kommer med backend-integrasjonen'), trailing: Icon(Icons.download_outlined)),
        ]))),
        AppSection(title: 'Kart og visning', child: Card(child: ListTile(title: const Text('Tema'), trailing: DropdownButton<ThemePreference>(value: s.themePreference, underline: const SizedBox.shrink(), items: const [DropdownMenuItem(value: ThemePreference.system, child: Text('System')), DropdownMenuItem(value: ThemePreference.light, child: Text('Lys')), DropdownMenuItem(value: ThemePreference.dark, child: Text('Mørk'))], onChanged: (v) { if (v != null) store.setThemePreference(v); })))),
        const AppSection(title: 'Sikkerhet', child: Card(child: Column(children: [ListTile(title: Text('Blokkerte brukere'), trailing: Icon(Icons.chevron_right)), ListTile(title: Text('Rapportering og hjelp'), trailing: Icon(Icons.chevron_right))]))),
        const AppSection(title: 'Om', child: Card(child: ListTile(leading: CircleAvatar(backgroundImage: AssetImage('assets/branding/waycrew_icon.png')), title: Text('WayCrew'), subtitle: Text('v0.2.14 · Deletion & Branding Fix')))),
        const SizedBox(height: 24),
      ]),
    );
  }
}

class _VisibilityTile extends StatelessWidget {
  final String title; final VisibilityLevel value; final ValueChanged<VisibilityLevel> onChanged;
  const _VisibilityTile({required this.title, required this.value, required this.onChanged});
  @override Widget build(BuildContext context) => ListTile(
    title: Text(title),
    subtitle: Text(_label(value)),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => showModalBottomSheet<void>(context: context, showDragHandle: true, builder: (ctx) => SafeArea(child: RadioGroup<VisibilityLevel>(groupValue: value, onChanged: (next) { if (next != null) onChanged(next); Navigator.pop(ctx); }, child: Column(mainAxisSize: MainAxisSize.min, children: VisibilityLevel.values.map((v) => RadioListTile<VisibilityLevel>(value: v, title: Text(_label(v)))).toList())))),
  );
  static String _label(VisibilityLevel v) => switch (v) { VisibilityLevel.everyone => 'Alle', VisibilityLevel.participants => 'Grupper / deltakere', VisibilityLevel.onlyMe => 'Kun meg' };
}

class _AccountSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentSupabaseUserProvider);
    final demo = ref.watch(localDemoModeProvider);
    return AppSection(
      title: 'Konto',
      child: Card(
        child: Column(
          children: [
            ListTile(
              leading: Icon(demo ? Icons.science_outlined : Icons.verified_user_outlined),
              title: Text(demo ? 'Lokal demo' : (user?.email ?? 'Supabase-konto')),
              subtitle: Text(demo ? 'Mockdata · ingen backendkonto aktiv' : 'Koblet til activity-network-dev'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout),
              title: Text(demo ? 'Avslutt demo' : 'Logg ut'),
              onTap: () async {
                if (demo) {
                  ref.read(localDemoModeProvider.notifier).state = false;
                } else {
                  await ref.read(authRepositoryProvider).signOut();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

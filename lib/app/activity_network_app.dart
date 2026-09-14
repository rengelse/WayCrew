import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/supabase/supabase_providers.dart';
import '../core/update/app_update_gate.dart';
import '../data/mock/mock_settings_store.dart';
import '../data/mock/providers.dart';
import '../features/auth/auth_controller.dart';
import '../features/auth/auth_screen.dart';
import '../features/live_activity/live_tracking_gate.dart';
import 'app_router.dart';
import 'app_theme.dart';

class ActivityNetworkApp extends ConsumerWidget {
  const ActivityNetworkApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(mockSettingsStoreProvider);
    final themeMode = switch (settings.themePreference) {
      ThemePreference.system => ThemeMode.system,
      ThemePreference.light => ThemeMode.light,
      ThemePreference.dark => ThemeMode.dark,
    };
    final demoMode = ref.watch(localDemoModeProvider);
    final session = ref.watch(authSessionProvider);

    return session.when(
      loading: () => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'WayCrew',
        builder: (context, child) => AppUpdateGate(child: LiveTrackingGate(child: child ?? const SizedBox.shrink())),
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        home: const _BootstrapScreen(),
      ),
      error: (error, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'WayCrew',
        builder: (context, child) => AppUpdateGate(child: LiveTrackingGate(child: child ?? const SizedBox.shrink())),
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        home: _BootstrapErrorScreen(error: error),
      ),
      data: (activeSession) {
        if (activeSession == null && !demoMode) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'WayCrew',
            builder: (context, child) => AppUpdateGate(child: LiveTrackingGate(child: child ?? const SizedBox.shrink())),
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: themeMode,
            home: const AuthScreen(),
          );
        }
        final router = ref.watch(appRouterProvider);
        return MaterialApp.router(
          debugShowCheckedModeBanner: false,
          title: 'WayCrew',
          builder: (context, child) => AppUpdateGate(child: LiveTrackingGate(child: child ?? const SizedBox.shrink())),
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeMode,
          routerConfig: router,
        );
      },
    );
  }
}

class _BootstrapScreen extends StatelessWidget {
  const _BootstrapScreen();
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
}

class _BootstrapErrorScreen extends StatelessWidget {
  final Object error;
  const _BootstrapErrorScreen({required this.error});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_outlined, size: 48),
                  const SizedBox(height: 16),
                  Text('Kunne ikke starte Supabase', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text('$error', textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      );
}

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_update_service.dart';

class AppUpdateGate extends StatefulWidget {
  final Widget child;

  const AppUpdateGate({super.key, required this.child});

  @override
  State<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends State<AppUpdateGate> {
  static const _lastCheckKey = 'app_update_last_check_ms';
  static const _lastPromptVersionKey = 'app_update_last_prompt_version';
  static const _lastPromptAtKey = 'app_update_last_prompt_at_ms';
  static const _checkInterval = Duration(hours: 12);
  static const _repeatPromptInterval = Duration(hours: 24);

  final _service = const AppUpdateService();
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdate());
  }

  Future<void> _checkForUpdate() async {
    final preferences = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final lastCheckMs = preferences.getInt(_lastCheckKey);
    if (lastCheckMs != null) {
      final lastCheck = DateTime.fromMillisecondsSinceEpoch(lastCheckMs);
      if (now.difference(lastCheck) < _checkInterval) return;
    }

    await preferences.setInt(_lastCheckKey, now.millisecondsSinceEpoch);

    try {
      final result = await _service.check();
      final update = result.update;
      if (!mounted || update == null) return;

      final lastPromptVersion = preferences.getString(_lastPromptVersionKey);
      final lastPromptMs = preferences.getInt(_lastPromptAtKey);
      if (lastPromptVersion == update.latestVersion && lastPromptMs != null) {
        final lastPrompt = DateTime.fromMillisecondsSinceEpoch(lastPromptMs);
        if (now.difference(lastPrompt) < _repeatPromptInterval) return;
      }

      await preferences.setString(_lastPromptVersionKey, update.latestVersion);
      await preferences.setInt(_lastPromptAtKey, now.millisecondsSinceEpoch);

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.system_update_alt),
          title: const Text('Ny WayCrew-versjon tilgjengelig'),
          content: Text(
            'Du har v${update.currentVersion}. '
            'v${update.latestVersion} er tilgjengelig på GitHub.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Senere'),
            ),
            FilledButton.icon(
              onPressed: () async {
                Navigator.pop(dialogContext);
                final uri = Uri.parse(update.downloadUrl);
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              },
              icon: const Icon(Icons.download_outlined),
              label: const Text('Last ned'),
            ),
          ],
        ),
      );
    } catch (_) {
      // Startup update checks are intentionally silent on network/API errors.
      // The user can retry manually from Settings > Om.
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

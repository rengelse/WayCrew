import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:ota_update/ota_update.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_update_service.dart';
import '../errors_user_facing.dart';

Future<void> showAppUpdateDownload(
  BuildContext context,
  AppUpdateInfo update,
) async {
  if (!Platform.isAndroid) {
    final uri = Uri.parse(update.downloadUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
    return;
  }

  if (update.apkUrl == null || update.apkUrl!.isEmpty) {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('APK mangler i releasen'),
        content: const Text(
          'GitHub-releasen inneholder ingen APK-fil som WayCrew kan laste ned.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return;
  }

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _AppUpdateDownloadDialog(update: update),
  );
}

class _AppUpdateDownloadDialog extends StatefulWidget {
  final AppUpdateInfo update;

  const _AppUpdateDownloadDialog({required this.update});

  @override
  State<_AppUpdateDownloadDialog> createState() =>
      _AppUpdateDownloadDialogState();
}

class _AppUpdateDownloadDialogState extends State<_AppUpdateDownloadDialog> {
  final OtaUpdate _otaUpdate = OtaUpdate();
  StreamSubscription<OtaEvent>? _subscription;

  double? _progress;
  String _status = 'Forbereder nedlasting …';
  bool _canClose = false;
  bool _downloading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final apkUrl = widget.update.apkUrl!;
      final filename = 'WayCrew-v${widget.update.latestVersion}.apk';

      _subscription = _otaUpdate
          .execute(
            apkUrl,
            destinationFilename: filename,
          )
          .listen(
            _onEvent,
            onError: (Object error, StackTrace stackTrace) {
              _setError(userFacingError(error, fallback: 'Nedlastingen feilet. Prøv igjen.'));
            },
          );
    } catch (error) {
      _setError(userFacingError(error, fallback: 'Kunne ikke starte oppdateringen. Prøv igjen.'));
    }
  }

  void _onEvent(OtaEvent event) {
    if (!mounted) return;

    switch (event.status) {
      case OtaStatus.DOWNLOADING:
        final parsed = double.tryParse(event.value ?? '');
        setState(() {
          _downloading = true;
          _status = 'Laster ned WayCrew v${widget.update.latestVersion} …';
          _progress = parsed == null ? null : (parsed / 100).clamp(0.0, 1.0).toDouble();
          _error = null;
        });
        return;
      case OtaStatus.INSTALLING:
        setState(() {
          _downloading = false;
          _progress = 1;
          _status = 'Nedlasting ferdig. Åpner Android-installasjon …';
          _canClose = true;
        });
        return;
      case OtaStatus.INSTALLATION_DONE:
        setState(() {
          _downloading = false;
          _progress = 1;
          _status = 'Oppdateringen er installert.';
          _canClose = true;
        });
        return;
      case OtaStatus.CANCELED:
        setState(() {
          _downloading = false;
          _status = 'Nedlastingen ble avbrutt.';
          _canClose = true;
        });
        return;
      case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
        _setError(
          'Android har ikke gitt WayCrew tillatelse til å installere oppdateringen. '
          'Tillat installasjon fra denne appen og prøv igjen.',
        );
        return;
      case OtaStatus.DOWNLOAD_ERROR:
        _setError('Kunne ikke laste ned APK-en.${_detail(event.value)}');
        return;
      case OtaStatus.CHECKSUM_ERROR:
        _setError('APK-en kunne ikke verifiseres.${_detail(event.value)}');
        return;
      case OtaStatus.INSTALLATION_ERROR:
        _setError('Android kunne ikke installere oppdateringen.${_detail(event.value)}');
        return;
      case OtaStatus.ALREADY_RUNNING_ERROR:
        _setError('En oppdatering lastes allerede ned.');
        return;
      case OtaStatus.INTERNAL_ERROR:
        _setError('Oppdateringen feilet.${_detail(event.value)}');
        return;
    }
  }

  String _detail(String? value) {
    final detail = value?.trim();
    if (detail == null || detail.isEmpty) return '';
    return '\n\n$detail';
  }

  void _setError(String message) {
    if (!mounted) return;
    setState(() {
      _downloading = false;
      _error = message;
      _status = 'Oppdatering feilet';
      _canClose = true;
    });
  }

  Future<void> _cancel() async {
    await _otaUpdate.cancel();
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _canClose,
      child: AlertDialog(
        icon: Icon(_error == null ? Icons.system_update_alt : Icons.error_outline),
        title: Text(_error == null ? 'Oppdaterer WayCrew' : 'Kunne ikke oppdatere'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_error ?? _status),
            if (_error == null) ...[
              const SizedBox(height: 20),
              LinearProgressIndicator(value: _progress),
              if (_progress != null) ...[
                const SizedBox(height: 8),
                Text(
                  '${(_progress! * 100).round()} %',
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ],
        ),
        actions: [
          if (_downloading)
            TextButton(
              onPressed: _cancel,
              child: const Text('Avbryt'),
            )
          else if (_canClose)
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Lukk'),
            ),
        ],
      ),
    );
  }
}

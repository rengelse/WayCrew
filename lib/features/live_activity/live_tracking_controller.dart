import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../data/mock/providers.dart';
import '../../domain/models/activity_models.dart';
import '../../domain/repositories/repositories.dart';

class LiveTrackingState {
  final bool starting;
  final bool tracking;
  final bool permissionDenied;
  final bool serviceDisabled;
  final String? error;
  final DateTime? lastPublishedAt;

  const LiveTrackingState({
    this.starting = false,
    this.tracking = false,
    this.permissionDenied = false,
    this.serviceDisabled = false,
    this.error,
    this.lastPublishedAt,
  });

  LiveTrackingState copyWith({
    bool? starting,
    bool? tracking,
    bool? permissionDenied,
    bool? serviceDisabled,
    String? error,
    bool clearError = false,
    DateTime? lastPublishedAt,
  }) => LiveTrackingState(
        starting: starting ?? this.starting,
        tracking: tracking ?? this.tracking,
        permissionDenied: permissionDenied ?? this.permissionDenied,
        serviceDisabled: serviceDisabled ?? this.serviceDisabled,
        error: clearError ? null : (error ?? this.error),
        lastPublishedAt: lastPublishedAt ?? this.lastPublishedAt,
      );
}

class LiveTrackingController extends StateNotifier<LiveTrackingState> {
  final String activityId;
  final LiveTrackingRepository? repository;
  final bool Function() shareWithParticipants;
  final bool Function() shareWithLeader;
  final bool Function() publicApproximate;
  final bool Function() saveRouteHistory;
  StreamSubscription<Position>? _subscription;
  bool _publishing = false;
  String? _lastPrivacyKey;
  bool? _lastRouteHistory;

  LiveTrackingController({required this.activityId, required this.repository, required this.shareWithParticipants, required this.shareWithLeader, required this.publicApproximate, required this.saveRouteHistory}) : super(const LiveTrackingState());

  Future<void> start() async {
    if (repository == null || state.tracking || state.starting) return;
    state = state.copyWith(starting: true, clearError: true, permissionDenied: false, serviceDisabled: false);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        state = state.copyWith(starting: false, tracking: false, serviceDisabled: true, error: 'Posisjonstjenester er slått av på telefonen.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        state = state.copyWith(starting: false, tracking: false, permissionDenied: true, error: permission == LocationPermission.deniedForever
            ? 'Posisjonstilgang er blokkert. Åpne appinnstillingene for å tillate posisjon.'
            : 'Posisjonstilgang er nødvendig for live-sporing.');
        return;
      }

      await repository!.ensureSession(activityId);
      await syncRouteHistory();
      await syncPrivacy();

      final current = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      await _publish(current);

      await _subscription?.cancel();
      final LocationSettings streamSettings = defaultTargetPlatform == TargetPlatform.android
          ? AndroidSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 10,
              intervalDuration: const Duration(seconds: 10),
              foregroundNotificationConfig: const ForegroundNotificationConfig(
                notificationTitle: 'Live aktivitet pågår',
                notificationText: 'Posisjonen din deles mens aktiviteten er aktiv.',
                notificationChannelName: 'Live aktivitet',
                enableWakeLock: true,
                setOngoing: true,
              ),
            )
          : const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 10,
            );

      _subscription = Geolocator.getPositionStream(
        locationSettings: streamSettings,
      ).listen(
        (position) => _publish(position),
        onError: (Object error) {
          state = state.copyWith(error: 'GPS-oppdatering feilet: $error');
        },
      );

      state = state.copyWith(starting: false, tracking: true, clearError: true);
    } catch (error) {
      state = state.copyWith(starting: false, tracking: false, error: 'Kunne ikke starte live-sporing: $error');
    }
  }

  Future<void> _publish(Position position) async {
    if (_publishing || repository == null) return;
    _publishing = true;
    try {
      await syncRouteHistory();
      final recordedAt = position.timestamp;
      final sequence = recordedAt.microsecondsSinceEpoch;
      await repository!.publishPosition(
        activityId,
        LivePositionSample(
          latitude: position.latitude,
          longitude: position.longitude,
          accuracyMeters: position.accuracy,
          headingDegrees: position.heading.isFinite ? position.heading : null,
          speedMetersPerSecond: position.speed.isFinite && position.speed >= 0 ? position.speed : null,
          recordedAt: recordedAt,
          sequence: sequence,
        ),
        shareWithParticipants: shareWithParticipants(),
        shareWithLeader: shareWithLeader(),
        publicApproximate: publicApproximate(),
      );
      state = state.copyWith(lastPublishedAt: DateTime.now(), clearError: true);
    } catch (error) {
      final text = error.toString();
      if (text.contains('activity_not_live') ||
          text.contains('participant_required') ||
          text.contains('authentication_required')) {
        await stop(notifyServer: false);
        state = state.copyWith(
          tracking: false,
          error: text.contains('participant_required')
              ? 'Live-sporing er stoppet fordi du ikke lenger deltar på aktiviteten.'
              : 'Live-sporing er stoppet fordi aktiviteten ikke lenger er aktiv.',
        );
      } else {
        state = state.copyWith(error: 'Kunne ikke sende liveposisjon: $error');
      }
    } finally {
      _publishing = false;
    }
  }


  Future<void> syncRouteHistory() async {
    if (repository == null) return;
    final enabled = saveRouteHistory();
    if (_lastRouteHistory == enabled) return;
    await repository!.setRouteHistoryEnabled(activityId, enabled);
    _lastRouteHistory = enabled;
  }

  Future<void> syncPrivacy() async {
    if (repository == null) return;
    final participants = shareWithParticipants();
    final leader = shareWithLeader();
    final public = publicApproximate();
    final key = '$participants|$leader|$public';
    if (_lastPrivacyKey == key) return;
    try {
      await repository!.setPrivacy(
        activityId,
        shareWithParticipants: participants,
        shareWithLeader: leader,
        publicApproximate: public,
      );
      _lastPrivacyKey = key;
    } catch (_) {
      // No live row may exist yet; the next published position carries the same flags.
    }
  }

  Future<void> stop({bool notifyServer = true}) async {
    await _subscription?.cancel();
    _subscription = null;
    if (notifyServer && repository != null) {
      try {
        await repository!.stopSharing(activityId);
      } catch (_) {
        // Activity status changes may already have ended the live session server-side.
      }
    }
    state = state.copyWith(starting: false, tracking: false);
  }

  Future<void> openLocationSettings() => Geolocator.openLocationSettings();
  Future<void> openAppSettings() => Geolocator.openAppSettings();

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final liveTrackingControllerProvider = StateNotifierProvider.family<LiveTrackingController, LiveTrackingState, String>((ref, activityId) {
  return LiveTrackingController(
    activityId: activityId,
    repository: ref.watch(liveTrackingRepositoryProvider),
    shareWithParticipants: () => ref.read(mockSettingsStoreProvider).participantLocation,
    shareWithLeader: () => ref.read(mockSettingsStoreProvider).leaderLocation,
    publicApproximate: () => ref.read(mockSettingsStoreProvider).publicApproximateLocation,
    saveRouteHistory: () => ref.read(mockSettingsStoreProvider).routeHistory,
  );
});

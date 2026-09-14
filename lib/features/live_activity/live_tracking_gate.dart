import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/models/activity_models.dart';
import 'live_tracking_controller.dart';

/// Keeps live tracking bound to the user's active activity rather than to a
/// particular screen. Once an approved participant is in an active/paused
/// activity, Android's foreground location service can keep publishing while
/// the UI is backgrounded.
class LiveTrackingGate extends ConsumerStatefulWidget {
  final Widget child;
  const LiveTrackingGate({super.key, required this.child});

  @override
  ConsumerState<LiveTrackingGate> createState() => _LiveTrackingGateState();
}

class _LiveTrackingGateState extends ConsumerState<LiveTrackingGate>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _checking = false;
  String? _trackedActivityId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _reconcile());
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _reconcile());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _reconcile();
    }
  }

  Future<void> _reconcile() async {
    if (_checking || !mounted) return;
    _checking = true;
    try {
      final currentUserId = ref.read(currentActivityUserIdProvider);
      if (currentUserId == null) {
        await _stopCurrent();
        return;
      }

      final settings = ref.read(settingsStoreProvider);
      final sharingEnabled = settings.participantLocation ||
          settings.leaderLocation ||
          settings.publicApproximateLocation;
      if (!sharingEnabled) {
        await _stopCurrent();
        return;
      }

      final activities = await ref.read(activityRepositoryProvider).discover();
      Activity? eligible;
      for (final activity in activities) {
        if (!activity.isLive) continue;
        final mine = activity.participants.where((participant) =>
            participant.user.id == currentUserId &&
            (participant.status == ParticipantStatus.approved ||
                participant.status == ParticipantStatus.active));
        if (mine.isNotEmpty) {
          eligible = activity;
          break;
        }
      }

      if (eligible == null) {
        await _stopCurrent();
        return;
      }

      if (_trackedActivityId != null && _trackedActivityId != eligible.id) {
        await ref
            .read(liveTrackingControllerProvider(_trackedActivityId!).notifier)
            .stop();
      }
      _trackedActivityId = eligible.id;
      final controller =
          ref.read(liveTrackingControllerProvider(eligible.id).notifier);
      final state = ref.read(liveTrackingControllerProvider(eligible.id));
      if (!state.tracking && !state.starting) {
        await controller.start();
      } else if (state.tracking) {
        await controller.syncPrivacy();
      }
    } catch (_) {
      // Server-side live eligibility remains the source of truth. A temporary
      // network failure must not crash the app or start tracking incorrectly.
    } finally {
      _checking = false;
    }
  }

  Future<void> _stopCurrent() async {
    final id = _trackedActivityId;
    _trackedActivityId = null;
    if (id == null) return;
    await ref.read(liveTrackingControllerProvider(id).notifier).stop();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

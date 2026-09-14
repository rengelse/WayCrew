import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase/supabase_providers.dart';
import '../../domain/models/profile_models.dart';
import '../../domain/models/activity_models.dart';
import 'supabase_profile_repository.dart';

final supabaseProfileRepositoryProvider = Provider<SupabaseProfileRepository>((ref) {
  return SupabaseProfileRepository(ref.watch(supabaseClientProvider));
});

class SupabaseProfileController extends StateNotifier<AsyncValue<ProfileState>> {
  final SupabaseProfileRepository _repository;

  SupabaseProfileController(this._repository) : super(const AsyncLoading()) {
    refresh();
  }

  Future<void> refresh({bool showLoading = true}) async {
    if (showLoading) state = const AsyncLoading();
    final next = await AsyncValue.guard(_repository.mine);
    state = next;
  }

  Future<bool> updateBasic({required String name, required String region, required String bio}) async {
    try {
      await _repository.updateMine(displayName: name, region: region, bio: bio);
      await refresh(showLoading: false);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> toggleInterest(ActivityKind kind) async {
    final current = state.valueOrNull;
    if (current == null) return false;
    final enabled = !current.interests.contains(kind);
    try {
      await _repository.toggleInterest(kind, enabled: enabled);
      await refresh(showLoading: false);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> upsertActivityProfile(ActivityKind kind, {required String experience, required String summary}) async {
    try {
      await _repository.upsertActivityProfile(kind, experience: experience, summary: summary);
      await refresh(showLoading: false);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> removeActivityProfile(ActivityKind kind) async {
    try {
      await _repository.removeActivityProfile(kind);
      await refresh(showLoading: false);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> uploadAvatar(List<int> bytes, {required String extension}) async {
    try {
      await _repository.uploadAvatar(Uint8List.fromList(bytes), extension: extension);
      await refresh(showLoading: false);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> removeAvatar() async {
    final current = state.valueOrNull;
    try {
      await _repository.removeAvatar(current?.avatarStoragePath);
      await refresh(showLoading: false);
      return true;
    } catch (_) {
      return false;
    }
  }
}

final supabaseProfileControllerProvider = StateNotifierProvider<SupabaseProfileController, AsyncValue<ProfileState>>((ref) {
  ref.watch(authSessionProvider);
  return SupabaseProfileController(ref.watch(supabaseProfileRepositoryProvider));
});

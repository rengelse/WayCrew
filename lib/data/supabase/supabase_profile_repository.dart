import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/mock/mock_profile_store.dart';
import '../../domain/models/activity_models.dart';

class SupabaseProfileRepository {
  final SupabaseClient _client;
  const SupabaseProfileRepository(this._client);

  User get _user {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('Not authenticated');
    return user;
  }

  Future<ProfileState> mine() async {
    final user = _user;
    var profile = await _client.from('profiles').select().eq('id', user.id).maybeSingle();
    if (profile == null) {
      final displayName = (user.userMetadata?['display_name'] as String?)?.trim();
      await _client.from('profiles').upsert({
        'id': user.id,
        'display_name': (displayName == null || displayName.isEmpty) ? (user.email?.split('@').first ?? 'Ny bruker') : displayName,
      });
      profile = await _client.from('profiles').select().eq('id', user.id).single();
    }

    final interestsRows = await _client.from('user_interests').select('activity_type').eq('user_id', user.id);
    final activityProfileRows = await _client.from('activity_profiles').select().eq('user_id', user.id).order('created_at');

    final avatarPath = profile['avatar_url'] as String?;
    String? avatarSignedUrl;
    if (avatarPath != null && avatarPath.isNotEmpty) {
      try {
        avatarSignedUrl = await _client.storage.from('avatars').createSignedUrl(avatarPath, 24 * 60 * 60);
      } catch (_) {
        avatarSignedUrl = null;
      }
    }

    return ProfileState(
      name: (profile['display_name'] as String?) ?? '',
      region: (profile['region'] as String?) ?? '',
      bio: (profile['bio'] as String?) ?? '',
      avatarUrl: avatarSignedUrl,
      avatarStoragePath: avatarPath,
      interests: interestsRows
          .map<ActivityKind?>((row) => activityKindFromStorage(row['activity_type'] as String?))
          .whereType<ActivityKind>()
          .toList(),
      activityProfiles: activityProfileRows.map<ActivityProfileData>((row) {
        final metadata = Map<String, dynamic>.from((row['metadata'] as Map?) ?? const {});
        final kind = activityKindFromStorage(row['activity_type'] as String?) ?? ActivityKind.other;
        return ActivityProfileData(
          kind: kind,
          experience: (metadata['experience_label'] as String?) ?? experienceLevelLabel(row['experience_level'] as String?),
          summary: (metadata['summary'] as String?) ?? '',
        );
      }).toList(),
    );
  }

  Future<void> updateMine({required String displayName, required String region, required String bio}) async {
    final user = _user;
    await _client.from('profiles').update({
      'display_name': displayName.trim(),
      'region': region.trim(),
      'bio': bio.trim(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', user.id);
  }

  Future<void> toggleInterest(ActivityKind kind, {required bool enabled}) async {
    final user = _user;
    if (enabled) {
      await _client.from('user_interests').insert({
        'user_id': user.id,
        'activity_type': kind.name,
      });
    } else {
      await _client.from('user_interests').delete().eq('user_id', user.id).eq('activity_type', kind.name);
    }
  }

  Future<void> upsertActivityProfile(ActivityKind kind, {required String experience, required String summary}) async {
    final user = _user;
    await _client.from('activity_profiles').upsert({
      'user_id': user.id,
      'activity_type': kind.name,
      'experience_level': experienceLevelStorage(experience),
      'metadata': {
        'experience_label': experience.trim(),
        'summary': summary.trim(),
      },
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id,activity_type');
  }

  Future<void> removeActivityProfile(ActivityKind kind) async {
    final user = _user;
    await _client.from('activity_profiles').delete().eq('user_id', user.id).eq('activity_type', kind.name);
  }

  Future<void> uploadAvatar(Uint8List bytes, {required String extension}) async {
    final user = _user;
    final safeExtension = switch (extension.toLowerCase()) {
      'png' => 'png',
      'webp' => 'webp',
      _ => 'jpg',
    };
    final contentType = switch (safeExtension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
    final path = '${user.id}/profile.$safeExtension';
    await _client.storage.from('avatars').uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(contentType: contentType, upsert: true),
    );
    await _client.from('profiles').update({
      'avatar_url': path,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', user.id);
  }

  Future<void> removeAvatar(String? storagePath) async {
    final user = _user;
    if (storagePath != null && storagePath.isNotEmpty) {
      await _client.storage.from('avatars').remove([storagePath]);
    }
    await _client.from('profiles').update({
      'avatar_url': null,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', user.id);
  }
}

ActivityKind? activityKindFromStorage(String? value) {
  if (value == null) return null;
  for (final kind in ActivityKind.values) {
    if (kind.name == value) return kind;
  }
  return null;
}

String experienceLevelStorage(String label) {
  final normalized = label.trim().toLowerCase();
  if (normalized.contains('svært') || normalized.contains('very')) return 'very_experienced';
  if (normalized.contains('erfaren') || normalized.contains('experienced')) return 'experienced';
  if (normalized.contains('litt') || normalized.contains('middels') || normalized.contains('some')) return 'some_experience';
  return 'beginner';
}

String experienceLevelLabel(String? value) => switch (value) {
      'very_experienced' => 'Svært erfaren',
      'experienced' => 'Erfaren',
      'some_experience' => 'Litt erfaring',
      _ => 'Nybegynner',
    };

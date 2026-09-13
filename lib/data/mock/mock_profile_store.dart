import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/activity_models.dart';
import 'mock_data.dart';

class ActivityProfileData {
  final ActivityKind kind;
  final String experience;
  final String summary;
  const ActivityProfileData({required this.kind, required this.experience, required this.summary});
  ActivityProfileData copyWith({String? experience, String? summary}) => ActivityProfileData(
    kind: kind,
    experience: experience ?? this.experience,
    summary: summary ?? this.summary,
  );
}

class ProfileState {
  final String name;
  final String region;
  final String bio;
  final Uint8List? avatarBytes;
  final String? avatarUrl;
  final String? avatarStoragePath;
  final List<ActivityKind> interests;
  final List<ActivityProfileData> activityProfiles;
  const ProfileState({required this.name, required this.region, required this.bio, this.avatarBytes, this.avatarUrl, this.avatarStoragePath, required this.interests, required this.activityProfiles});
  ProfileState copyWith({String? name, String? region, String? bio, Uint8List? avatarBytes, String? avatarUrl, String? avatarStoragePath, bool clearAvatar = false, List<ActivityKind>? interests, List<ActivityProfileData>? activityProfiles}) => ProfileState(
    name: name ?? this.name,
    region: region ?? this.region,
    bio: bio ?? this.bio,
    avatarBytes: clearAvatar ? null : (avatarBytes ?? this.avatarBytes),
    avatarUrl: clearAvatar ? null : (avatarUrl ?? this.avatarUrl),
    avatarStoragePath: clearAvatar ? null : (avatarStoragePath ?? this.avatarStoragePath),
    interests: interests ?? this.interests,
    activityProfiles: activityProfiles ?? this.activityProfiles,
  );
}

class MockProfileStore extends StateNotifier<ProfileState> {
  MockProfileStore() : super(ProfileState(
    name: currentUser.name,
    region: currentUser.region,
    bio: 'MC, ski og fjelltur',
    interests: List<ActivityKind>.from(currentUser.interests),
    activityProfiles: const [
      ActivityProfileData(kind: ActivityKind.motorcycle, experience: 'Erfaren', summary: 'Touring / Adventure · Asfalt + grus'),
      ActivityProfileData(kind: ActivityKind.ski, experience: 'Middels', summary: 'Randonee · Moderat nivå'),
    ],
  ));

  void updateBasic({required String name, required String region, required String bio}) {
    state = state.copyWith(name: name.trim(), region: region.trim(), bio: bio.trim());
  }

  void setAvatar(Uint8List bytes) => state = state.copyWith(avatarBytes: bytes);
  void removeAvatar() => state = state.copyWith(clearAvatar: true);

  void toggleInterest(ActivityKind kind) {
    final interests = List<ActivityKind>.from(state.interests);
    interests.contains(kind) ? interests.remove(kind) : interests.add(kind);
    state = state.copyWith(interests: interests);
  }

  void upsertActivityProfile(ActivityKind kind, {required String experience, required String summary}) {
    final items = List<ActivityProfileData>.from(state.activityProfiles);
    final index = items.indexWhere((p) => p.kind == kind);
    final next = ActivityProfileData(kind: kind, experience: experience.trim(), summary: summary.trim());
    if (index == -1) {
      items.add(next);
    } else {
      items[index] = next;
    }
    state = state.copyWith(activityProfiles: items);
  }

  void removeActivityProfile(ActivityKind kind) {
    state = state.copyWith(activityProfiles: state.activityProfiles.where((p) => p.kind != kind).toList());
  }
}

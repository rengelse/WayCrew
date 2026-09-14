import 'dart:typed_data';
import 'activity_models.dart';

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
class LiveParticipantProfileCard {
  final String userId;
  final String name;
  final String region;
  final String bio;
  final String? avatarUrl;

  const LiveParticipantProfileCard({
    required this.userId,
    required this.name,
    required this.region,
    required this.bio,
    this.avatarUrl,
  });
}


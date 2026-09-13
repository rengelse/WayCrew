enum ActivityKind { motorcycle, ski, cycling, hiking, running, kayak, climbing, other }
enum ActivityStatus { draft, planned, gathering, active, paused, finished, cancelled }
enum ParticipationMode { open, request, groupOnly, private }
enum ParticipantRole { leader, sweep, participant }
enum ParticipantStatus { invited, requested, approved, active, rejected, withdrawn, left, removed }
enum GroupRole { owner, admin, member }
enum GroupMembershipStatus { active, requested, invited, left, removed }
enum GroupVisibility { public, private }
enum GroupJoinMode { open, request, inviteOnly }
enum ActivityTimeFilter { now, today, weekend, later }
enum NotificationCategory { activities, groups, messages, important }
enum NotificationPriority { normal, important, critical }

extension ActivityKindX on ActivityKind {
  String get label => switch (this) {
    ActivityKind.motorcycle => 'MC',
    ActivityKind.ski => 'Ski',
    ActivityKind.cycling => 'Sykkel',
    ActivityKind.hiking => 'Fottur',
    ActivityKind.running => 'Løping',
    ActivityKind.kayak => 'Kajakk',
    ActivityKind.climbing => 'Klatring',
    ActivityKind.other => 'Annet',
  };
  String get emoji => switch (this) {
    ActivityKind.motorcycle => '🏍️',
    ActivityKind.ski => '⛷️',
    ActivityKind.cycling => '🚵',
    ActivityKind.hiking => '🥾',
    ActivityKind.running => '🏃',
    ActivityKind.kayak => '🛶',
    ActivityKind.climbing => '🧗',
    ActivityKind.other => '📍',
  };
}

extension ActivityStatusX on ActivityStatus {
  String get label => switch (this) {
    ActivityStatus.draft => 'Utkast',
    ActivityStatus.planned => 'Planlagt',
    ActivityStatus.gathering => 'Samling nå',
    ActivityStatus.active => 'Pågår',
    ActivityStatus.paused => 'Pause',
    ActivityStatus.finished => 'Ferdig',
    ActivityStatus.cancelled => 'Avlyst',
  };
}

extension ActivityTimeFilterX on ActivityTimeFilter {
  String get label => switch (this) {
    ActivityTimeFilter.now => 'Nå',
    ActivityTimeFilter.today => 'I dag',
    ActivityTimeFilter.weekend => 'Denne helgen',
    ActivityTimeFilter.later => 'Senere',
  };
}

extension GroupRoleX on GroupRole {
  String get label => switch (this) {
    GroupRole.owner => 'Eier',
    GroupRole.admin => 'Administrator',
    GroupRole.member => 'Medlem',
  };
}

extension GroupVisibilityX on GroupVisibility {
  String get label => switch (this) {
    GroupVisibility.public => 'Offentlig',
    GroupVisibility.private => 'Privat',
  };
}

extension GroupJoinModeX on GroupJoinMode {
  String get label => switch (this) {
    GroupJoinMode.open => 'Åpen',
    GroupJoinMode.request => 'Forespørsel',
    GroupJoinMode.inviteOnly => 'Kun invitasjon',
  };
}

class AppUser {
  final String id;
  final String name;
  final String region;
  final List<ActivityKind> interests;
  const AppUser({required this.id, required this.name, required this.region, required this.interests});
}

class ActivityParticipant {
  final AppUser user;
  final ParticipantRole role;
  final ParticipantStatus status;
  final double? distanceBehindKm;
  final DateTime? lastUpdated;
  const ActivityParticipant({required this.user, required this.role, required this.status, this.distanceBehindKm, this.lastUpdated});
  ActivityParticipant copyWith({ParticipantRole? role, ParticipantStatus? status, double? distanceBehindKm, DateTime? lastUpdated}) => ActivityParticipant(
    user: user,
    role: role ?? this.role,
    status: status ?? this.status,
    distanceBehindKm: distanceBehindKm ?? this.distanceBehindKm,
    lastUpdated: lastUpdated ?? this.lastUpdated,
  );
}

class Activity {
  final String id;
  final String title;
  final ActivityKind kind;
  final ActivityStatus status;
  final ParticipationMode participationMode;
  final String routeLabel;
  final String meetingPoint;
  final String? meetingAddress;
  final double? meetingLatitude;
  final double? meetingLongitude;
  final DateTime startsAt;
  final int maxParticipants;
  final double distanceKm;
  final String pace;
  final String surface;
  final String description;
  final String? groupId;
  final String? nextStopName;
  final int? nextStopEtaMinutes;
  final List<ActivityParticipant> participants;
  final bool mine;
  final bool requestPending;
  const Activity({
    required this.id,
    required this.title,
    required this.kind,
    required this.status,
    required this.participationMode,
    required this.routeLabel,
    required this.meetingPoint,
    this.meetingAddress,
    this.meetingLatitude,
    this.meetingLongitude,
    required this.startsAt,
    required this.maxParticipants,
    required this.distanceKm,
    required this.pace,
    required this.surface,
    required this.description,
    this.groupId,
    this.nextStopName,
    this.nextStopEtaMinutes,
    required this.participants,
    this.mine = false,
    this.requestPending = false,
  });

  int get confirmedParticipants => participants.where((p) => p.status == ParticipantStatus.active || p.status == ParticipantStatus.approved).length;
  bool get isFull => confirmedParticipants >= maxParticipants;
  bool get isLive => status == ActivityStatus.active || status == ActivityStatus.paused;

  Activity copyWith({
    String? title,
    ActivityKind? kind,
    ActivityStatus? status,
    ParticipationMode? participationMode,
    String? routeLabel,
    String? meetingPoint,
    String? meetingAddress,
    double? meetingLatitude,
    double? meetingLongitude,
    DateTime? startsAt,
    int? maxParticipants,
    double? distanceKm,
    String? pace,
    String? surface,
    String? description,
    String? groupId,
    bool clearGroup = false,
    String? nextStopName,
    int? nextStopEtaMinutes,
    List<ActivityParticipant>? participants,
    bool? mine,
    bool? requestPending,
  }) => Activity(
    id: id,
    title: title ?? this.title,
    kind: kind ?? this.kind,
    status: status ?? this.status,
    participationMode: participationMode ?? this.participationMode,
    routeLabel: routeLabel ?? this.routeLabel,
    meetingPoint: meetingPoint ?? this.meetingPoint,
    meetingAddress: meetingAddress ?? this.meetingAddress,
    meetingLatitude: meetingLatitude ?? this.meetingLatitude,
    meetingLongitude: meetingLongitude ?? this.meetingLongitude,
    startsAt: startsAt ?? this.startsAt,
    maxParticipants: maxParticipants ?? this.maxParticipants,
    distanceKm: distanceKm ?? this.distanceKm,
    pace: pace ?? this.pace,
    surface: surface ?? this.surface,
    description: description ?? this.description,
    groupId: clearGroup ? null : (groupId ?? this.groupId),
    nextStopName: nextStopName ?? this.nextStopName,
    nextStopEtaMinutes: nextStopEtaMinutes ?? this.nextStopEtaMinutes,
    participants: participants ?? this.participants,
    mine: mine ?? this.mine,
    requestPending: requestPending ?? this.requestPending,
  );
}

class Group {
  final String id;
  final String name;
  final ActivityKind kind;
  final String region;
  final int memberCount;
  final int upcomingCount;
  final bool member;
  final bool requestPending;
  final GroupRole? myRole;
  final String description;
  final GroupVisibility visibility;
  final GroupJoinMode joinMode;
  final bool membersCanCreateActivities;
  const Group({
    required this.id,
    required this.name,
    required this.kind,
    required this.region,
    required this.memberCount,
    required this.upcomingCount,
    this.member = false,
    this.requestPending = false,
    this.myRole,
    this.description = '',
    this.visibility = GroupVisibility.public,
    this.joinMode = GroupJoinMode.request,
    this.membersCanCreateActivities = false,
  });
  Group copyWith({
    String? name,
    ActivityKind? kind,
    String? region,
    int? memberCount,
    int? upcomingCount,
    bool? member,
    bool? requestPending,
    GroupRole? myRole,
    bool clearRole = false,
    String? description,
    GroupVisibility? visibility,
    GroupJoinMode? joinMode,
    bool? membersCanCreateActivities,
  }) => Group(
    id: id,
    name: name ?? this.name,
    kind: kind ?? this.kind,
    region: region ?? this.region,
    memberCount: memberCount ?? this.memberCount,
    upcomingCount: upcomingCount ?? this.upcomingCount,
    member: member ?? this.member,
    requestPending: requestPending ?? this.requestPending,
    myRole: clearRole ? null : (myRole ?? this.myRole),
    description: description ?? this.description,
    visibility: visibility ?? this.visibility,
    joinMode: joinMode ?? this.joinMode,
    membersCanCreateActivities: membersCanCreateActivities ?? this.membersCanCreateActivities,
  );
}

class GroupMember {
  final AppUser user;
  final GroupRole role;
  final GroupMembershipStatus status;
  const GroupMember({required this.user, required this.role, required this.status});
  GroupMember copyWith({GroupRole? role, GroupMembershipStatus? status}) => GroupMember(
    user: user,
    role: role ?? this.role,
    status: status ?? this.status,
  );
}

class GroupPost {
  final String id;
  final String groupId;
  final AppUser author;
  final String body;
  final DateTime createdAt;
  const GroupPost({required this.id, required this.groupId, required this.author, required this.body, required this.createdAt});
}

class ChatMessage {
  final String id;
  final String? senderId;
  final String sender;
  final String text;
  final DateTime sentAt;
  final bool system;
  final bool important;
  final bool pending;
  const ChatMessage({required this.id, this.senderId, required this.sender, required this.text, required this.sentAt, this.system = false, this.important = false, this.pending = false});
}

class AppNotification {
  final String id;
  final String title;
  final String body;
  final NotificationCategory category;
  final NotificationPriority priority;
  final DateTime createdAt;
  final String? route;
  final bool read;
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.priority,
    required this.createdAt,
    this.route,
    this.read = false,
  });
  AppNotification copyWith({bool? read}) => AppNotification(
    id: id,
    title: title,
    body: body,
    category: category,
    priority: priority,
    createdAt: createdAt,
    route: route,
    read: read ?? this.read,
  );
}

class ActivityEvent {
  final String id;
  final String activityId;
  final String eventType;
  final String? actorUserId;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  const ActivityEvent({required this.id, required this.activityId, required this.eventType, this.actorUserId, this.data = const {}, required this.createdAt});
}

class ActivityHistoryEntry {
  final String id;
  final String? sourceActivityId;
  final String title;
  final ActivityKind kind;
  final DateTime date;
  final double distanceKm;
  final int durationMinutes;
  final int participantCount;
  final String role;
  final bool routeSaved;
  final String routeLabel;
  const ActivityHistoryEntry({required this.id, this.sourceActivityId, required this.title, required this.kind, required this.date, required this.distanceKm, required this.durationMinutes, required this.participantCount, required this.role, required this.routeSaved, required this.routeLabel});
}

class RouteHistoryPoint {
  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final DateTime recordedAt;
  const RouteHistoryPoint({required this.latitude, required this.longitude, required this.accuracyMeters, required this.recordedAt});
}

class ActivityFilterState {
  final String query;
  final ActivityKind? kind;
  final ActivityTimeFilter time;
  final bool openOnly;
  const ActivityFilterState({this.query = '', this.kind, this.time = ActivityTimeFilter.now, this.openOnly = false});
  ActivityFilterState copyWith({String? query, ActivityKind? kind, bool clearKind = false, ActivityTimeFilter? time, bool? openOnly}) => ActivityFilterState(
    query: query ?? this.query,
    kind: clearKind ? null : (kind ?? this.kind),
    time: time ?? this.time,
    openOnly: openOnly ?? this.openOnly,
  );
}

class LiveParticipantPosition {
  final String activityId;
  final String userId;
  final ParticipantRole role;
  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final double? headingDegrees;
  final double? speedMetersPerSecond;
  final DateTime recordedAt;
  final bool sharing;

  const LiveParticipantPosition({
    required this.activityId,
    required this.userId,
    required this.role,
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    this.headingDegrees,
    this.speedMetersPerSecond,
    required this.recordedAt,
    this.sharing = true,
  });

  bool get isStale => DateTime.now().difference(recordedAt) > const Duration(minutes: 2);
}

class ActivityPublicState {
  final String activityId;
  final double latitude;
  final double longitude;
  final int participantCount;
  final DateTime updatedAt;

  const ActivityPublicState({
    required this.activityId,
    required this.latitude,
    required this.longitude,
    required this.participantCount,
    required this.updatedAt,
  });

  bool get isStale => DateTime.now().difference(updatedAt) > const Duration(minutes: 3);
}

class LivePositionSample {
  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final double? headingDegrees;
  final double? speedMetersPerSecond;
  final DateTime recordedAt;
  final int sequence;

  const LivePositionSample({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    this.headingDegrees,
    this.speedMetersPerSecond,
    required this.recordedAt,
    required this.sequence,
  });
}

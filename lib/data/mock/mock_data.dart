import '../../domain/models/activity_models.dart';

final mockNow = DateTime(2026, 9, 13, 9, 15);

const currentUser = AppUser(id: 'u1', name: 'Anders', region: 'Stavanger / Rogaland', interests: [ActivityKind.motorcycle, ActivityKind.ski, ActivityKind.hiking]);
const kari = AppUser(id: 'u2', name: 'Kari', region: 'Sandnes / Rogaland', interests: [ActivityKind.motorcycle, ActivityKind.hiking]);
const marius = AppUser(id: 'u3', name: 'Marius', region: 'Jæren / Rogaland', interests: [ActivityKind.motorcycle, ActivityKind.cycling]);
const ole = AppUser(id: 'u4', name: 'Ole', region: 'Stavanger / Rogaland', interests: [ActivityKind.motorcycle]);
const linn = AppUser(id: 'u5', name: 'Linn', region: 'Bryne / Rogaland', interests: [ActivityKind.motorcycle, ActivityKind.ski]);

List<ActivityParticipant> _liveParticipants({bool stale = false}) => [
  ActivityParticipant(user: currentUser, role: ParticipantRole.leader, status: ParticipantStatus.active, lastUpdated: mockNow),
  ActivityParticipant(user: kari, role: ParticipantRole.participant, status: ParticipantStatus.active, distanceBehindKm: .35, lastUpdated: mockNow.subtract(const Duration(seconds: 8))),
  ActivityParticipant(user: marius, role: ParticipantRole.participant, status: ParticipantStatus.active, distanceBehindKm: 2.1, lastUpdated: mockNow.subtract(Duration(minutes: stale ? 8 : 2))),
  ActivityParticipant(user: ole, role: ParticipantRole.sweep, status: ParticipantStatus.active, distanceBehindKm: 2.4, lastUpdated: mockNow.subtract(const Duration(seconds: 18))),
];

List<ActivityParticipant> _externalParticipants(AppUser leader, List<AppUser> others) => [
  ActivityParticipant(user: leader, role: ParticipantRole.leader, status: ParticipantStatus.approved),
  ...others.map((u) => ActivityParticipant(user: u, role: ParticipantRole.participant, status: ParticipantStatus.approved)),
];

List<Activity> activities({bool staleGps = false, bool pending = false, bool full = false}) => [
  Activity(
    id: 'a1', title: 'MC-tur til Lysebotn', kind: ActivityKind.motorcycle, status: ActivityStatus.active,
    participationMode: ParticipationMode.request, routeLabel: 'Stavanger → Sirdal → Lysebotn', meetingPoint: 'Shell Forus',
    startsAt: mockNow.subtract(const Duration(hours: 2)), maxParticipants: full ? 4 : 12, distanceKm: 18,
    pace: 'Normal', surface: 'Asfalt', description: 'Rolig søndagstur via Sirdal med pause underveis. Vi holder samlet tempo.',
    groupId: 'g1', nextStopName: 'Byrkjedalstunet', nextStopEtaMinutes: 18,
    participants: _liveParticipants(stale: staleGps), mine: true,
  ),
  Activity(
    id: 'a4', title: 'Jærens kveldstur', kind: ActivityKind.motorcycle, status: ActivityStatus.gathering,
    participationMode: ParticipationMode.request, routeLabel: 'Forus → Jæren → Bryne', meetingPoint: 'Circle K Forus',
    startsAt: mockNow.add(const Duration(minutes: 30)), maxParticipants: 8, distanceKm: 4,
    pace: 'Rolig', surface: 'Asfalt', description: 'Kort kveldstur med samling på Forus.',
    groupId: 'g1', nextStopName: 'Bryne sentrum', nextStopEtaMinutes: 35,
    participants: const [
      ActivityParticipant(user: currentUser, role: ParticipantRole.leader, status: ParticipantStatus.approved),
      ActivityParticipant(user: linn, role: ParticipantRole.participant, status: ParticipantStatus.requested),
    ], mine: true,
  ),
  Activity(
    id: 'a2', title: 'Randonee i Sirdal', kind: ActivityKind.ski, status: ActivityStatus.planned,
    participationMode: ParticipationMode.request, routeLabel: 'Sirdal', meetingPoint: 'Ålsheia parkering',
    startsAt: mockNow.add(const Duration(days: 1, hours: 1)), maxParticipants: 8, distanceKm: 31,
    pace: 'Middels', surface: 'Fjell', description: 'Rolig topptur for middels erfarne.',
    groupId: 'g2', nextStopName: 'Ålsheia', nextStopEtaMinutes: 45,
    participants: _externalParticipants(kari, [marius, ole]), requestPending: pending,
  ),
  Activity(
    id: 'a3', title: 'Kveldstur Preikestolen', kind: ActivityKind.hiking, status: ActivityStatus.planned,
    participationMode: ParticipationMode.open, routeLabel: 'Preikestolen tur/retur', meetingPoint: 'Preikestolen parkering',
    startsAt: mockNow.add(const Duration(hours: 9)), maxParticipants: 10, distanceKm: 42,
    pace: 'Rolig', surface: 'Sti', description: 'Kveldstur med god tid og pause på toppen.',
    groupId: 'g4', nextStopName: 'Preikestolen', nextStopEtaMinutes: 70,
    participants: _externalParticipants(ole, [kari, marius]),
  ),
];

List<Group> initialGroups() => const [
  Group(id: 'g1', name: 'Rogaland MC', kind: ActivityKind.motorcycle, region: 'Rogaland', memberCount: 128, upcomingCount: 2, member: true, myRole: GroupRole.owner, description: 'MC-gruppe for turer i Rogaland og omegn.', visibility: GroupVisibility.public, joinMode: GroupJoinMode.request, membersCanCreateActivities: true),
  Group(id: 'g2', name: 'Sirdal vinter', kind: ActivityKind.ski, region: 'Sirdal', memberCount: 42, upcomingCount: 1, member: true, myRole: GroupRole.member, description: 'Ski, randonee og vinterturer i Sirdal.', visibility: GroupVisibility.public, joinMode: GroupJoinMode.request),
  Group(id: 'g3', name: 'Stavanger MTB', kind: ActivityKind.cycling, region: 'Stavanger', memberCount: 86, upcomingCount: 3, description: 'Terrengsykling i Stavanger og omegn.', visibility: GroupVisibility.public, joinMode: GroupJoinMode.request),
  Group(id: 'g4', name: 'Jæren turfolk', kind: ActivityKind.hiking, region: 'Jæren', memberCount: 64, upcomingCount: 2, description: 'Fotturer for alle nivåer på Jæren.', visibility: GroupVisibility.public, joinMode: GroupJoinMode.open),
];

final activityChat = [
  ChatMessage(id: 'm1', sender: 'System', text: 'Kari ble med i aktiviteten.', sentAt: mockNow.subtract(const Duration(minutes: 35)), system: true),
  ChatMessage(id: 'm2', sender: 'Anders', text: 'Vi stopper på Byrkjedalstunet.', sentAt: mockNow.subtract(const Duration(minutes: 16)), important: true),
  ChatMessage(id: 'm3', sender: 'Kari', text: 'Supert, jeg ligger litt bak men tar dere igjen.', sentAt: mockNow.subtract(const Duration(minutes: 12))),
];


final gatheringChat = [
  ChatMessage(id: 'gm1', sender: 'System', text: 'Samling er startet.', sentAt: mockNow.subtract(const Duration(minutes: 8)), system: true),
  ChatMessage(id: 'gm2', sender: 'Linn', text: 'Jeg er på vei, ca. 5 min unna.', sentAt: mockNow.subtract(const Duration(minutes: 4))),
];

final groupChat = [
  ChatMessage(id: 'gc1', sender: 'Kari', text: 'Noen som er klare for tur på søndag?', sentAt: mockNow.subtract(const Duration(hours: 3))),
  ChatMessage(id: 'gc2', sender: 'Anders', text: 'Ja, jeg lager en aktivitet litt senere.', sentAt: mockNow.subtract(const Duration(hours: 2, minutes: 42))),
];


Map<String, List<GroupMember>> initialGroupMembers() => {
  'g1': const [
    GroupMember(user: currentUser, role: GroupRole.owner, status: GroupMembershipStatus.active),
    GroupMember(user: kari, role: GroupRole.admin, status: GroupMembershipStatus.active),
    GroupMember(user: marius, role: GroupRole.member, status: GroupMembershipStatus.active),
    GroupMember(user: linn, role: GroupRole.member, status: GroupMembershipStatus.requested),
  ],
  'g2': const [
    GroupMember(user: kari, role: GroupRole.owner, status: GroupMembershipStatus.active),
    GroupMember(user: currentUser, role: GroupRole.member, status: GroupMembershipStatus.active),
  ],
  'g3': const [
    GroupMember(user: marius, role: GroupRole.owner, status: GroupMembershipStatus.active),
  ],
  'g4': const [
    GroupMember(user: ole, role: GroupRole.owner, status: GroupMembershipStatus.active),
  ],
};

Map<String, List<GroupPost>> initialGroupPosts() => {
  'g1': [
    GroupPost(id: 'p1', groupId: 'g1', author: kari, body: 'Noen som vil være med på en rolig tur søndag?', createdAt: mockNow.subtract(const Duration(hours: 5))),
    GroupPost(id: 'p2', groupId: 'g1', author: currentUser, body: 'Jeg legger ut en aktivitet når ruten er bestemt.', createdAt: mockNow.subtract(const Duration(hours: 4, minutes: 20))),
  ],
  'g2': [
    GroupPost(id: 'p3', groupId: 'g2', author: kari, body: 'Fine forhold i høyden i dag. Husk vind!', createdAt: mockNow.subtract(const Duration(days: 1))),
  ],
};

List<AppNotification> initialNotifications() => [
  AppNotification(id: 'n1', title: 'Møtepunkt endret', body: 'Søndagstur Lysebotn · Shell Sirdal', category: NotificationCategory.activities, priority: NotificationPriority.important, createdAt: mockNow.subtract(const Duration(minutes: 2)), route: '/activity/a1'),
  AppNotification(id: 'n2', title: 'Forespørselen din ble godkjent', body: 'Randonee i Sirdal', category: NotificationCategory.activities, priority: NotificationPriority.normal, createdAt: mockNow.subtract(const Duration(minutes: 18)), route: '/activity/a2'),
  AppNotification(id: 'n3', title: 'Ny aktivitet i Rogaland MC', body: 'Kveldstur Jæren', category: NotificationCategory.groups, priority: NotificationPriority.normal, createdAt: mockNow.subtract(const Duration(hours: 1)), route: '/group/g1'),
  AppNotification(id: 'n4', title: 'Viktig melding fra turleder', body: 'Vi snur ved neste kryss.', category: NotificationCategory.important, priority: NotificationPriority.critical, createdAt: mockNow.subtract(const Duration(minutes: 6)), route: '/activity/a1/live'),
];

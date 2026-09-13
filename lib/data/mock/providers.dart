import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/dev/dev_scenario_provider.dart';
import '../../core/supabase/supabase_providers.dart';
import '../../features/auth/auth_controller.dart';
import '../supabase/supabase_activity_repository.dart';
import '../supabase/supabase_group_repository.dart';
import '../supabase/supabase_chat_repository.dart';
import '../supabase/supabase_live_tracking_repository.dart';
import '../supabase/supabase_notification_repository.dart';
import '../supabase/supabase_history_repository.dart';
import '../supabase/supabase_safety_repository.dart';
import '../../domain/models/activity_models.dart';
import '../../domain/repositories/repositories.dart';
import 'mock_activity_store.dart';
import 'mock_data.dart';
import 'mock_chat_store.dart';
import 'mock_filter_store.dart';
import 'mock_group_store.dart';
import 'mock_notification_store.dart';
import 'mock_profile_store.dart';
import 'mock_settings_store.dart';
import 'mock_history_store.dart';
import 'mock_repositories.dart';

final mockActivityStoreProvider = StateNotifierProvider<MockActivityStore, List<Activity>>((ref) => MockActivityStore());
final mockGroupStoreProvider = StateNotifierProvider<MockGroupStore, List<Group>>((ref) => MockGroupStore());
final mockChatStoreProvider = StateNotifierProvider<MockChatStore, MockChatState>((ref) => MockChatStore());
final activityFilterProvider = StateNotifierProvider<MockFilterStore, ActivityFilterState>((ref) => MockFilterStore());
final mockNotificationStoreProvider = StateNotifierProvider<MockNotificationStore, List<AppNotification>>((ref) => MockNotificationStore());
final mockProfileStoreProvider = StateNotifierProvider<MockProfileStore, ProfileState>((ref) => MockProfileStore());
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError('SharedPreferences not initialized'));
final mockSettingsStoreProvider = StateNotifierProvider<MockSettingsStore, SettingsState>((ref) => MockSettingsStore(ref.watch(sharedPreferencesProvider)));
final mockHistoryStoreProvider = StateNotifierProvider<MockHistoryStore, List<ActivityHistoryEntry>>((ref) => MockHistoryStore());

final activityRepositoryProvider = Provider<ActivityRepository>((ref) {
  final demo = ref.watch(localDemoModeProvider);
  final user = ref.watch(currentSupabaseUserProvider);
  if (!demo && user != null) return SupabaseActivityRepository(ref.watch(supabaseClientProvider));
  final state = ref.watch(mockActivityStoreProvider);
  return MockActivityRepository(ref.watch(devScenarioProvider), state, ref.read(mockActivityStoreProvider.notifier));
});


final liveTrackingRepositoryProvider = Provider<LiveTrackingRepository?>((ref) {
  final demo = ref.watch(localDemoModeProvider);
  final user = ref.watch(currentSupabaseUserProvider);
  if (!demo && user != null) return SupabaseLiveTrackingRepository(ref.watch(supabaseClientProvider));
  return null;
});

final liveParticipantsProvider = StreamProvider.autoDispose.family<List<LiveParticipantPosition>, String>((ref, activityId) {
  final repository = ref.watch(liveTrackingRepositoryProvider);
  if (repository == null) return Stream.value(const <LiveParticipantPosition>[]);
  return repository.watchParticipants(activityId);
});

final activityPublicStateProvider = StreamProvider.autoDispose.family<ActivityPublicState?, String>((ref, activityId) {
  final repository = ref.watch(liveTrackingRepositoryProvider);
  if (repository == null) return Stream.value(null);
  return repository.watchPublicState(activityId);
});

final activityPublicStatesProvider = StreamProvider.autoDispose<List<ActivityPublicState>>((ref) {
  final repository = ref.watch(liveTrackingRepositoryProvider);
  if (repository == null) return Stream.value(const <ActivityPublicState>[]);
  return repository.watchPublicStates();
});

final currentActivityUserIdProvider = Provider<String?>((ref) {
  if (ref.watch(localDemoModeProvider)) return currentUser.id;
  return ref.watch(currentSupabaseUserProvider)?.id;
});
final groupRepositoryProvider = Provider<GroupRepository>((ref) {
  final demo = ref.watch(localDemoModeProvider);
  final user = ref.watch(currentSupabaseUserProvider);
  if (!demo && user != null) return SupabaseGroupRepository(ref.watch(supabaseClientProvider));
  final state = ref.watch(mockGroupStoreProvider);
  return MockGroupRepository(state, ref.read(mockGroupStoreProvider.notifier));
});
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final demo = ref.watch(localDemoModeProvider);
  final user = ref.watch(currentSupabaseUserProvider);
  if (!demo && user != null) return SupabaseChatRepository(ref.watch(supabaseClientProvider));
  ref.watch(mockChatStoreProvider);
  return MockChatRepository(ref.read(mockChatStoreProvider.notifier));
});

final notificationRepositoryProvider = Provider<NotificationRepository?>((ref) {
  final demo = ref.watch(localDemoModeProvider);
  final user = ref.watch(currentSupabaseUserProvider);
  if (!demo && user != null) return SupabaseNotificationRepository(ref.watch(supabaseClientProvider));
  return null;
});

final notificationsProvider = StreamProvider<List<AppNotification>>((ref) {
  final demo = ref.watch(localDemoModeProvider);
  if (demo) {
    final items = ref.watch(mockNotificationStoreProvider);
    return Stream.value(items);
  }
  final repository = ref.watch(notificationRepositoryProvider);
  if (repository == null) return Stream.value(const <AppNotification>[]);
  return repository.watchMine();
});

final historyRepositoryProvider = Provider<HistoryRepository?>((ref) {
  final demo = ref.watch(localDemoModeProvider);
  final user = ref.watch(currentSupabaseUserProvider);
  if (!demo && user != null) return SupabaseHistoryRepository(ref.watch(supabaseClientProvider));
  return null;
});

final activityHistoryProvider = FutureProvider.autoDispose<List<ActivityHistoryEntry>>((ref) async {
  if (ref.watch(localDemoModeProvider)) return ref.watch(mockHistoryStoreProvider);
  final repository = ref.watch(historyRepositoryProvider);
  return repository == null ? const <ActivityHistoryEntry>[] : repository.mine();
});

final historyByIdProvider = FutureProvider.autoDispose.family<ActivityHistoryEntry?, String>((ref, id) async {
  if (ref.watch(localDemoModeProvider)) return ref.watch(mockHistoryStoreProvider).where((e) => e.id == id).firstOrNull;
  final repository = ref.watch(historyRepositoryProvider);
  return repository?.byId(id);
});

final routeHistoryProvider = FutureProvider.autoDispose.family<List<RouteHistoryPoint>, String>((ref, historyId) async {
  if (ref.watch(localDemoModeProvider)) return const <RouteHistoryPoint>[];
  final repository = ref.watch(historyRepositoryProvider);
  return repository == null ? const <RouteHistoryPoint>[] : repository.routePoints(historyId);
});

final activityEventsProvider = FutureProvider.autoDispose.family<List<ActivityEvent>, String>((ref, activityId) async {
  if (ref.watch(localDemoModeProvider)) return const <ActivityEvent>[];
  final repository = ref.watch(historyRepositoryProvider);
  return repository == null ? const <ActivityEvent>[] : repository.eventsForActivity(activityId);
});

List<Activity> applyActivityFilters(List<Activity> items, ActivityFilterState filter, DateTime now) {
  final query = filter.query.trim().toLowerCase();
  return items.where((a) {
    if (filter.kind != null && a.kind != filter.kind) return false;
    if (filter.openOnly && !(a.participationMode == ParticipationMode.open || a.participationMode == ParticipationMode.request)) return false;
    if (query.isNotEmpty && !'${a.title} ${a.routeLabel} ${a.meetingPoint} ${a.kind.label}'.toLowerCase().contains(query)) return false;
    final sameDay = a.startsAt.year == now.year && a.startsAt.month == now.month && a.startsAt.day == now.day;
    switch (filter.time) {
      case ActivityTimeFilter.now:
        return a.status == ActivityStatus.active || a.status == ActivityStatus.paused || a.status == ActivityStatus.gathering || a.startsAt.difference(now).inHours.abs() <= 2;
      case ActivityTimeFilter.today:
        return sameDay || a.status == ActivityStatus.active || a.status == ActivityStatus.paused;
      case ActivityTimeFilter.weekend:
        return a.startsAt.difference(now).inDays >= 0 && a.startsAt.difference(now).inDays <= 7;
      case ActivityTimeFilter.later:
        return a.startsAt.isAfter(now.add(const Duration(days: 1)));
    }
  }).toList();
}

final activitiesProvider = FutureProvider.autoDispose((ref) => ref.watch(activityRepositoryProvider).discover());
final filteredActivitiesProvider = FutureProvider.autoDispose((ref) async {
  final items = await ref.watch(activityRepositoryProvider).discover();
  final filter = ref.watch(activityFilterProvider);
  return applyActivityFilters(items, filter, DateTime.now());
});
final activityByIdProvider = FutureProvider.autoDispose.family<Activity?, String>((ref, id) => ref.watch(activityRepositoryProvider).byId(id));
final myGroupsProvider = FutureProvider((ref) => ref.watch(groupRepositoryProvider).mine());
final discoverGroupsProvider = FutureProvider((ref) => ref.watch(groupRepositoryProvider).discover());
final groupByIdProvider = FutureProvider.family<Group?, String>((ref, id) => ref.watch(groupRepositoryProvider).byId(id));
final activityMessagesProvider = StreamProvider.autoDispose.family<List<ChatMessage>, String>((ref, id) {
  if (ref.watch(localDemoModeProvider)) ref.watch(mockChatStoreProvider);
  return ref.watch(chatRepositoryProvider).watchActivityMessages(id);
});
final groupMessagesProvider = StreamProvider.autoDispose.family<List<ChatMessage>, String>((ref, id) {
  if (ref.watch(localDemoModeProvider)) ref.watch(mockChatStoreProvider);
  return ref.watch(chatRepositoryProvider).watchGroupMessages(id);
});


final groupMembersProvider = FutureProvider.autoDispose.family<List<GroupMember>, String>((ref, id) {
  if (ref.watch(localDemoModeProvider)) ref.watch(mockGroupStoreProvider);
  return ref.watch(groupRepositoryProvider).members(id);
});
final pendingGroupMembersProvider = FutureProvider.autoDispose.family<List<GroupMember>, String>((ref, id) {
  if (ref.watch(localDemoModeProvider)) ref.watch(mockGroupStoreProvider);
  return ref.watch(groupRepositoryProvider).pendingMembers(id);
});
final groupPostsProvider = FutureProvider.autoDispose.family<List<GroupPost>, String>((ref, id) {
  if (ref.watch(localDemoModeProvider)) ref.watch(mockGroupStoreProvider);
  return ref.watch(groupRepositoryProvider).posts(id);
});

final groupActivitiesProvider = FutureProvider.autoDispose.family<List<Activity>, String>((ref, groupId) async {
  final items = await ref.watch(activityRepositoryProvider).discover();
  return items.where((activity) => activity.groupId == groupId && activity.status != ActivityStatus.cancelled).toList()
    ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
});

extension _ProvidersFirstOrNull<E> on Iterable<E> { E? get firstOrNull => isEmpty ? null : first; }

final safetyRepositoryProvider = Provider<SafetyRepository?>((ref) {
  final demo = ref.watch(localDemoModeProvider);
  final user = ref.watch(currentSupabaseUserProvider);
  if (!demo && user != null) return SupabaseSafetyRepository(ref.watch(supabaseClientProvider));
  return null;
});

final blockedUsersProvider = FutureProvider.autoDispose<List<BlockedUserEntry>>((ref) async {
  final repository = ref.watch(safetyRepositoryProvider);
  return repository == null ? const <BlockedUserEntry>[] : repository.blockedUsers();
});

final myReportsProvider = FutureProvider.autoDispose<List<UserReportEntry>>((ref) async {
  final repository = ref.watch(safetyRepositoryProvider);
  return repository == null ? const <UserReportEntry>[] : repository.myReports();
});


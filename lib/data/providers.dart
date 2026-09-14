import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/supabase/supabase_providers.dart';
import '../domain/models/activity_models.dart';
import '../domain/repositories/repositories.dart';
import 'local/activity_filter_store.dart';
import 'local/settings_store.dart';
import 'supabase/supabase_activity_repository.dart';
import 'supabase/supabase_chat_repository.dart';
import 'supabase/supabase_group_repository.dart';
import 'supabase/supabase_history_repository.dart';
import 'supabase/supabase_live_tracking_repository.dart';
import 'supabase/supabase_notification_repository.dart';
import 'supabase/supabase_safety_repository.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError('SharedPreferences not initialized'));
final settingsStoreProvider = StateNotifierProvider<LocalSettingsStore, SettingsState>((ref) => LocalSettingsStore(ref.watch(sharedPreferencesProvider)));
final activityFilterProvider = StateNotifierProvider<ActivityFilterStore, ActivityFilterState>((ref) => ActivityFilterStore());

final activityRepositoryProvider = Provider<ActivityRepository>((ref) {
  return SupabaseActivityRepository(ref.watch(supabaseClientProvider));
});

final groupRepositoryProvider = Provider<GroupRepository>((ref) {
  return SupabaseGroupRepository(ref.watch(supabaseClientProvider));
});

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return SupabaseChatRepository(ref.watch(supabaseClientProvider));
});

final liveTrackingRepositoryProvider = Provider<LiveTrackingRepository>((ref) {
  return SupabaseLiveTrackingRepository(ref.watch(supabaseClientProvider));
});

final notificationRepositoryProvider = Provider<NotificationRepository?>((ref) {
  final session = ref.watch(authSessionProvider).valueOrNull;
  if (session?.user == null) return null;
  return SupabaseNotificationRepository(ref.watch(supabaseClientProvider));
});

final historyRepositoryProvider = Provider<HistoryRepository?>((ref) {
  final user = ref.watch(currentSupabaseUserProvider);
  if (user == null) return null;
  return SupabaseHistoryRepository(ref.watch(supabaseClientProvider));
});

final safetyRepositoryProvider = Provider<SafetyRepository?>((ref) {
  final user = ref.watch(currentSupabaseUserProvider);
  if (user == null) return null;
  return SupabaseSafetyRepository(ref.watch(supabaseClientProvider));
});

final currentActivityUserIdProvider = Provider<String?>((ref) => ref.watch(currentSupabaseUserProvider)?.id);

final liveParticipantsProvider = StreamProvider.autoDispose.family<List<LiveParticipantPosition>, String>((ref, activityId) {
  return ref.watch(liveTrackingRepositoryProvider).watchParticipants(activityId);
});

final activityPublicStateProvider = StreamProvider.autoDispose.family<ActivityPublicState?, String>((ref, activityId) {
  return ref.watch(liveTrackingRepositoryProvider).watchPublicState(activityId);
});

final activityPublicStatesProvider = StreamProvider.autoDispose<List<ActivityPublicState>>((ref) {
  return ref.watch(liveTrackingRepositoryProvider).watchPublicStates();
});

final notificationsProvider = StreamProvider<List<AppNotification>>((ref) async* {
  ref.watch(authSessionProvider);
  final repository = ref.watch(notificationRepositoryProvider);
  if (repository == null) {
    yield const <AppNotification>[];
    return;
  }
  try {
    yield* repository.watchMine();
  } catch (error) {
    final text = error.toString();
    if (!text.contains('InvalidJWTToken') && !text.toLowerCase().contains('token has expired')) rethrow;
    final client = ref.read(supabaseClientProvider);
    final refreshed = await client.auth.refreshSession();
    final accessToken = refreshed.session?.accessToken;
    if (accessToken == null) rethrow;
    await client.realtime.setAuth(accessToken);
    yield* repository.watchMine();
  }
});

final activityHistoryProvider = FutureProvider.autoDispose<List<ActivityHistoryEntry>>((ref) async {
  final repository = ref.watch(historyRepositoryProvider);
  return repository == null ? const <ActivityHistoryEntry>[] : repository.mine();
});

final historyByIdProvider = FutureProvider.autoDispose.family<ActivityHistoryEntry?, String>((ref, id) async {
  return ref.watch(historyRepositoryProvider)?.byId(id);
});

final routeHistoryProvider = FutureProvider.autoDispose.family<List<RouteHistoryPoint>, String>((ref, historyId) async {
  final repository = ref.watch(historyRepositoryProvider);
  return repository == null ? const <RouteHistoryPoint>[] : repository.routePoints(historyId);
});

final activityEventsProvider = FutureProvider.autoDispose.family<List<ActivityEvent>, String>((ref, activityId) async {
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
  return applyActivityFilters(items, ref.watch(activityFilterProvider), DateTime.now());
});
final activityByIdProvider = FutureProvider.autoDispose.family<Activity?, String>((ref, id) => ref.watch(activityRepositoryProvider).byId(id));
final myGroupsProvider = FutureProvider((ref) => ref.watch(groupRepositoryProvider).mine());
final discoverGroupsProvider = FutureProvider((ref) => ref.watch(groupRepositoryProvider).discover());
final groupByIdProvider = FutureProvider.family<Group?, String>((ref, id) => ref.watch(groupRepositoryProvider).byId(id));
final activityMessagesProvider = StreamProvider.autoDispose.family<List<ChatMessage>, String>((ref, id) => ref.watch(chatRepositoryProvider).watchActivityMessages(id));
final groupMessagesProvider = StreamProvider.autoDispose.family<List<ChatMessage>, String>((ref, id) => ref.watch(chatRepositoryProvider).watchGroupMessages(id));
final groupMembersProvider = FutureProvider.autoDispose.family<List<GroupMember>, String>((ref, id) => ref.watch(groupRepositoryProvider).members(id));
final pendingGroupMembersProvider = FutureProvider.autoDispose.family<List<GroupMember>, String>((ref, id) => ref.watch(groupRepositoryProvider).pendingMembers(id));
final groupPostsProvider = FutureProvider.autoDispose.family<List<GroupPost>, String>((ref, id) => ref.watch(groupRepositoryProvider).posts(id));

final groupActivitiesProvider = FutureProvider.autoDispose.family<List<Activity>, String>((ref, groupId) async {
  final items = await ref.watch(activityRepositoryProvider).discover();
  return items.where((activity) => activity.groupId == groupId && activity.status != ActivityStatus.cancelled).toList()
    ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
});

final blockedUsersProvider = FutureProvider.autoDispose<List<BlockedUserEntry>>((ref) async {
  final repository = ref.watch(safetyRepositoryProvider);
  return repository == null ? const <BlockedUserEntry>[] : repository.blockedUsers();
});

final myReportsProvider = FutureProvider.autoDispose<List<UserReportEntry>>((ref) async {
  final repository = ref.watch(safetyRepositoryProvider);
  return repository == null ? const <UserReportEntry>[] : repository.myReports();
});

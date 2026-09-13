import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/map/map_screen.dart';
import '../features/activities/activities_screen.dart';
import '../features/activities/activity_detail_screen.dart';
import '../features/activities/create_activity_screen.dart';
import '../features/live_activity/live_activity_screen.dart';
import '../features/groups/groups_screen.dart';
import '../features/groups/group_detail_screen.dart';
import '../features/groups/create_group_screen.dart';
import '../features/groups/group_admin_screen.dart';
import '../features/chat/chat_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/settings/blocked_users_screen.dart';
import '../features/settings/report_help_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/history/history_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) => GoRouter(
  initialLocation: '/map',
  routes: [
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(path: '/map', builder: (_, __) => const MapScreen()),
        GoRoute(path: '/activities', builder: (_, __) => const ActivitiesScreen()),
        GoRoute(path: '/groups', builder: (_, __) => const GroupsScreen()),
        GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      ],
    ),
    GoRoute(path: '/activity/new', builder: (_, s) => CreateActivityScreen(initialGroupId: s.uri.queryParameters['groupId'])),
    GoRoute(path: '/activity/:id', builder: (_, s) => ActivityDetailScreen(activityId: s.pathParameters['id']!)),
    GoRoute(path: '/activity/:id/live', builder: (_, s) => LiveActivityScreen(activityId: s.pathParameters['id']!)),
    GoRoute(path: '/activity/:id/chat', builder: (_, s) => ChatScreen(title: 'Aktivitetschat', entityId: s.pathParameters['id']!, isGroup: false)),
    GoRoute(path: '/group/new', builder: (_, __) => const CreateGroupScreen()),
    GoRoute(path: '/group/:id', builder: (_, s) => GroupDetailScreen(groupId: s.pathParameters['id']!)),
    GoRoute(path: '/group/:id/admin', builder: (_, s) => GroupAdminScreen(groupId: s.pathParameters['id']!)),
    GoRoute(path: '/group/:id/chat', builder: (_, s) => ChatScreen(title: 'Gruppechat', entityId: s.pathParameters['id']!, isGroup: true)),
    GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
    GoRoute(path: '/settings/blocked', builder: (_, __) => const BlockedUsersScreen()),
    GoRoute(path: '/settings/report', builder: (_, s) => ReportHelpScreen(targetType: s.uri.queryParameters['targetType'], targetId: s.uri.queryParameters['targetId'])),
    GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),
    GoRoute(path: '/history', builder: (_, __) => const HistoryScreen()),
    GoRoute(path: '/history/:id', builder: (_, s) => HistoryDetailScreen(historyId: s.pathParameters['id']!)),
  ],
));

class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  int _index(String location) {
    if (location.startsWith('/activities')) return 1;
    if (location.startsWith('/groups')) return 3;
    if (location.startsWith('/profile')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final selected = _index(location);
    return Scaffold(
      body: child,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: SizedBox(
        width: 54,
        height: 54,
        child: FloatingActionButton(
          onPressed: () => context.push('/activity/new'),
          elevation: 4,
          child: const Icon(Icons.add, size: 26),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: (index) {
          switch (index) {
            case 0: context.go('/map');
            case 1: context.go('/activities');
            case 2: context.push('/activity/new');
            case 3: context.go('/groups');
            case 4: context.go('/profile');
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'Kart'),
          NavigationDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore), label: 'Aktiviteter'),
          NavigationDestination(icon: Icon(Icons.add_circle_outline), selectedIcon: Icon(Icons.add_circle), label: 'Start'),
          NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups), label: 'Grupper'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }
}

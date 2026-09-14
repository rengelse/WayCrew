import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('notification navigation validates live targets before opening', () {
    final repo = File('lib/data/supabase/supabase_notification_repository.dart').readAsStringSync();
    final screen = File('lib/features/notifications/notifications_screen.dart').readAsStringSync();
    expect(repo, contains("rpc('resolve_notification_route'"));
    expect(screen, contains('Innholdet er ikke lenger tilgjengelig. Varslet er fjernet.'));
    expect(screen, contains('resolveRoute(item.id)'));
  });

  test('orphan cleanup migration removes stale targets and chat notifications', () {
    final sql = File('supabase/migrations/20260914201000_orphan_cleanup_navigation_integrity.sql').readAsStringSync();
    expect(sql, contains('create or replace function public.resolve_notification_route'));
    expect(sql, contains('cleanup_notifications_for_deleted_entity'));
    expect(sql, contains('cleanup_chat_notifications_on_membership_change'));
    expect(sql, contains("entity_type='history'"));
    expect(sql, contains("route like '%/chat'"));
  });

  test('chat access failures are rendered as user-facing states', () {
    final chat = File('lib/features/chat/chat_screen.dart').readAsStringSync();
    final errors = File('lib/core/errors_user_facing.dart').readAsStringSync();
    expect(chat, contains('_ChatUnavailableState'));
    expect(chat, isNot(contains(r"error: (e, _) => Center(child: Text('$e'))")));
    expect(errors, contains('activity_chat_membership_required'));
    expect(errors, contains('group_chat_membership_required'));
  });
}

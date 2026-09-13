import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('delete cascade sync triggers never recreate chats on DELETE', () {
    final sql = File('supabase/migrations/20260913210000_deletion_trigger_fix.sql').readAsStringSync();
    expect(sql, contains("if tg_op='DELETE' then"));
    expect(sql, contains('create or replace function public.sync_group_chat_member()'));
    expect(sql, contains('create or replace function public.sync_activity_chat_member()'));
    expect(sql, contains('create or replace function public.delete_activity'));
    expect(sql, contains('activity_owner_required'));
  });

  test('activity deletion uses RPC and WayCrew branding is bundled', () {
    final repository = File('lib/data/supabase/supabase_activity_repository.dart').readAsStringSync();
    final app = File('lib/app/activity_network_app.dart').readAsStringSync();
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(repository, contains("rpc('delete_activity'"));
    expect(app, contains("title: 'WayCrew'"));
    expect(pubspec, contains('assets/branding/waycrew_icon.png'));
    expect(File('assets/branding/waycrew_icon.png').existsSync(), isTrue);
  });
}

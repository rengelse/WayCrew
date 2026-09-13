import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production hardening migration locks critical table mutations behind RPC', () {
    final sql = File('supabase/migrations/20260913200000_production_hardening.sql').readAsStringSync();
    expect(sql, contains('revoke insert, update on public.activities from authenticated'));
    expect(sql, contains('revoke insert, update on public.groups from authenticated'));
    expect(sql, contains('create or replace function public.update_group'));
    expect(sql, contains('group_admin_required'));
  });

  test('group repository updates through RPC instead of direct table update', () {
    final source = File('lib/data/supabase/supabase_group_repository.dart').readAsStringSync();
    expect(source, contains("rpc('update_group'"));
    expect(source, isNot(contains("from('groups').update")));
  });
}

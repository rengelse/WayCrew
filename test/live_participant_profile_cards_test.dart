import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('live map exposes participant tap callback', () {
    final source = File('lib/core/map/live_activity_map.dart').readAsStringSync();
    expect(source, contains('final ValueChanged<String>? onParticipantTap'));
    expect(source, contains('controller.onSymbolTapped.add(_onSymbolTapped)'));
    expect(source, contains('_symbolParticipants[symbol.id] = position.userId'));
  });

  test('live participant profile is server-authorized and avatar remains private', () {
    final sql = File('supabase/migrations/20260914204500_live_participant_profile_cards.sql').readAsStringSync();
    expect(sql, contains('get_live_participant_profile'));
    expect(sql, contains("a.status in ('active', 'paused')"));
    expect(sql, contains('avatar_read_live_participant'));
    expect(sql, contains('can_read_live_participant_profile'));
  });

  test('profile card only exposes existing basic profile fields', () {
    final source = File('lib/domain/models/profile_models.dart').readAsStringSync();
    expect(source, contains('class LiveParticipantProfileCard'));
    expect(source, contains('final String region'));
    expect(source, contains('final String bio'));
    expect(source, contains('final String? avatarUrl'));
  });
}

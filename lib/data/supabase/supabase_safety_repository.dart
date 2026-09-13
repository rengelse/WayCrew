import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/activity_models.dart';
import '../../domain/repositories/repositories.dart';

class SupabaseSafetyRepository implements SafetyRepository {
  final SupabaseClient _client;
  const SupabaseSafetyRepository(this._client);

  String get _userId {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('Not authenticated');
    return user.id;
  }

  @override
  Future<List<BlockedUserEntry>> blockedUsers() async {
    final rows = await _client
        .from('blocked_users')
        .select('blocked_user_id, blocked_display_name, created_at')
        .eq('user_id', _userId)
        .order('created_at', ascending: false);
    return rows.map<BlockedUserEntry>((raw) {
      final row = Map<String, dynamic>.from(raw);
      return BlockedUserEntry(
        userId: row['blocked_user_id'] as String,
        displayName: (row['blocked_display_name'] as String?)?.trim().isNotEmpty == true
            ? (row['blocked_display_name'] as String).trim()
            : 'Bruker',
        blockedAt: DateTime.tryParse(row['created_at'] as String? ?? '')?.toLocal() ?? DateTime.now(),
      );
    }).toList();
  }

  @override
  Future<void> blockUser(String userId) async {
    if (userId == _userId) throw StateError('Du kan ikke blokkere deg selv.');
    await _client.rpc('block_user', params: {'p_blocked_user_id': userId});
  }

  @override
  Future<void> unblockUser(String userId) async {
    await _client.rpc('unblock_user', params: {'p_blocked_user_id': userId});
  }

  @override
  Future<void> submitReport({required String category, required String description, String? targetType, String? targetId}) async {
    await _client.rpc('submit_user_report', params: {
      'p_category': category,
      'p_description': description.trim(),
      'p_target_type': targetType,
      'p_target_id': targetId,
    });
  }

  @override
  Future<List<UserReportEntry>> myReports() async {
    final rows = await _client
        .from('user_reports')
        .select('id, category, description, target_type, target_id, status, created_at')
        .eq('reporter_id', _userId)
        .order('created_at', ascending: false);
    return rows.map<UserReportEntry>((raw) {
      final row = Map<String, dynamic>.from(raw);
      return UserReportEntry(
        id: row['id'] as String,
        category: row['category'] as String? ?? 'other',
        description: row['description'] as String? ?? '',
        targetType: row['target_type'] as String?,
        targetId: row['target_id'] as String?,
        status: row['status'] as String? ?? 'open',
        createdAt: DateTime.tryParse(row['created_at'] as String? ?? '')?.toLocal() ?? DateTime.now(),
      );
    }).toList();
  }
}

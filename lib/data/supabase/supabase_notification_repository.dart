import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/activity_models.dart';
import '../../domain/repositories/repositories.dart';

class SupabaseNotificationRepository implements NotificationRepository {
  final SupabaseClient _client;
  const SupabaseNotificationRepository(this._client);

  String get _userId => _client.auth.currentUser!.id;

  @override
  Stream<List<AppNotification>> watchMine() {
    return _client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', _userId)
        .order('created_at', ascending: false)
        .map((rows) => rows.map(_fromRow).toList());
  }

  @override
  Future<void> markRead(String id) async {
    await _client.from('notifications').update({'read_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id).eq('user_id', _userId);
  }

  @override
  Future<void> markAllRead() async {
    await _client.from('notifications').update({'read_at': DateTime.now().toUtc().toIso8601String()}).eq('user_id', _userId);
  }

  @override
  Future<void> remove(String id) async {
    await _client.from('notifications').delete().eq('id', id).eq('user_id', _userId);
  }

  @override
  Future<String?> resolveRoute(String id) async {
    final result = await _client.rpc('resolve_notification_route', params: {'p_notification_id': id});
    if (result is String && result.trim().isNotEmpty) return result;
    return null;
  }

  AppNotification _fromRow(Map<String, dynamic> row) {
    return AppNotification(
      id: row['id'] as String,
      title: row['title'] as String? ?? 'Varsel',
      body: row['body'] as String? ?? '',
      category: NotificationCategory.values.where((e) => e.name == row['category']).firstOrNull ?? NotificationCategory.activities,
      priority: NotificationPriority.values.where((e) => e.name == row['priority']).firstOrNull ?? NotificationPriority.normal,
      createdAt: DateTime.tryParse(row['created_at'] as String? ?? '')?.toLocal() ?? DateTime.now(),
      route: row['route'] as String?,
      read: row['read_at'] != null,
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> { E? get firstOrNull => isEmpty ? null : first; }

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/activity_models.dart';
import '../../domain/repositories/repositories.dart';

class SupabaseChatRepository implements ChatRepository {
  final SupabaseClient _client;
  const SupabaseChatRepository(this._client);

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('Ingen innlogget Supabase-bruker.');
    return id;
  }

  @override
  Future<List<ChatMessage>> activityMessages(String activityId) async {
    final chatId = await _activityChatId(activityId);
    final rows = await _client.from('messages').select().eq('chat_id', chatId).order('created_at');
    return _hydrateMessages(rows);
  }

  @override
  Future<List<ChatMessage>> groupMessages(String groupId) async {
    final chatId = await _groupChatId(groupId);
    final rows = await _client.from('messages').select().eq('chat_id', chatId).order('created_at');
    return _hydrateMessages(rows);
  }

  @override
  Stream<List<ChatMessage>> watchActivityMessages(String activityId) async* {
    final chatId = await _activityChatId(activityId);
    yield* _watchChat(chatId);
  }

  @override
  Stream<List<ChatMessage>> watchGroupMessages(String groupId) async* {
    final chatId = await _groupChatId(groupId);
    yield* _watchChat(chatId);
  }

  Stream<List<ChatMessage>> _watchChat(String chatId) {
    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('chat_id', chatId)
        .order('created_at')
        .asyncMap(_hydrateMessages);
  }

  @override
  Future<void> sendActivityMessage(
    String activityId,
    String text, {
    bool important = false,
    String? senderName,
  }) async {
    final clean = text.trim();
    if (clean.isEmpty) return;
    final chatId = await _activityChatId(activityId);
    await _client.from('messages').insert({
      'chat_id': chatId,
      'sender_id': _userId,
      'message_type': 'text',
      'body': clean,
      'important': important,
    });
  }

  @override
  Future<void> sendGroupMessage(String groupId, String text, {String? senderName}) async {
    final clean = text.trim();
    if (clean.isEmpty) return;
    final chatId = await _groupChatId(groupId);
    await _client.from('messages').insert({
      'chat_id': chatId,
      'sender_id': _userId,
      'message_type': 'text',
      'body': clean,
      'important': false,
    });
  }

  @override
  Future<void> deleteMessage(String messageId) async {
    await _client.rpc('delete_chat_message', params: {'p_message_id': messageId});
  }

  Future<String> _activityChatId(String activityId) async {
    final row = await _client.from('chats').select('id').eq('activity_id', activityId).maybeSingle();
    if (row == null) {
      final id = await _client.rpc('ensure_activity_chat', params: {'p_activity_id': activityId});
      if (id is String && id.isNotEmpty) return id;
      throw StateError('Aktivitetschat finnes ikke.');
    }
    return row['id'] as String;
  }

  Future<String> _groupChatId(String groupId) async {
    final row = await _client.from('chats').select('id').eq('group_id', groupId).maybeSingle();
    if (row == null) {
      final id = await _client.rpc('ensure_group_chat', params: {'p_group_id': groupId});
      if (id is String && id.isNotEmpty) return id;
      throw StateError('Gruppechat finnes ikke.');
    }
    return row['id'] as String;
  }

  Future<List<ChatMessage>> _hydrateMessages(List<dynamic> rows) async {
    final senderIds = rows
        .map((row) => row['sender_id'] as String?)
        .whereType<String>()
        .toSet()
        .toList();
    final profiles = <String, String>{};
    if (senderIds.isNotEmpty) {
      final profileRows = await _client.from('profiles').select('id,display_name').inFilter('id', senderIds);
      for (final raw in profileRows) {
        final row = Map<String, dynamic>.from(raw);
        final id = row['id'] as String;
        final name = (row['display_name'] as String?)?.trim();
        profiles[id] = name?.isNotEmpty == true ? name! : 'Deltaker';
      }
    }

    return rows.map<ChatMessage>((raw) {
      final row = Map<String, dynamic>.from(raw);
      final senderId = row['sender_id'] as String?;
      final type = row['message_type'] as String? ?? 'text';
      final deletedAt = DateTime.tryParse(row['deleted_at'] as String? ?? '')?.toLocal();
      return ChatMessage(
        id: row['id'] as String,
        senderId: senderId,
        sender: senderId == null ? 'System' : (profiles[senderId] ?? 'Deltaker'),
        text: deletedAt == null ? (row['body'] as String? ?? '') : '',
        sentAt: DateTime.tryParse(row['created_at'] as String? ?? '')?.toLocal() ?? DateTime.now(),
        system: type == 'system',
        important: row['important'] as bool? ?? false,
        deletedAt: deletedAt,
        deletedById: row['deleted_by'] as String?,
      );
    }).toList();
  }
}

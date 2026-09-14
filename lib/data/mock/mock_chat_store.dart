import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/activity_models.dart';
import 'mock_data.dart';

class MockChatState {
  final Map<String, List<ChatMessage>> activity;
  final Map<String, List<ChatMessage>> group;
  const MockChatState({required this.activity, required this.group});
}

class MockChatStore extends StateNotifier<MockChatState> {
  MockChatStore() : super(MockChatState(
    activity: {'a1': List<ChatMessage>.from(activityChat), 'a4': List<ChatMessage>.from(gatheringChat)},
    group: {'g1': List<ChatMessage>.from(groupChat), 'g2': <ChatMessage>[]},
  ));

  List<ChatMessage> activityMessages(String id) => List.unmodifiable(state.activity[id] ?? const []);
  List<ChatMessage> groupMessages(String id) => List.unmodifiable(state.group[id] ?? const []);

  void sendActivity(String id, String text, {bool important = false, String? senderName}) {
    final clean = text.trim(); if (clean.isEmpty) return;
    final next = Map<String, List<ChatMessage>>.from(state.activity);
    next[id] = [...(next[id] ?? const []), ChatMessage(id: 'local-${DateTime.now().microsecondsSinceEpoch}', sender: senderName?.trim().isNotEmpty == true ? senderName!.trim() : currentUser.name, text: clean, sentAt: DateTime.now(), important: important)];
    state = MockChatState(activity: next, group: state.group);
  }

  void sendGroup(String id, String text, {String? senderName}) {
    final clean = text.trim(); if (clean.isEmpty) return;
    final next = Map<String, List<ChatMessage>>.from(state.group);
    next[id] = [...(next[id] ?? const []), ChatMessage(id: 'local-${DateTime.now().microsecondsSinceEpoch}', sender: senderName?.trim().isNotEmpty == true ? senderName!.trim() : currentUser.name, text: clean, sentAt: DateTime.now())];
    state = MockChatState(activity: state.activity, group: next);
  }
  void deleteMessage(String messageId) {
    ChatMessage deleted(ChatMessage message) => ChatMessage(
      id: message.id,
      senderId: message.senderId,
      sender: message.sender,
      text: '',
      sentAt: message.sentAt,
      system: message.system,
      important: false,
      pending: false,
      deletedAt: DateTime.now(),
      deletedById: currentUser.id,
    );

    var changed = false;
    final nextActivity = <String, List<ChatMessage>>{};
    for (final entry in state.activity.entries) {
      nextActivity[entry.key] = entry.value.map((message) {
        if (message.id != messageId || message.system || message.isDeleted) return message;
        changed = true;
        return deleted(message);
      }).toList();
    }
    final nextGroup = <String, List<ChatMessage>>{};
    for (final entry in state.group.entries) {
      nextGroup[entry.key] = entry.value.map((message) {
        if (message.id != messageId || message.system || message.isDeleted) return message;
        changed = true;
        return deleted(message);
      }).toList();
    }
    if (changed) state = MockChatState(activity: nextActivity, group: nextGroup);
  }

}

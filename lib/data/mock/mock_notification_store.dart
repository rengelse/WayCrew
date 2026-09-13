import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/activity_models.dart';
import 'mock_data.dart';

class MockNotificationStore extends StateNotifier<List<AppNotification>> {
  MockNotificationStore() : super(initialNotifications());

  void markRead(String id) {
    state = [for (final item in state) if (item.id == id) item.copyWith(read: true) else item];
  }

  void markAllRead() {
    state = [for (final item in state) item.copyWith(read: true)];
  }

  void remove(String id) {
    state = state.where((item) => item.id != id).toList();
  }
}

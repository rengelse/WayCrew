import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/activity_models.dart';

class MockFilterStore extends StateNotifier<ActivityFilterState> {
  MockFilterStore() : super(const ActivityFilterState());
  void setQuery(String value) => state = state.copyWith(query: value);
  void setKind(ActivityKind? value) => state = value == null ? state.copyWith(clearKind: true) : state.copyWith(kind: value);
  void setTime(ActivityTimeFilter value) => state = state.copyWith(time: value);
  void setOpenOnly(bool value) => state = state.copyWith(openOnly: value);
  void reset() => state = const ActivityFilterState();
}

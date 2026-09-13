import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum VisibilityLevel { everyone, participants, onlyMe }
enum ThemePreference { system, light, dark }

class SettingsState {
  final VisibilityLevel profileVisibility;
  final VisibilityLevel historyVisibility;
  final bool participantLocation;
  final bool leaderLocation;
  final bool publicApproximateLocation;
  final bool nearbyNotifications;
  final bool chatNotifications;
  final bool importantNotifications;
  final bool routeHistory;
  final int nearbyRadiusKm;
  final ThemePreference themePreference;
  const SettingsState({
    this.profileVisibility = VisibilityLevel.everyone,
    this.historyVisibility = VisibilityLevel.participants,
    this.participantLocation = true,
    this.leaderLocation = true,
    this.publicApproximateLocation = true,
    this.nearbyNotifications = true,
    this.chatNotifications = true,
    this.importantNotifications = true,
    this.routeHistory = true,
    this.nearbyRadiusKm = 50,
    this.themePreference = ThemePreference.system,
  });
  SettingsState copyWith({
    VisibilityLevel? profileVisibility,
    VisibilityLevel? historyVisibility,
    bool? participantLocation,
    bool? leaderLocation,
    bool? publicApproximateLocation,
    bool? nearbyNotifications,
    bool? chatNotifications,
    bool? importantNotifications,
    bool? routeHistory,
    int? nearbyRadiusKm,
    ThemePreference? themePreference,
  }) => SettingsState(
    profileVisibility: profileVisibility ?? this.profileVisibility,
    historyVisibility: historyVisibility ?? this.historyVisibility,
    participantLocation: participantLocation ?? this.participantLocation,
    leaderLocation: leaderLocation ?? this.leaderLocation,
    publicApproximateLocation: publicApproximateLocation ?? this.publicApproximateLocation,
    nearbyNotifications: nearbyNotifications ?? this.nearbyNotifications,
    chatNotifications: chatNotifications ?? this.chatNotifications,
    importantNotifications: importantNotifications ?? this.importantNotifications,
    routeHistory: routeHistory ?? this.routeHistory,
    nearbyRadiusKm: nearbyRadiusKm ?? this.nearbyRadiusKm,
    themePreference: themePreference ?? this.themePreference,
  );
}

class MockSettingsStore extends StateNotifier<SettingsState> {
  static const _themeKey = 'settings.theme';
  static const _participantLocationKey = 'settings.participant_location';
  static const _leaderLocationKey = 'settings.leader_location';
  static const _publicApproximateLocationKey = 'settings.public_approximate_location';
  static const _routeHistoryKey = 'settings.route_history';
  final SharedPreferences? _preferences;

  MockSettingsStore([this._preferences]) : super(SettingsState(
    themePreference: _readTheme(_preferences),
    participantLocation: _preferences?.getBool(_participantLocationKey) ?? true,
    leaderLocation: _preferences?.getBool(_leaderLocationKey) ?? true,
    publicApproximateLocation: _preferences?.getBool(_publicApproximateLocationKey) ?? true,
    routeHistory: _preferences?.getBool(_routeHistoryKey) ?? true,
  ));

  static ThemePreference _readTheme(SharedPreferences? preferences) {
    final value = preferences?.getString(_themeKey);
    return ThemePreference.values.where((item) => item.name == value).firstOrNull ?? ThemePreference.system;
  }

  void setProfileVisibility(VisibilityLevel v) => state = state.copyWith(profileVisibility: v);
  void setHistoryVisibility(VisibilityLevel v) => state = state.copyWith(historyVisibility: v);
  void setParticipantLocation(bool v) { state = state.copyWith(participantLocation: v); _preferences?.setBool(_participantLocationKey, v); }
  void setLeaderLocation(bool v) { state = state.copyWith(leaderLocation: v); _preferences?.setBool(_leaderLocationKey, v); }
  void setPublicApproximateLocation(bool v) { state = state.copyWith(publicApproximateLocation: v); _preferences?.setBool(_publicApproximateLocationKey, v); }
  void setNearbyNotifications(bool v) => state = state.copyWith(nearbyNotifications: v);
  void setChatNotifications(bool v) => state = state.copyWith(chatNotifications: v);
  void setImportantNotifications(bool v) => state = state.copyWith(importantNotifications: v);
  void setRouteHistory(bool v) { state = state.copyWith(routeHistory: v); _preferences?.setBool(_routeHistoryKey, v); }
  void setNearbyRadius(int v) => state = state.copyWith(nearbyRadiusKm: v);
  void setThemePreference(ThemePreference v) {
    state = state.copyWith(themePreference: v);
    _preferences?.setString(_themeKey, v.name);
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}

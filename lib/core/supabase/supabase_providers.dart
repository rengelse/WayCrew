import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Emits the current session immediately and then every auth state change.
final authSessionProvider = StreamProvider<Session?>((ref) async* {
  final client = ref.watch(supabaseClientProvider);
  yield client.auth.currentSession;
  await for (final event in client.auth.onAuthStateChange) {
    yield event.session;
  }
});

final currentSupabaseUserProvider = Provider<User?>((ref) {
  return ref.watch(authSessionProvider).valueOrNull?.user;
});

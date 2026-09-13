import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/supabase/supabase_providers.dart';
import '../../data/supabase/supabase_auth_repository.dart';

final authRepositoryProvider = Provider<SupabaseAuthRepository>((ref) {
  return SupabaseAuthRepository(ref.watch(supabaseClientProvider));
});

final localDemoModeProvider = StateProvider<bool>((ref) => false);

class AuthActionState {
  final bool loading;
  final String? message;
  final bool error;
  const AuthActionState({this.loading = false, this.message, this.error = false});
}

class AuthController extends StateNotifier<AuthActionState> {
  final SupabaseAuthRepository _repository;
  AuthController(this._repository) : super(const AuthActionState());

  Future<bool> signIn(String email, String password) async {
    state = const AuthActionState(loading: true);
    try {
      await _repository.signIn(email: email, password: password);
      state = const AuthActionState();
      return true;
    } catch (error) {
      state = AuthActionState(message: _friendly(error), error: true);
      return false;
    }
  }

  Future<bool> signUp(String name, String email, String password) async {
    state = const AuthActionState(loading: true);
    try {
      final response = await _repository.signUp(email: email, password: password, displayName: name);
      if (response.session == null) {
        state = const AuthActionState(message: 'Kontoen er opprettet. Bekreft e-posten før du logger inn.');
        return false;
      }
      state = const AuthActionState();
      return true;
    } catch (error) {
      state = AuthActionState(message: _friendly(error), error: true);
      return false;
    }
  }

  Future<void> resetPassword(String email) async {
    state = const AuthActionState(loading: true);
    try {
      await _repository.sendPasswordReset(email);
      state = const AuthActionState(message: 'Hvis adressen finnes, er lenke for nytt passord sendt.');
    } catch (error) {
      state = AuthActionState(message: _friendly(error), error: true);
    }
  }

  void clearMessage() => state = const AuthActionState();

  String _friendly(Object error) {
    final text = error.toString();
    if (text.contains('Invalid login credentials')) return 'Feil e-post eller passord.';
    if (text.contains('Email not confirmed')) return 'E-postadressen er ikke bekreftet ennå.';
    if (text.contains('User already registered')) return 'Det finnes allerede en konto med denne e-postadressen.';
    return 'Kunne ikke fullføre handlingen. $text';
  }
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthActionState>((ref) {
  return AuthController(ref.watch(authRepositoryProvider));
});

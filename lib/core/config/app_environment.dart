/// Compile-time runtime configuration for WayCrew.
///
/// Release builds default to production-safe behaviour. Development-only
/// features must be enabled explicitly with --dart-define.
abstract final class AppEnvironment {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://idplsgwzcpjyyboizgig.supabase.co',
  );

  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_A_LbBwcScbOngb5mznk42A__YVpxPvY',
  );

  static const environment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'production',
  );

  static const supabaseDebug = bool.fromEnvironment(
    'SUPABASE_DEBUG',
    defaultValue: false,
  );

  static bool get isDevelopment => environment == 'development';
}

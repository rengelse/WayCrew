/// Runtime configuration for the development Supabase project.
///
/// The publishable key is intentionally client-safe. Production/staging values
/// should be supplied with --dart-define when those environments are created.
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
    defaultValue: 'development',
  );

  static bool get isDevelopment => environment == 'development';
}

import 'package:flutter_test/flutter_test.dart';
import 'package:activity_network/core/config/app_environment.dart';

void main() {
  test('development Supabase configuration is present', () {
    expect(AppEnvironment.supabaseUrl, startsWith('https://'));
    expect(AppEnvironment.supabaseUrl, contains('.supabase.co'));
    expect(AppEnvironment.supabasePublishableKey, startsWith('sb_publishable_'));
  });
}

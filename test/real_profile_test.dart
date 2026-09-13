import 'package:flutter_test/flutter_test.dart';
import 'package:activity_network/data/supabase/supabase_profile_repository.dart';
import 'package:activity_network/domain/models/activity_models.dart';

void main() {
  test('activity kind storage ids map to app enum', () {
    expect(activityKindFromStorage('motorcycle'), ActivityKind.motorcycle);
    expect(activityKindFromStorage('ski'), ActivityKind.ski);
    expect(activityKindFromStorage('unknown'), isNull);
  });

  test('experience labels normalize to database levels', () {
    expect(experienceLevelStorage('Nybegynner'), 'beginner');
    expect(experienceLevelStorage('Litt erfaring'), 'some_experience');
    expect(experienceLevelStorage('Erfaren'), 'experienced');
    expect(experienceLevelStorage('Svært erfaren'), 'very_experienced');
  });
}

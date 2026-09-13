import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('GitHub update service targets WayCrew releases', () {
    final source = File('lib/core/update/app_update_service.dart').readAsStringSync();
    expect(source, contains("static const _owner = 'rengelse'"));
    expect(source, contains("static const _repository = 'WayCrew'"));
    expect(source, contains('/releases/latest'));
    expect(source, contains("name.endsWith('.apk')"));
    final installer = File('lib/core/update/app_update_installer.dart').readAsStringSync();
    expect(installer, contains('OtaUpdate()'));
    expect(installer, contains('destinationFilename'));
    expect(installer, contains('LinearProgressIndicator'));
  });

  test('Android host enables in-app APK installation', () {
    final source = File('tool/prepare_android_ci.py').readAsStringSync();
    expect(source, contains('android.permission.REQUEST_INSTALL_PACKAGES'));
    expect(source, contains('OtaUpdateFileProvider'));
    expect(source, contains('filepaths.xml'));
    expect(source, contains('isCoreLibraryDesugaringEnabled = true'));
  });

  test('release workflow builds release APK only', () {
    final source = File('.github/workflows/android-release.yml').readAsStringSync();
    expect(source, contains('flutter build apk --release'));
    expect(source, isNot(contains('flutter build apk --debug')));
    expect(source, contains('Configure release signing'));
  });
}

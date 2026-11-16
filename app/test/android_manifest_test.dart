import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Release builds only use the main manifest; the INTERNET permission in the
/// debug and profile manifests hides a missing one there (issue #141).
void main() {
  test('the main Android manifest declares the INTERNET permission', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    expect(
      manifest,
      contains('<uses-permission android:name="android.permission.INTERNET"/>'),
    );
  });
}

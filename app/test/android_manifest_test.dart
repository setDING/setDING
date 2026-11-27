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

  // Plain HTTP only in debug builds and only to the development machine,
  // for the integration tests (docs/development/android-tests.md, #647).
  test('release builds allow no plain HTTP', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    expect(manifest, isNot(contains('usesCleartextTraffic')));
    expect(manifest, isNot(contains('networkSecurityConfig')));
    expect(
      File('android/app/src/main/res/xml/network_security_config.xml')
          .existsSync(),
      isFalse,
    );
  });

  test('debug builds allow plain HTTP to local addresses only', () {
    final config = File(
      'android/app/src/debug/res/xml/network_security_config.xml',
    ).readAsStringSync();
    expect(config, isNot(contains('base-config')));
    final domains = RegExp(r'<domain[^>]*>([^<]+)</domain>')
        .allMatches(config)
        .map((m) => m.group(1))
        .toSet();
    expect(domains, {'127.0.0.1', 'localhost', '10.0.2.2'});
    expect(config, isNot(contains('includeSubdomains="true"')));
  });
  // A Bluetooth page turner registers as a keyboard with arrow keys:
  // connecting or disconnecting it changes `keyboard`, `keyboardHidden` and
  // `navigation`. An unhandled one recreates the activity, which restarts the
  // app in live mode (issue #681).
  test('connecting a page turner does not recreate the activity', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    final changes = RegExp(r'android:configChanges="([^"]+)"')
        .firstMatch(manifest)!
        .group(1)!
        .split('|');
    expect(changes, containsAll(['keyboard', 'keyboardHidden', 'navigation']));
  });

  test('every theme disables the system focus frame', () {
    final styles = Directory('android/app/src/main/res')
        .listSync()
        .whereType<Directory>()
        .map((d) => File('${d.path}/styles.xml'))
        .where((f) => f.existsSync())
        .toList();
    expect(styles, isNotEmpty);
    for (final file in styles) {
      final xml = file.readAsStringSync();
      final themes = RegExp(r'<style\b').allMatches(xml).length;
      final disabled = RegExp(
        r'<item name="android:defaultFocusHighlightEnabled">false</item>',
      ).allMatches(xml).length;
      expect(disabled, themes, reason: file.path);
    }
  });

  test('links to sets and songs open the app (ADR-0065)', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    // App Links on the web client's host, verified like the invitations.
    final filter = RegExp(
      r'<intent-filter android:autoVerify="true">(?:(?!</intent-filter>).)*'
      r'android:host="app\.setding\.app"(?:(?!</intent-filter>).)*'
      r'</intent-filter>',
      dotAll: true,
    ).firstMatch(manifest)?.group(0);
    expect(filter, isNotNull);
    for (final prefix in ['/sets/', '/songs/', '/invite/']) {
      expect(filter, contains('android:pathPrefix="$prefix"'));
    }
    for (final host in ['invite', 'sets', 'songs']) {
      expect(
        manifest,
        contains('android:scheme="setding" android:host="$host"'),
      );
    }
  });
}

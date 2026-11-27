import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// setding:// links on Windows (ADR-0005, ADR-0065, #1115): the installer
/// registers the scheme for the user, and a second start with a link hands
/// it to the running app. Not testable on the Linux CI machine itself, so
/// the configuration is checked here.
void main() {
  test('the installer registers setding:// for the app', () {
    final iss = File('windows/installer/setding.iss').readAsStringSync();
    const key = r'Software\Classes\setding';
    expect(iss, contains('[Registry]'));
    expect(
      iss,
      contains(
        'Root: HKA; Subkey: "$key"; ValueType: string; ValueName: "URL Protocol"',
      ),
    );
    expect(
      iss,
      contains(
        r'Subkey: "Software\Classes\setding\shell\open\command"; '
        r'ValueType: string; ValueName: ""; '
        r'ValueData: """{app}\setding.exe"" ""%1"""',
      ),
    );
    // Removed with the app.
    expect(
      RegExp(
        r'Subkey: "Software\\Classes\\setding";[^\n]*Flags: uninsdeletekey',
      ).hasMatch(iss),
      isTrue,
    );
  });

  test('a link reaches the running app instead of a second one', () {
    final main = File('windows/runner/main.cpp').readAsStringSync();
    expect(main, contains('#include "app_links/app_links_plugin_c_api.h"'));
    final forward = main.indexOf('SendAppLinkToInstance()');
    expect(forward, greaterThan(0));
    // Before the window of a second instance is created.
    expect(forward, lessThan(main.indexOf('window.Create(')));
  });
}

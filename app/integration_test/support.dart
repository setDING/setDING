// Helpers of the Android integration tests (make android-test,
// docs/development/android-tests.md).
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps frames until [finder] finds something, for work that runs on the
/// real platform (database, files, network) and does not settle on its own.
Future<void> pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final end = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty) {
    if (DateTime.now().isAfter(end)) {
      throw TestFailure('Timed out after $timeout waiting for $finder');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Types [text] into the text field [field]. `enterText` needs the test
/// text input, which the web binding does not use (the browser's own input
/// is active): the field's controller is set instead.
Future<void> fillIn(WidgetTester tester, Finder field, String text) async {
  final editable = find.descendant(
    of: field,
    matching: find.byType(EditableText),
  );
  tester.widget<EditableText>(editable).controller.text = text;
  await tester.pump();
}

/// Pumps frames for [duration] (animations, platform callbacks).
Future<void> pumpFor(WidgetTester tester, Duration duration) async {
  final end = DateTime.now().add(duration);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// A PDF with [pages] empty pages (300 x 400 pt), rendered by the platform's
/// PDF engine in the tests.
Uint8List pdfWith(int pages) {
  final kids = [for (var i = 0; i < pages; i++) '${i + 3} 0 R'].join(' ');
  final objects = [
    for (var i = 0; i < pages; i++)
      '${i + 3} 0 obj<</Type/Page/Parent 2 0 R/MediaBox[0 0 300 400]>>endobj',
  ].join('\n');
  return utf8.encode('''%PDF-1.1
1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj
2 0 obj<</Type/Pages/Kids[$kids]/Count $pages>>endobj
$objects
trailer<</Root 1 0 R>>
%%EOF
''');
}

/// Whether the runner fires the links of [openLink] (make android-test).
const linksFromRunner = bool.fromEnvironment('SETDING_ITEST_LINKS');

/// Asks the runner of make android-test to open [link] on the device as a
/// link from outside the app (`adb shell am start -a VIEW -d <link>`), as a
/// chat or the browser would. The request goes through the device's log,
/// which tool/android-test.sh watches; the root zone's print bypasses the
/// test's own print capture and reaches the log.
void openLink(String link) {
  Zone.root.print('setding-itest-open-link: $link');
}

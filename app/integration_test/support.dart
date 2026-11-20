// Helpers of the Android integration tests (make android-test,
// docs/development/android-tests.md).
import 'dart:convert';
import 'dart:typed_data';

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

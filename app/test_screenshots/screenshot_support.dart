// Shared setup of the screenshot tests (`*_screenshots_test.dart`).
// Run: make screenshots   (output in build/screenshots/), or
//      make screenshots ONLY="<test name regex>"   (only the matching tests)
//
// The tests are split into several files so `flutter test` runs them in
// parallel. The files are only written with --dart-define=WRITE_SCREENSHOTS=true
// (set by `make screenshots`). Without it, as in the test gate
// (tool/check.sh), the screens are still built, driven, laid out and painted,
// so a UI change that breaks the screenshots fails `make check`; only the
// rasterising and PNG encoding of the images is skipped.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setding/update/whats_new.dart' show whatsNewAsset;

const _write = bool.fromEnvironment('WRITE_SCREENSHOTS');

/// The Material fonts of the Flutter SDK running the test: the test runs in
/// `<sdk>/bin/cache/artifacts/engine/<platform>/flutter_tester`.
String get _materialFonts =>
    '${File(Platform.resolvedExecutable).parent.parent.parent.path}'
    '/material_fonts';

Future<void> _loadFonts() async {
  final dir = _materialFonts;
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      final bytes = File('$dir/$f').readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }

  await load('Roboto', [
    'Roboto-Regular.ttf',
    'Roboto-Bold.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Italic.ttf',
  ]);
  await load('MaterialIcons', ['MaterialIcons-Regular.otf']);
  // Wordmark of the logo (registered in pubspec.yaml).
  final noto = FontLoader('NotoSans')
    ..addFont(
      Future.value(
        ByteData.sublistView(
          File('assets/fonts/NotoSans-Bold.ttf').readAsBytesSync(),
        ),
      ),
    );
  await noto.load();
  // A system font with the flat and sharp signs of chords (#915), if
  // available; registered under a name the chord fallback lists.
  for (final (family, file) in [
    ('Noto Sans Symbols', '/usr/share/fonts/noto/NotoSansSymbols-Regular.ttf'),
    ('DejaVu Sans', '/usr/share/fonts/TTF/DejaVuSans.ttf'),
  ]) {
    if (!File(file).existsSync()) continue;
    final loader = FontLoader(family)
      ..addFont(
        Future.value(ByteData.sublistView(File(file).readAsBytesSync())),
      );
    await loader.load();
  }
  // A system monospace font for tabs and sources, if available.
  const mono = '/usr/share/fonts/TTF/DejaVuSansMono.ttf';
  if (File(mono).existsSync()) {
    final loader = FontLoader('monospace')
      ..addFont(
        Future.value(ByteData.sublistView(File(mono).readAsBytesSync())),
      );
    await loader.load();
  }
}

/// Settles the screen and, with WRITE_SCREENSHOTS, writes it to
/// `build/screenshots/<name>.png`. Without it (the test gate), the screen is
/// laid out and painted by the pump, but not rasterised and PNG-encoded,
/// which made up most of the time of these tests.
///
/// The image has the logical size of the view times [pixelRatio]; pass the
/// view's device pixel ratio for an image in physical pixels.
Future<void> shot(
  WidgetTester tester,
  String name, {
  double pixelRatio = 1,
}) async {
  await tester.pumpAndSettle();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byType(RepaintBoundary).first,
  );
  expect(boundary.debugNeedsPaint, isFalse);
  if (!_write) return;
  final image = await tester.runAsync(
    () => boundary.toImage(pixelRatio: pixelRatio),
  );
  final bytes = await tester.runAsync(
    () => image!.toByteData(format: ui.ImageByteFormat.png),
  );
  expect(bytes!.lengthInBytes, greaterThan(0));
  Directory('build/screenshots').createSync(recursive: true);
  File('build/screenshots/$name.png')
      .writeAsBytesSync(bytes.buffer.asUint8List());
}

/// A screenshot test that renders real elevation shadows.
///
/// Flutter tests disable shadows (`debugDisableShadows`), which paints them as
/// thick black outlines; the screenshots should look like the real app. The
/// flag is restored before the test ends, as the framework checks it.
void screenshotTest(String description, WidgetTesterCallback body) {
  testWidgets(description, (tester) async {
    final disabled = debugDisableShadows;
    debugDisableShadows = false;
    try {
      await body(tester);
    } finally {
      debugDisableShadows = disabled;
    }
  });
}

/// Loads the real fonts once per test file, and the "What's new" notes:
/// without loading them first, whether the "What's new" button was in a
/// screenshot depended on how fast the asset loaded, so the images changed
/// from run to run.
void setUpScreenshots() => setUpAll(() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await _loadFonts();
  await rootBundle.loadString(whatsNewAsset);
});

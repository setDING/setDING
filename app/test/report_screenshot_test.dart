import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/data/annotation.dart';
import 'package:setding/data/song_review.dart';
import 'package:setding/ui/annotations/annotation_placement.dart';
import 'package:setding/ui/songs/report_screenshot.dart';

import 'test_app.dart';

const _pngSignature = [0x89, 0x50, 0x4E, 0x47];

Future<ui.Image> _image(int width, int height, {bool noise = false}) {
  final random = math.Random(1);
  final pixels = Uint8List(width * height * 4);
  for (var i = 0; i < pixels.length; i += 4) {
    final v = noise ? random.nextInt(256) : 255;
    pixels[i] = v;
    pixels[i + 1] = noise ? random.nextInt(256) : 255;
    pixels[i + 2] = noise ? random.nextInt(256) : 255;
    pixels[i + 3] = 255;
  }
  final done = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    pixels,
    width,
    height,
    ui.PixelFormat.rgba8888,
    done.complete,
  );
  return done.future;
}

Future<(int, int)> _size(Uint8List png) async {
  final codec = await ui.instantiateImageCodec(png);
  final frame = await codec.getNextFrame();
  return (frame.image.width, frame.image.height);
}

/// The screenshot of a mistake report (ADR-0060, #991): taken from the
/// view, marked, stored as a PNG of at most 1 MB.
void main() {
  testWidgets('a marked screenshot is a PNG of the same size', (tester) async {
    await tester.runAsync(() async {
      final image = await _image(400, 300);
      final png = await encodeScreenshot(image, [
        PlacedStroke(
          stroke: const AnnotationStroke(
            id: '1',
            tool: AnnotationTool.pen,
            width: 0,
            points: [],
          ),
          points: const [Offset(10, 10), Offset(200, 150)],
          width: 4,
        ),
      ]);
      expect(png.sublist(0, 4), _pngSignature);
      expect(await _size(png), (400, 300));
      // The pen is drawn into the image: not plain white any more.
      final white = await encodeScreenshot(image, const []);
      expect(png.length, isNot(white.length));
    });
  });

  testWidgets('a screenshot too large for 1 MB is scaled down', (tester) async {
    await tester.runAsync(() async {
      final image = await _image(1200, 1200, noise: true);
      final png = await encodeScreenshot(image, const []);
      expect(png.length, lessThanOrEqualTo(maxScreenshotBytes));
      final (w, h) = await _size(png);
      expect(w, lessThan(1200));
      expect(w, h);
    });
  });

  testWidgets('a report from the song view carries a marked screenshot, '
      'shown in the reports panel', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    await tester.runAsync(
      () => app.songs.createSong(source: '{title: Song}\n[G]Hello'),
    );
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Songs').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Song'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('song-report')));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('report-sheet')), findsOneWidget);

    await tester.tap(find.byKey(const Key('report-screenshot-add')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('screenshot-marking')), findsOneWidget);
    final canvas = find.byKey(const Key('screenshot-canvas'));
    await tester.drag(canvas, const Offset(80, 40));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('screenshot-done')));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('report-screenshot-preview')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('report-category-chords')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('report-send')));
    // The screenshot file and the report are written for real.
    for (var i = 0; i < 60; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();

    final row = (await tester.runAsync(
      () => app.db.select(app.db.songReports).getSingle(),
    ))!;
    expect(row.screenshotFile, endsWith('.png'));
    final bytes = (await tester.runAsync(
      () => app.storage.file(row.screenshotFile!).readAsBytes(),
    ))!;
    expect(bytes.sublist(0, 4), _pngSignature);
    expect(bytes.length, lessThanOrEqualTo(maxScreenshotBytes));

    await tester.tap(find.byKey(const Key('open-song-reports')));
    // The thumbnail reads the file for real.
    for (var i = 0; i < 60; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('report-screenshot')), findsOneWidget);
    await app.dispose(tester);
  });
}

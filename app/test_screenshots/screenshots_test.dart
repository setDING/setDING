// Renders screenshots with real fonts for visual review.
// Run: flutter test test_screenshots   (output in build/screenshots/)
import 'dart:io';
import 'dart:ui' as ui;

import 'package:bandchords/data/database.dart';
import 'package:bandchords/data/demo_song.dart';
import 'package:bandchords/ui/live/live_screen.dart';
import 'package:bandchords/ui/songs/song_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import '../test/test_app.dart';

Future<void> _loadFonts() async {
  final dir =
      '${Platform.environment['HOME']}/development/flutter/bin/cache/artifacts/material_fonts';
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
}

Future<void> _shot(WidgetTester tester, String name) async {
  await tester.pumpAndSettle();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byType(RepaintBoundary).first,
  );
  final image = await tester.runAsync(() => boundary.toImage());
  final bytes = await tester.runAsync(
    () => image!.toByteData(format: ui.ImageByteFormat.png),
  );
  Directory('build/screenshots').createSync(recursive: true);
  File('build/screenshots/$name.png')
      .writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  setUpAll(() async => _loadFonts());

  for (final (lang, dark) in [('de', false), ('en', true)]) {
    testWidgets('screenshots $lang', (tester) async {
      useTabletSize(tester);
      final app = await TestApp.create(
        prefs: {'language': lang, 'themeMode': dark ? 'dark' : 'light'},
      );
      final ids = await tester.runAsync(() async {
        final a = await app.songs.createSong(source: demoSongSource);
        final b = await app.songs.createSong(
          source: '{title: Blue Monday Groove}\n{artist: House Band}\n{key: Bb}\n[Bb7]Blues [Eb7]line\n',
        );
        await app.songs.saveOverlay(
          (await app.songs.getOverlay(
            a,
          )).copyWith(notes: const Value('Count in 4, ritardando at the end')),
        );
        final setId = await app.sets.createSet(
          name: 'Summer Festival',
          venue: 'Bern',
          gigDate: DateTime(2027, 6, 21),
        );
        await app.sets.addSongs(setId, [a, b]);
        await app.sets.addMarker(
          setId,
          SetItemType.pause,
          lang == 'de' ? 'Pause' : 'Break',
        );
        return [a, setId];
      });

      await tester.pumpWidget(
        RepaintBoundary(key: UniqueKey(), child: app.build()),
      );
      await _shot(tester, '${lang}_1_sets');
      await tester.tap(find.text('Summer Festival'));
      await _shot(tester, '${lang}_2_set');

      await tester.pumpWidget(
        RepaintBoundary(
          key: UniqueKey(),
          child: app.build(home: SongScreen(songId: ids![0])),
        ),
      );
      await _shot(tester, '${lang}_3_song');

      final items = await tester.runAsync(
        () async => [
          for (final v in await app.sets.getItems(ids[1]))
            v.song == null
                ? LiveItem.marker(v.item.type, v.item.note)
                : LiveItem.song(v.song!),
        ],
      );
      await tester.pumpWidget(
        RepaintBoundary(
          key: UniqueKey(),
          child: app.build(home: LiveScreen(items: items!)),
        ),
      );
      await _shot(tester, '${lang}_4_live');
      tester.view.physicalSize = const Size(800, 1280);
      await tester.pumpWidget(
        RepaintBoundary(
          key: UniqueKey(),
          child: app.build(home: LiveScreen(items: items)),
        ),
      );
      await _shot(tester, '${lang}_5_live_portrait');
      await app.dispose(tester);
    });
  }
}

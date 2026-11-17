// Performance scenarios on a real device (issue #270), run with `make perf`
// (flutter drive --profile, docs/development/performance.md).
//
// Seeds a large local library on the first run (songs, a set of 30 songs
// with PDF sheet music) and records timelines of the stage-relevant paths:
// song list scrolling and search, live mode page turns in portrait and
// landscape, and typing in the editor. The driver
// (test_driver/perf_driver.dart) writes the summaries to build/perf/.
//
// Runs in the app's own data directory: never run it on a device that has
// a RealChord installation with real data.
import 'dart:io';
import 'dart:math';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:realchord/app.dart';
import 'package:realchord/bootstrap/platform_services.dart';
import 'package:realchord/data/attachment_storage.dart';
import 'package:realchord/data/database.dart';
import 'package:realchord/data/set_repository.dart';
import 'package:realchord/data/song_repository.dart';
import 'package:realchord/providers.dart';
import 'package:realchord/settings/settings.dart';
import 'package:realchord/sync/auth_providers.dart';
import 'package:realchord/ui/home_screen.dart';
import 'package:realchord/ui/live/live_screen.dart';
import 'package:realchord/ui/songs/song_editor_screen.dart';
import 'package:realchord/ui/songs/songs_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Songs in the library; the set uses the first ones.
const _librarySize = 400;
const _setSize = 30;
const _seedKey = 'perfSeeded';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  final memory = <String, Object>{};

  void recordMemory(String step) => memory[step] = {
    'rssMb': ProcessInfo.currentRss ~/ (1024 * 1024),
    'maxRssMb': ProcessInfo.maxRss ~/ (1024 * 1024),
  };

  testWidgets(
    'performance scenarios',
    (tester) async {
      final services = await openPlatformServices();
      final prefs = await SharedPreferences.getInstance();
      // No demo song and no sync: only the seeded data is measured.
      await prefs.setBool('demoSeeded', true);
      final seed = await _seed(services.db, services.storage, prefs);
      recordMemory('afterSeed');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            databaseProvider.overrideWithValue(services.db),
            attachmentStorageProvider.overrideWithValue(services.storage),
            sessionStoreProvider.overrideWithValue(services.sessionStore),
          ],
          child: const RealChordApp(),
        ),
      );
      await _settle(tester);
      recordMemory('start');

      // The song list and the search in portrait (one column on a tablet),
      // whatever position the device was left in: in landscape, the
      // keyboard did not resize the app on the test tablet, so the frames
      // while it opens were not measured (#297).
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
      await tester.pump(const Duration(seconds: 2));
      await _settle(tester);

      // Song list: scroll through the library.
      await tester.tap(find.byIcon(Icons.library_music_outlined));
      await _settle(tester);
      final list = find
          .descendant(
            of: find.byType(SongsScreen),
            matching: find.byType(Scrollable),
          )
          .first;
      // A fling has many frames: four per part.
      await _trace(binding, 'song_list_scroll', 12, perPart: 4, (i) async {
        // Six flings down, then six up.
        final down = i < 6;
        await tester.fling(list, Offset(0, down ? -1200 : 1200), 4000);
        await _settle(tester);
      });
      recordMemory('songList');

      // Search: typed letter by letter, then cleared.
      final field = find.descendant(
        of: find.byType(SearchBar),
        matching: find.byType(EditableText),
      );
      const queries = ['night', 'train home', 'zz', 'love'];
      await _trace(binding, 'song_search', queries.length, (i) async {
        final query = queries[i];
        for (var n = 1; n <= query.length; n++) {
          await tester.enterText(field, query.substring(0, n));
          await tester.pump(const Duration(milliseconds: 120));
        }
        await tester.pump(const Duration(milliseconds: 600));
        await tester.enterText(field, '');
        await tester.pump(const Duration(milliseconds: 600));
      });
      recordMemory('search');

      final context = tester.element(find.byType(HomeScreen));

      // Live mode in portrait and landscape: every page of the whole set.
      for (final (name, orientations) in [
        ('live_portrait', [DeviceOrientation.portraitUp]),
        ('live_landscape', [DeviceOrientation.landscapeLeft]),
      ]) {
        await SystemChrome.setPreferredOrientations(orientations);
        await tester.pump(const Duration(seconds: 2));
        await _settle(tester);
        unawaited(LiveScreen.openSet(context, seed.setId));
        await tester.pump(const Duration(seconds: 2));
        await _settle(tester);
        await _trace(binding, name, _setSize * 3, (i) async {
          await _press(
            tester,
            LogicalKeyboardKey.arrowRight,
            PhysicalKeyboardKey.arrowRight,
          );
          // Room for the PDF renderer, which works in the background.
          await tester.pump(const Duration(milliseconds: 400));
          await _settle(tester);
        });
        recordMemory(name);
        await _press(
          tester,
          LogicalKeyboardKey.escape,
          PhysicalKeyboardKey.escape,
        );
        await _settle(tester);
      }
      await SystemChrome.setPreferredOrientations([]);

      // Editor: typing into a long song with the live preview.
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SongEditorScreen(songId: seed.longSongId),
        ),
      );
      await _settle(tester);
      final editor = find.byType(EditableText).first;
      await tester.tap(editor);
      await _settle(tester);
      final start = tester.widget<EditableText>(editor).controller.text;
      var text = start;
      final typed = '\n[G]typing a new [D]line of [Em]lyrics'.split('');
      await _trace(binding, 'editor_typing', typed.length + 1, (i) async {
        if (i == typed.length) return _settle(tester);
        text += typed[i];
        tester.testTextInput.updateEditingValue(
          TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
          ),
        );
        await tester.pump(const Duration(milliseconds: 80));
      });
      recordMemory('editor');

      binding.reportData = {...?binding.reportData, 'memory': memory};
    },
    timeout: const Timeout(Duration(minutes: 20)),
    // Semantics only run with an accessibility service (e.g. TalkBack);
    // the test default would add their cost to every frame.
    semanticsEnabled: false,
  );
}

/// Timeline streams for the frame summaries: frames, build/layout events and
/// the markers of the app, garbage collection. Not 'all': the API stream alone
/// would fill half of the VM's timeline buffer.
const _streams = ['Dart', 'Embedder', 'GC'];

/// Runs [count] steps of a scenario and records their timeline as [key].
///
/// The VM keeps the timeline in a ring buffer (about 32,000 events), so
/// scenarios are recorded in parts of [perPart] steps, reported as `key#1`,
/// `key#2`, …, which the driver joins again (test_driver/perf_driver.dart);
/// otherwise only the end of a long scenario would be measured.
Future<void> _trace(
  IntegrationTestWidgetsFlutterBinding binding,
  String key,
  int count,
  Future<void> Function(int step) step, {
  int perPart = 10,
}) async {
  for (var start = 0, part = 1; start < count; start += perPart, part++) {
    await binding.traceAction(
      () async {
        for (var i = start; i < min(start + perPart, count); i++) {
          await step(i);
        }
      },
      streams: _streams,
      reportKey: '$key#$part',
    );
  }
}

/// A key press as a page turner sends it; the physical key is given because
/// the simulator has no Android mapping for every logical key.
Future<void> _press(
  WidgetTester tester,
  LogicalKeyboardKey key,
  PhysicalKeyboardKey physical,
) async {
  await tester.sendKeyDownEvent(key, physicalKey: physical);
  await tester.sendKeyUpEvent(key, physicalKey: physical);
}

/// [WidgetTester.pumpAndSettle] that tolerates endless animations
/// (progress indicators) instead of failing.
Future<void> _settle(WidgetTester tester) async {
  try {
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 10),
    );
  } on FlutterError {
    await tester.pump(const Duration(milliseconds: 500));
  }
}

typedef _Seed = ({String setId, String longSongId});

Future<_Seed> _seed(
  AppDatabase db,
  AttachmentStorage storage,
  SharedPreferences prefs,
) async {
  final songs = SongRepository(db, storage);
  final sets = SetRepository(db, storage);
  final stored = prefs.getStringList(_seedKey);
  if (stored != null) return (setId: stored[0], longSongId: stored[1]);

  final random = Random(270);
  final ids = <String>[];
  for (var i = 0; i < _librarySize; i++) {
    final long = i % 10 == 3;
    ids.add(await songs.createSong(source: _songSource(random, i, long: long)));
  }
  // Sheet music: a large scanned-looking PDF (close to the 20 MB limit)
  // and a small one, as PDF-only songs in the set.
  final bigPdf = await songs.createSong(title: 'Scanned Sheet Music');
  await songs.addAttachment(
    bigPdf,
    name: 'scan.pdf',
    bytes: await _scannedPdf(random, maxBytes: maxAttachmentBytes),
  );
  final smallPdf = await songs.createSong(title: 'Lead Sheet');
  await songs.addAttachment(
    smallPdf,
    name: 'lead.pdf',
    bytes: await _scannedPdf(random, pages: 2, maxBytes: 3 * 1024 * 1024),
  );

  final setIds = [...ids.take(_setSize - 2)];
  setIds.insert(9, bigPdf);
  setIds.insert(19, smallPdf);
  final setId = await sets.createSet(
    name: 'Performance Test',
    gigDate: DateTime.now().add(const Duration(days: 1)),
    venue: 'Device',
  );
  await sets.addSongs(setId, setIds);
  final longSongId = ids[3];
  await prefs.setStringList(_seedKey, [setId, longSongId]);
  return (setId: setId, longSongId: longSongId);
}

const _words = [
  'night',
  'train',
  'home',
  'river',
  'light',
  'heart',
  'road',
  'love',
  'morning',
  'city',
  'rain',
  'fire',
  'song',
  'dream',
  'dance',
  'star',
  'summer',
  'winter',
  'shadow',
  'golden',
  'wild',
  'blue',
  'open',
  'sky',
];
const _chords = ['G', 'D', 'Em', 'C', 'Am', 'F', 'Bm', 'A7', 'D/F#', 'Esus4'];
const _keys = ['G', 'D', 'A', 'E', 'C', 'F', 'Bb', 'Am', 'Em'];

String _songSource(Random random, int index, {required bool long}) {
  String word() => _words[random.nextInt(_words.length)];
  String line() {
    final buffer = StringBuffer();
    for (var w = 0; w < 6 + random.nextInt(4); w++) {
      if (w % 2 == 0) {
        buffer.write('[${_chords[random.nextInt(_chords.length)]}]');
      }
      buffer.write('${word()} ');
    }
    return buffer.toString().trimRight();
  }

  String section(String kind, String label, int lines) => [
    '{start_of_$kind: $label}',
    for (var l = 0; l < lines; l++) line(),
    '{end_of_$kind}',
  ].join('\n');

  final verses = long ? 6 : 3;
  return [
    '{title: ${word()} ${word()} $index}',
    '{artist: ${word()} band}',
    '{key: ${_keys[index % _keys.length]}}',
    '{tempo: ${70 + index % 80}}',
    for (var v = 1; v <= verses; v++) ...[
      section('verse', 'Verse $v', long ? 6 : 4),
      if (v == 1) section('chorus', 'Chorus', 4) else '{chorus}',
    ],
    if (long) section('bridge', 'Bridge', 4),
    '{chorus}',
  ].join('\n\n');
}

/// A PDF of grey noise pages, which compress badly like scans, below
/// [maxBytes].
Future<Uint8List> _scannedPdf(
  Random random, {
  int pages = 6,
  required int maxBytes,
}) async {
  const width = 1240, height = 1754; // A4 at 150 dpi
  while (true) {
    final doc = pw.Document();
    for (var p = 0; p < pages; p++) {
      final rgba = Uint8List(width * height * 4);
      for (var i = 0; i < rgba.length; i += 4) {
        final v = 200 + random.nextInt(56);
        rgba[i] = v;
        rgba[i + 1] = v;
        rgba[i + 2] = v;
        rgba[i + 3] = 255;
      }
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Image(
            pw.RawImage(bytes: rgba, width: width, height: height),
            fit: pw.BoxFit.fill,
          ),
        ),
      );
    }
    final bytes = await doc.save();
    if (bytes.length <= maxBytes || pages == 1) return bytes;
    pages--;
  }
}

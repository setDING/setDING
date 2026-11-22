import 'package:chordpro/chordpro.dart' show Subdivision;
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/data/database.dart';
import 'package:setding/data/song_repository.dart';
import 'package:setding/midi/midi_message.dart';
import 'package:setding/ui/songs/song_screen.dart';

import 'test_app.dart';

/// The offer to copy personal adjustments from another language version
/// (ADR-0053, #808).
void main() {
  final banner = find.byKey(const Key('adjustment-offer'));

  Future<(TestApp, Map<String, String>)> setUpApp(
    WidgetTester tester, {
    bool twoSources = false,
  }) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final ids = (await tester.runAsync(() async {
      final en = await app.songs.createSong(source: '{title: River}\n[D]La');
      final de = await app.songs.createSong(source: '{title: Fluss}\n[D]La');
      final ch = await app.songs.createSong(source: '{title: Flussli}\n[D]La');
      await app.songs.setLanguage(en, 'en');
      await app.songs.setLanguage(de, 'de');
      await app.songs.setLanguage(ch, 'gsw');
      await app.songs.linkLanguageVersions(en, de);
      await app.songs.linkLanguageVersions(en, ch);
      await app.songs.updateOverlay(
        en,
        (o) => o.copyWith(
          transpose: 2,
          capoFret: const Value(3),
          notes: const Value('Mine'),
          fontScale: 1.4,
        ),
      );
      if (twoSources) {
        await app.songs.updateOverlay(
          ch,
          (o) => o.copyWith(clickSubdivision: const Value(Subdivision.eighths)),
        );
      }
      return {'en': en, 'de': de, 'ch': ch};
    }))!;
    return (app, ids);
  }

  Future<void> open(WidgetTester tester, TestApp app, String id) async {
    await tester.pumpWidget(app.build(home: SongScreen(songId: id)));
    await tester.pumpAndSettle();
  }

  group('repository', () {
    testWidgets('only musical adjustments count and are copied', (
      tester,
    ) async {
      final (app, ids) = await setUpApp(tester);
      await tester.runAsync(() async {
        final sources = await app.songs.musicalAdjustmentSources(ids['de']!);
        expect([for (final (s, _) in sources) s.id], [ids['en']]);

        await app.songs.updateOverlay(
          ids['de']!,
          (o) => o.copyWith(notes: const Value('Keep me'), fontScale: 0.8),
        );
        final before = await app.songs.copyMusicalAdjustments(
          from: ids['en']!,
          to: ids['de']!,
        );
        expect(SongRepository.hasMusicalAdjustments(before), isFalse);
        final copied = await app.songs.getOverlay(ids['de']!);
        expect(copied.transpose, 2);
        expect(copied.capoFret, 3);
        // Notes and the font size are not musical: they stay.
        expect(copied.notes, 'Keep me');
        expect(copied.fontScale, 0.8);
      });
      await app.dispose(tester);
    });

    test('keyboard programs and the click are musical', () {
      final none = SongRepository.defaultOverlay('s');
      expect(SongRepository.hasMusicalAdjustments(none), isFalse);
      expect(
        SongRepository.hasMusicalAdjustments(
          none.copyWith(notes: const Value('x'), fontScale: 2),
        ),
        isFalse,
      );
      expect(
        SongRepository.hasMusicalAdjustments(
          none.copyWith(
            midiPrograms: const Value(
              MidiPrograms({'nord': MidiProgram(program: 3)}),
            ),
          ),
        ),
        isTrue,
      );
      expect(
        SongRepository.hasMusicalAdjustments(
          none.copyWith(midi: const Value(MidiProgram(program: 3))),
        ),
        isTrue,
      );
      expect(
        SongRepository.hasMusicalAdjustments(
          none.copyWith(clickGrouping: const Value('3+2+2')),
        ),
        isTrue,
      );
    });
  });

  testWidgets('the offer copies the adjustments, with Undo', (tester) async {
    final (app, ids) = await setUpApp(tester);
    await open(tester, app, ids['de']!);
    expect(banner, findsOneWidget);
    expect(
      find.text(
        'Your adjustments in “English”: key, capo. '
        'Use them for this version too?',
      ),
      findsOneWidget,
    );

    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('adjustment-offer-copy')));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(find.text('Adjustments of “English” used'), findsOneWidget);
    expect(banner, findsNothing);
    var overlay = (await tester.runAsync(
      () => app.songs.getOverlay(ids['de']!),
    ))!;
    expect(overlay.transpose, 2);
    expect(overlay.notes, isNull);

    await tester.runAsync(() async {
      await tester.tap(find.text('Undo'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    overlay = (await tester.runAsync(() => app.songs.getOverlay(ids['de']!)))!;
    expect(overlay.transpose, 0);
    expect(banner, findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('with several sources the person picks one', (tester) async {
    final (app, ids) = await setUpApp(tester, twoSources: true);
    await open(tester, app, ids['de']!);
    expect(
      find.textContaining('Other language versions have your adjustments'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('adjustment-offer-copy')));
    await tester.pumpAndSettle();
    expect(find.text('key, capo'), findsOneWidget);
    expect(find.text('click'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.byKey(ValueKey('adjustment-source-${ids['ch']}')));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    final overlay = (await tester.runAsync(
      () => app.songs.getOverlay(ids['de']!),
    ))!;
    expect(overlay.clickSubdivision, Subdivision.eighths);
    expect(overlay.transpose, 0);
    await app.dispose(tester);
  });

  testWidgets('a dismissed offer does not come back for that song', (
    tester,
  ) async {
    final (app, ids) = await setUpApp(tester);
    await open(tester, app, ids['de']!);
    await tester.tap(find.byKey(const Key('adjustment-offer-dismiss')));
    await tester.pumpAndSettle();
    expect(banner, findsNothing);
    // Not for the song again, but for another version.
    await open(tester, app, ids['de']!);
    expect(banner, findsNothing);
    await open(tester, app, ids['ch']!);
    expect(banner, findsOneWidget);
    expect(
      (await tester.runAsync(() => app.songs.getOverlay(ids['de']!)))!
          .transpose,
      0,
    );
    await app.dispose(tester);
  });

  testWidgets('no offer on the version with the adjustments or without '
      'versions', (tester) async {
    final (app, ids) = await setUpApp(tester);
    await open(tester, app, ids['en']!);
    expect(banner, findsNothing);
    final alone = (await tester.runAsync(
      () => app.songs.createSong(source: '{title: Alone}'),
    ))!;
    await open(tester, app, alone);
    expect(banner, findsNothing);
    await app.dispose(tester);
  });
}

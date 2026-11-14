import 'package:bandchords/data/database.dart';
import 'package:bandchords/ui/sets/set_list_pdf.dart';
import 'package:bandchords/ui/sets/set_list_text.dart';
import 'package:bandchords/ui/sets/set_screen.dart';
import 'package:chordpro/chordpro.dart' as cp;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

void main() {
  Future<(TestApp, String)> createSet(WidgetTester tester) async {
    final app = await TestApp.create(prefs: {'language': 'en'});
    final setId = await tester.runAsync(() async {
      final a = await app.songs.createSong(
        source: '{title: Late Train}\n{key: G}\n{x_sequence: V1, C, V2, C}',
      );
      final b = await app.songs.createSong(source: '{title: Blues}\n{key: Bb}');
      final c = await app.songs.createSong(source: '{title: No Key}');
      final h = await app.songs.createSong(source: '{title: Hm}\n{key: Bm}');
      final setId = await app.sets.createSet(
        name: 'Summer Festival',
        venue: 'Bern',
        gigDate: DateTime(2027, 6, 21),
      );
      await app.sets.addSongs(setId, [a, b]);
      await app.sets.addMarker(setId, SetItemType.pause, 'Break');
      await app.sets.addSongs(setId, [c, h]);
      final items = await app.sets.getItems(setId);
      // Set-specific key and sequence for the first song, +2 for "No Key".
      await app.sets.setItemTranspose(items[0].item.id, 2);
      await app.sets.setItemSequence(items[0].item.id, 'I, V1, C x2');
      await app.sets.setItemTranspose(items[3].item.id, 2);
      return setId;
    });
    return (app, setId!);
  }

  testWidgets('one line per song with title, set key and sequence', (
    tester,
  ) async {
    final (app, setId) = await createSet(tester);
    final data = await tester.runAsync(
      () async => (
        (await (app.db.select(
          app.db.setlists,
        )..where((s) => s.id.equals(setId))).getSingle()),
        await app.sets.getItems(setId),
      ),
    );
    String text(cp.ChordNotation notation) => setListText(
      buildSetList(
        data!.$1,
        data.$2,
        notation: notation,
        formatDate: (d) => '${d.day}.${d.month}.${d.year}',
        untitled: 'Untitled',
        songMissing: 'Missing',
      ),
    );
    expect(
      text(cp.ChordNotation.international),
      'Summer Festival\n'
      '21.6.2027 · Bern\n'
      '\n'
      '1. Late Train – A – I, V1, C x2\n'
      '2. Blues – Bb\n'
      '— Break —\n'
      '3. No Key – +2\n'
      '4. Hm – Bm\n',
    );
    // The original song is not changed by the set.
    final song = await tester.runAsync(
      () async => (await app.songs.getSong(data!.$2.first.song!.id))!,
    );
    expect(song!.chordproSource, contains('{x_sequence: V1, C, V2, C}'));
    expect(text(cp.ChordNotation.german), contains('4. Hm – Hm\n'));
    await app.dispose(tester);
  });

  testWidgets('copies the set list from the set menu', (tester) async {
    useTabletSize(tester);
    final (app, setId) = await createSet(tester);
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(app.build(home: SetScreen(setId: setId)));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy set list'));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(copied, contains('1. Late Train – A – I, V1, C x2\n'));
    expect(find.text('Set list copied'), findsOneWidget);
    await app.dispose(tester);
  });

  group('PDF', () {
    SetList list(
      int songs, {
      String sequence = 'I, V1, C, V2, PC, C x2, B, O',
    }) => SetList('Summer Festival', '21.6.2027 · Bern', [
      for (var i = 1; i <= songs; i++) ...[
        SetListSong(
          i,
          'Song number $i – Ünïcödé',
          key: 'B♭',
          sequence: sequence,
        ),
        if (i == 3) const SetListMarker('Pause', pause: true),
      ],
    ]);

    testWidgets('fits a typical set on one page in large type', (tester) async {
      final pdf = (await tester.runAsync(() async {
        final fonts = await SetListFonts.load();
        return setListPdf(list(12, sequence: 'V1, C, V2, C'), fonts);
      }))!;
      expect(String.fromCharCodes(pdf.bytes.take(5)), '%PDF-');
      expect(pdf.pages, 1);
      expect(pdf.fontSize, setListMaxFontSize);
    });

    testWidgets('shrinks the font for longer sets', (tester) async {
      final pdf = (await tester.runAsync(() async {
        final fonts = await SetListFonts.load();
        return setListPdf(list(28), fonts);
      }))!;
      expect(pdf.pages, 1);
      expect(pdf.fontSize, lessThan(setListMaxFontSize));
      expect(pdf.fontSize, greaterThanOrEqualTo(setListMinFontSize));
    });

    testWidgets('continues on more pages at the minimum size', (tester) async {
      final pdf = (await tester.runAsync(() async {
        final fonts = await SetListFonts.load();
        return setListPdf(list(80), fonts);
      }))!;
      expect(pdf.fontSize, setListMinFontSize);
      expect(pdf.pages, greaterThan(1));
    });
  });
}

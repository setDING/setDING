import 'package:realchord/ui/live/live_screen.dart';
import 'package:realchord/ui/render/chord_diagram.dart';
import 'package:realchord/ui/render/song_view.dart';
import 'package:realchord/ui/songs/song_screen.dart';
import 'package:chordpro/chordpro.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

DiagramResolver resolver(
  String source, {
  int transpose = 0,
  DiagramInstrument instrument = DiagramInstrument.guitar,
}) {
  final song = parseChordPro(source);
  return DiagramResolver(
    song,
    ChordFormatter.forSong(song, transpose: transpose),
    instrument,
  );
}

void main() {
  group('DiagramResolver', () {
    test('all chords in order, unique, as played', () {
      final r = resolver(
        '[C]a [G]b [C]c\n{start_of_grid}\n| Am . | F . |\n{end_of_grid}',
        transpose: 2,
      );
      expect(r.allChords().map((d) => d.name), ['D', 'A', 'Bm', 'G']);
    });

    test('a {define} is used when the chord is shown as written', () {
      const source =
          '{define: Am base-fret 5 frets 1 3 3 1 1 1}\n{define: Dsus diagram off}\n'
          '[Am]x [Dsus]y';
      final asWritten = resolver(source).allChords();
      expect(asWritten.single.name, 'Am'); // Dsus has "diagram off"
      expect(asWritten.single.shape!.baseFret, 5);
      // Transposed: the definition no longer matches, a fingering is made.
      final transposed = resolver(source, transpose: 2).allChords();
      expect(transposed.first.name, 'Bm');
      expect(transposed.first.shape!.frets, hasLength(6));
    });

    test('copy and display', () {
      final r = resolver(
        '{define: Hm base-fret 2 frets x 1 3 3 2 1}\n'
        '{define: X copy Hm display B minor}\n{chord: X}',
      );
      final line = r.song.sections.single.lines.single as ChordDiagramLine;
      final data = r.forDefinition(line.definition)!;
      expect(data.name, 'B minor');
      expect(data.shape!.baseFret, 2);
    });

    test('ukulele, keyboard and vocals', () {
      expect(
        resolver(
          '[C]x',
          instrument: DiagramInstrument.ukulele,
        ).allChords().single.shape!.frets,
        [0, 0, 0, 3],
      );
      expect(
        resolver(
          '[C]x',
          instrument: DiagramInstrument.keyboard,
        ).allChords().single.keys,
        [60, 64, 67],
      );
      expect(
        resolver('[C]x', instrument: DiagramInstrument.none).allChords(),
        isEmpty,
      );
    });

    test('instrument names map to diagram instruments', () {
      expect(diagramInstrumentFor('guitar'), DiagramInstrument.guitar);
      expect(diagramInstrumentFor('E-Gitarre'), DiagramInstrument.guitar);
      expect(
        diagramInstrumentFor('Bariton-Ukulele'),
        DiagramInstrument.ukulele,
      );
      expect(diagramInstrumentFor('bass'), DiagramInstrument.bass);
      expect(diagramInstrumentFor('Piano'), DiagramInstrument.keyboard);
      expect(diagramInstrumentFor('vocals'), DiagramInstrument.none);
    });

    test('song directive wins over the setting', () {
      expect(
        diagramsPosition(null, DiagramsPosition.off),
        DiagramsPosition.off,
      );
      expect(
        diagramsPosition('on', DiagramsPosition.off),
        DiagramsPosition.bottom,
      );
      expect(
        diagramsPosition('on', DiagramsPosition.top),
        DiagramsPosition.top,
      );
      expect(
        diagramsPosition('off', DiagramsPosition.top),
        DiagramsPosition.off,
      );
      expect(
        diagramsPosition('right', DiagramsPosition.off),
        DiagramsPosition.bottom,
      );
    });
  });

  testWidgets('song screen shows diagrams of all chords when enabled', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(
      prefs: {'language': 'en', 'diagrams': 'bottom'},
    );
    final id = await tester.runAsync(
      () => app.songs.createSong(source: '{title: D}\n[C]one [G]two [Am]three'),
    );
    await tester.pumpWidget(app.build(home: SongScreen(songId: id!)));
    await tester.pumpAndSettle();
    expect(find.byType(ChordDiagramView), findsNWidgets(3));
    await app.dispose(tester);
  });

  testWidgets(
    '{chord} shows an inline diagram, {diagrams: off} hides the list',
    (tester) async {
      useTabletSize(tester);
      final app = await TestApp.create(
        prefs: {'language': 'en', 'diagrams': 'top'},
      );
      final id = await tester.runAsync(
        () => app.songs.createSong(
          source: '{title: D}\n{diagrams: off}\n{chord: Am}\n[C]one [G]two',
        ),
      );
      await tester.pumpWidget(app.build(home: SongScreen(songId: id!)));
      await tester.pumpAndSettle();
      expect(find.byType(ChordDiagramView), findsOneWidget);
      await app.dispose(tester);
    },
  );

  testWidgets('live mode fits a song with diagrams exactly', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(
      prefs: {'language': 'en', 'diagrams': 'bottom'},
    );
    final song = await tester.runAsync(() async {
      final source = StringBuffer('{title: Many}\n');
      for (var i = 0; i < 4; i++) {
        source.writeln('{start_of_verse}');
        source.writeln('[C]one [G/B]two [Am]three [F]four [Dm7]five');
        source.writeln('[E7]six [Bb]seven [Cmaj7]eight [Gsus4]nine');
        source.writeln('{end_of_verse}');
      }
      final id = await app.songs.createSong(source: source.toString());
      return app.songs.getSong(id);
    });
    await tester.pumpWidget(
      app.build(home: LiveScreen(items: [LiveItem.song(song!)])),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ChordDiagramView), findsNWidgets(9));
    expect(find.byType(SingleChildScrollView), findsNothing);
    final body = tester.getSize(find.byType(SongBody));
    final box = tester.getSize(find.byType(FittedBox));
    expect(body.height, lessThanOrEqualTo(box.height));
    await app.dispose(tester);
  });
}

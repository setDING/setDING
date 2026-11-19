import 'dart:io';

import 'package:chordpro/chordpro.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setding/data/demo_song.dart';
import 'package:setding/l10n/generated/app_localizations.dart';
import 'package:setding/settings/song_display.dart';
import 'package:setding/ui/render/chord_diagram.dart';
import 'package:setding/ui/render/song_view.dart';

/// The layout measurement (song_layout.dart) must match the rendered
/// widgets (song_view.dart), or fitting a song to the screen in live mode
/// goes wrong (code review B3). Both use SongSpacing; this test catches a
/// change on one side only.
String describe(SongBlock b) => b.delegate != null
    ? 'delegate ${b.delegate!.type.name}'
    : b.diagrams != null
    ? 'diagrams'
    : b.text != null
    ? 'notes'
    : b.isRecallLabel
    ? 'recall'
    : '${b.label}: ${{for (final l in b.lines) l.runtimeType}.join(',')}';

void main() {
  // Wide enough that no chord line wraps: fitSong chooses the font so that
  // chord lines fit the column, and the measurement relies on that.
  const width = 1400.0;
  const fontSize = 20.0;

  final songs = {
    'demo': demoSongSource,
    'showcase': File('../docs/examples/feature-showcase.cho')
        .readAsStringSync(),
    'sizes':
        '{title: Sizes}\n{textsize: 30}\n{c: A comment}\n[C]Big [G]words\n'
        '{textsize: 12}\n{ci: small comment}\n[Am]small [F]words\n\n'
        '{soc}\n[C]Chorus [G]line\n{eoc}\n{chorus}\n'
        // An empty line inside a section.
        '{sov}\n[C]One\n\n[G]Two\n{eov}\n',
    // Section roles with their own styles in the presets (ADR-0033).
    'roles':
        '{title: Roles}\n{c: Intro}\n[G] [D]\n\n{c: Verse 1}\n[G]One [D]two\n\n'
        '{c: Pre-Chorus}\n[Am]Up we [C]go\n\n{soc: Chorus}\n[C]Sing a [G]long '
        'line that wraps in narrow columns\n{eoc}\n{chorus}\n\n'
        '{c: Solo}\n[Em] [C] [G] [D]\n\n{sob}\n[Am]Bridge\n{eob}\n\n'
        '{start_of_grid label="Intro grid"}\n| G . | D . |\n{end_of_grid}\n\n'
        '{c: Outro}\n[C] [G]\n',
  };
  // Every preset changes labels, bars, indents, tints and chord sizes.
  final displays = [
    for (final p in SongDisplayPreset.values)
      if (p != SongDisplayPreset.custom) SongDisplay.preset(p),
    // The monospace font changes the width of every text.
    const SongDisplay.preset(
      SongDisplayPreset.colorCoded,
      font: SongFont.monospace,
    ),
  ];

  for (final MapEntry(key: name, value: source) in songs.entries) {
    for (final display in displays) {
      testWidgets('measured heights match the rendered blocks: $name, '
          '${display.preset.name}, ${display.font.name}', (tester) async {
        tester.view.physicalSize = const Size(1600, 4000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final song = parseChordPro(source);
        final formatter = ChordFormatter.forSong(song);
        final resolver = DiagramResolver(
          song,
          formatter,
          DiagramInstrument.guitar,
        );
        late List<BlockMetrics> metrics;
        late List<SongBlock> blocks;
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: Material(
              child: SingleChildScrollView(
                child: SizedBox(
                  width: width,
                  child: Builder(
                    builder: (context) {
                      final options = SongRenderOptions(
                        formatter: formatter,
                        fontSize: fontSize,
                        notes:
                            'A personal note that is long enough to wrap '
                            'onto a second line in the card',
                        diagramResolver: resolver,
                        diagramsPosition: DiagramsPosition.bottom,
                        display: display,
                      );
                      blocks = buildSongBlocks(
                        song,
                        lyricsOnly: false,
                        labeler: sectionLabeler(AppLocalizations.of(context)),
                        notes: options.notes,
                        diagrams: options.songDiagrams,
                      );
                      metrics = measureBlocks(
                        blocks,
                        formatter: formatter,
                        lyricsOnly: false,
                        textScaler: MediaQuery.textScalerOf(context),
                        baseStyle: DefaultTextStyle.of(context).style,
                        diagramResolver: resolver,
                        display: display,
                      );
                      return SongBody(song: song, options: options);
                    },
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final report = <String>[];
        for (var i = 0; i < metrics.length; i++) {
          final rendered = tester
              .getSize(find.byKey(ValueKey(('song-block', i))))
              .height;
          final measured = metrics[i].height(fontSize, width);
          // Never smaller than what is drawn, beyond the safety margin of
          // fitSong (text lines are rounded up to whole pixels when drawn);
          // a little generous is fine (wrapping is estimated).
          if (measured < rendered * fitSafety ||
              measured > rendered * 1.15 + 4) {
            report.add(
              'block $i (${describe(blocks[i])}): '
              'measured $measured, rendered $rendered',
            );
          }
        }
        expect(report, isEmpty);
      });
    }
  }
}

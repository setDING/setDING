// Renders the projected page of the lyrics projection (ADR-0068) for the
// website: the real page asset served by the real ProjectionServer, shot by
// a headless Chromium. Run through tool/projection-screenshots.sh.
//
// Usage: dart --packages=app/.dart_tool/package_config.json \
//   app/tool/projection_screenshots.dart <app dir> <out dir> <chromium>
import 'dart:io';

import 'package:chordpro/chordpro.dart';
import 'package:setding/projection/projection_page.dart';
import 'package:setding/projection/projection_server_io.dart';
import 'package:setding/projection/projection_state.dart';

// Original example lyrics, written for these screenshots.
const _de = '''{title: Licht am Abend}
{copyright: © 2026 setDING Beispiel}
{start_of_verse}
Wenn der Tag sich leise neigt
und die Stadt im Abend schweigt,
singen wir ein einfaches Lied,
das uns heim ins Helle zieht.
{end_of_verse}
''';

const _en = '''{title: Evening Light}
{copyright: © 2026 setDING Example}
{start_of_verse}
When the day is fading slow
and the city lights are low,
we will sing a simple song
that will carry us along.
{end_of_verse}
''';

Future<void> main(List<String> args) async {
  final [appDir, outDir, chromium] = args;
  final template = File('$appDir/$projectionPageAsset').readAsStringSync();
  final de = parseChordPro(_de), en = parseChordPro(_en);

  LyricSlide slide(Song song, {Song? second, int lines = 8}) => lyricSlides(
    lyricSections(song),
    linesPerSlide: lines,
    second: second == null ? null : lyricSections(second),
  ).first;

  // Sections without a label are named as in the app (#1185).
  ProjectionState state(Song song, LyricSlide s) => ProjectionState.slide(
    s,
    title: song.title,
    copyright: song.copyright,
    defaultLabel: identical(song, de) ? 'Strophe' : 'Verse',
  );

  final shots = <(String, ProjectionState, String)>[
    ('projection_page', state(en, slide(en)), ''),
    ('projection_page_de', state(de, slide(de)), ''),
    ('projection_two_languages', state(de, slide(de, second: en)), ''),
    ('projection_two_languages_de', state(de, slide(de, second: en)), ''),
    ('projection_lower_third', state(en, slide(en, lines: 2)), '/lower-third'),
    (
      'projection_lower_third_de',
      state(de, slide(de, lines: 2)),
      '/lower-third',
    ),
  ];

  for (final (name, shown, path) in shots) {
    final server = ProjectionServer(
      page: projectionPage(
        template,
        lang: name.endsWith('_de') ? 'de' : 'en',
        fullScreen: 'Full screen',
      ),
    );
    await server.start(port: 0);
    server.update(shown);
    final url = 'http://127.0.0.1:${server.port}/p/${server.token}$path';
    final result = await Process.run(chromium, [
      '--headless',
      '--disable-gpu',
      '--hide-scrollbars',
      '--window-size=1280,720',
      // Shot after a fixed time: the open event stream keeps the page
      // loading, so a virtual time budget would never run out.
      '--timeout=2500',
      // The lower third is transparent; a slate (RRGGBBAA) stands in for the video
      // behind it in OBS.
      if (path.isNotEmpty) '--default-background-color=3C4650FF',
      '--screenshot=$outDir/$name.png',
      url,
    ]);
    await server.stop();
    if (result.exitCode != 0) {
      stderr.write(result.stderr);
      exit(result.exitCode);
    }
    stdout.writeln('$outDir/$name.png');
  }
}

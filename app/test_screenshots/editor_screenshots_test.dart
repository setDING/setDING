// Screenshots of the song editor hints and the import report.
// See screenshot_support.dart.
import 'dart:convert';

import 'package:setding/data/import_export.dart';
import 'package:setding/ui/songs/import_dialog.dart';
import 'package:setding/data/demo_song.dart';
import 'package:setding/ui/songs/song_editor_screen.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/test_app.dart';

import 'screenshot_support.dart';

void main() {
  setUpScreenshots();

  // Chorus labels after `{chorus: ` (#758).
  for (final (lang, dark) in [('de', false), ('en', true)]) {
    screenshotTest('chorus labels $lang', (tester) async {
      useTabletSize(tester);
      final app = await TestApp.create(
        prefs: {'language': lang, 'themeMode': dark ? 'dark' : 'light'},
      );
      final (refrain, last) = lang == 'de'
          ? ('Refrain', 'Schlussrefrain')
          : ('Chorus', 'Final chorus');
      final source =
          '{title: Amazing Grace}\n{key: G}\n\n'
          '{start_of_chorus label="$refrain"}\n'
          'A[G]mazing [G7]grace, how [C]sweet the [G]sound\n'
          '{end_of_chorus}\n\n'
          '{start_of_chorus label="$last"}\n'
          'I [G]once was [D]lost, but [G]now am found\n'
          '{end_of_chorus}\n\n{chorus:}';
      await tester.pumpWidget(
        RepaintBoundary(
          key: UniqueKey(),
          child: app.build(home: SongEditorScreen(initialSource: source)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextField));
      await tester.pump();
      final at = source.length - 1;
      tester.testTextInput.updateEditingValue(
        TextEditingValue(
          text: source.replaceRange(at, at, ' '),
          selection: TextSelection.collapsed(offset: at + 1),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.label_outline), findsNWidgets(2));
      await shot(tester, '${lang}_33_editor_chorus_labels');
      await app.dispose(tester);
    });
  }

  // An empty or invalid {key} in the save warning (#933).
  for (final (lang, dark) in [('de', false), ('en', true)]) {
    screenshotTest('invalid key $lang', (tester) async {
      useTabletSize(tester);
      final app = await TestApp.create(
        prefs: {'language': lang, 'themeMode': dark ? 'dark' : 'light'},
      );
      const source =
          '{title: Amazing Grace}\n{key}\n\n'
          'A[G]mazing [G7]grace, how [C]sweet the [G]sound\n'
          'That [G]saved a [Em]wretch like [D]me';
      await tester.pumpWidget(
        RepaintBoundary(
          key: UniqueKey(),
          child: app.build(home: SongEditorScreen(initialSource: source)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(lang == 'de' ? 'Speichern' : 'Save'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOne);
      await shot(tester, '${lang}_48_editor_invalid_key');
      await app.dispose(tester);
    });
  }

  // A key suggested from the chords in the song details (#919).
  for (final (lang, dark) in [('de', false), ('en', true)]) {
    screenshotTest('key suggestion $lang', (tester) async {
      useTabletSize(tester);
      final app = await TestApp.create(
        prefs: {'language': lang, 'themeMode': dark ? 'dark' : 'light'},
      );
      const source =
          '{title: Amazing Grace}\n\n'
          'A[G]mazing [G7]grace, how [C]sweet the [G]sound\n'
          'That [G]saved a [Em]wretch like [D]me\n'
          'I [G]once was [G7]lost, but [C]now am [G]found\n'
          'Was [Em]blind but [D]now I [G]see';
      await tester.pumpWidget(
        RepaintBoundary(
          key: UniqueKey(),
          child: app.build(home: SongEditorScreen(initialSource: source)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(lang == 'de' ? 'Songdetails' : 'Song details'),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('songDetail-keyGuess-G')), findsOne);
      await shot(tester, '${lang}_47_song_details_key');
      await app.dispose(tester);
    });
  }

  // The CCLI footer of SongSelect files (#785): the editor hint that
  // removes it and keeps its values as metadata.
  for (final (lang, dark) in [('de', false), ('en', true)]) {
    screenshotTest('ccli footer $lang', (tester) async {
      useTabletSize(tester);
      final app = await TestApp.create(
        prefs: {'language': lang, 'themeMode': dark ? 'dark' : 'light'},
      );
      await tester.pumpWidget(
        RepaintBoundary(
          key: UniqueKey(),
          child: app.build(
            home: SongEditorScreen(
              initialSource: lang == 'de' ? _ccliFooterDe : _ccliFooter,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CcliFooterHint), findsOneWidget);
      await shot(tester, '${lang}_24c_editor_ccli_footer');
      await app.dispose(tester);
    });
  }

  // Sections marked with comment headings (#963): the hint that turns
  // them into section environments.
  for (final (lang, dark) in [('de', false), ('en', true)]) {
    screenshotTest('comment headings $lang', (tester) async {
      useTabletSize(tester);
      final app = await TestApp.create(
        prefs: {'language': lang, 'themeMode': dark ? 'dark' : 'light'},
      );
      await tester.pumpWidget(
        RepaintBoundary(
          key: UniqueKey(),
          child: app.build(
            home: SongEditorScreen(
              initialSource: lang == 'de' ? _headingsDe : _headings,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CommentHeadingHint), findsOneWidget);
      await shot(tester, '${lang}_24d_editor_headings');
      await app.dispose(tester);
    });
  }

  // Section labels in the short form (#672): the editor hint and the import
  // report that offer to convert them to label="…"; the CCLI bar line hint
  // (#481).
  for (final (lang, dark) in [('de', false), ('en', true)]) {
    screenshotTest('section label conversion $lang', (tester) async {
      useTabletSize(tester);
      final app = await TestApp.create(
        prefs: {'language': lang, 'themeMode': dark ? 'dark' : 'light'},
      );
      final source = lang == 'de' ? _shortLabelsDe : _shortLabels;
      await tester.pumpWidget(
        RepaintBoundary(
          key: UniqueKey(),
          child: app.build(home: SongEditorScreen(initialSource: source)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LegacyLabelHint), findsOneWidget);
      await shot(tester, '${lang}_23_editor_labels');

      // CCLI bar lines (#481): the hint that converts them to chord grids.
      await tester.pumpWidget(
        RepaintBoundary(
          key: UniqueKey(),
          child: app.build(
            home: SongEditorScreen(
              initialSource: lang == 'de' ? _ccliBarsDe : _ccliBars,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CcliGridHint), findsOneWidget);
      expect(find.byType(LegacyLabelHint), findsNothing);
      await shot(tester, '${lang}_24_editor_ccli');

      // SongSelect directives outside the specification (#777): the hint
      // that renames {ccli} and removes {ccli_license}.
      await tester.pumpWidget(
        RepaintBoundary(
          key: UniqueKey(),
          child: app.build(
            home: const SongEditorScreen(initialSource: _songSelectDirectives),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SongSelectDirectiveHint), findsOneWidget);
      await shot(tester, '${lang}_24b_editor_songselect');

      // Typing aids (#747): Enter after a section start adds its end, a
      // typed `[` its `]`. Esc hides the chord suggestions, which would
      // cover the end directive.
      const autoClose =
          '{title: Amazing Grace}\n{key: G}\n\n{start_of_verse}\n'
          'A[G]mazing [G7]grace, how [C]sweet the [G]sound\n'
          '{end_of_verse}\n\n{start_of_chorus}';
      await tester.pumpWidget(
        RepaintBoundary(
          key: UniqueKey(),
          child: app.build(
            home: const SongEditorScreen(initialSource: autoClose),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextField));
      await tester.pump();
      final editor = tester.widget<TextField>(find.byType(TextField));
      for (final char in ['\n', '[']) {
        final value = editor.controller!.value;
        final at = char == '\n'
            ? value.text.length
            : value.selection.baseOffset;
        tester.testTextInput.updateEditingValue(
          TextEditingValue(
            text: value.text.replaceRange(at, at, char),
            selection: TextSelection.collapsed(offset: at + 1),
          ),
        );
        await tester.pumpAndSettle();
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(
        editor.controller!.text,
        endsWith('{start_of_chorus}\n[]\n{end_of_chorus}'),
      );
      await shot(tester, '${lang}_31_editor_auto_close');

      // The save button (#748): filled as soon as there are unsaved changes.
      await tester.pumpWidget(
        RepaintBoundary(
          key: UniqueKey(),
          child: app.build(
            home: SongEditorScreen(initialSource: demoSongSource),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final saveField = tester.widget<TextField>(find.byType(TextField));
      saveField.controller!.text = '$demoSongSource\n';
      await shot(tester, '${lang}_32_editor_save');

      ImportFile file(String name, String text) =>
          ImportFile(name, Uint8List.fromList(utf8.encode(text)));
      final files = [
        file('amazing-grace.cho', source),
        file(
          'morning-light.cho',
          '{title: Morning Light}\n{key: D}\n'
              '{sov: ${lang == 'de' ? 'Strophe' : 'Verse'} 1}\n'
              '[D]Morning light on the hill\n{eov}\n',
        ),
        file(
          'washed.cho',
          '{title: Washed}\n{c: Chorus} (a cappella)\n[G]la\n',
        ),
      ];
      await tester.pumpWidget(
        RepaintBoundary(
          key: UniqueKey(),
          child: app.build(
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: TextButton(
                    onPressed: () => showImportDialog(
                      context,
                      pick: ({extensions}) async => files,
                    ),
                    child: const Text('import'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('import'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(lang == 'de' ? 'Dateien auswählen' : 'Choose files'),
      );
      // The import writes to the database outside the fake clock.
      final report = find.byKey(const Key('import-problems'));
      for (var i = 0; i < 100 && report.evaluate().isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(report, findsOneWidget);
      await shot(tester, '${lang}_23b_import_labels');
      await app.dispose(tester);
    });
  }

  // Keys suggested from the chords in the import report (#925).
  for (final (lang, dark) in [('de', false), ('en', true)]) {
    screenshotTest('import key suggestions $lang', (tester) async {
      useTabletSize(tester);
      final app = await TestApp.create(
        prefs: {'language': lang, 'themeMode': dark ? 'dark' : 'light'},
      );
      ImportFile file(String name, String text) =>
          ImportFile(name, Uint8List.fromList(utf8.encode(text)));
      final files = [
        file(
          'amazing-grace.cho',
          '{title: Amazing Grace}\n'
              'A[G]mazing [G7]grace, how [C]sweet the [G]sound\n'
              'That [G]saved a [Em]wretch like [D]me\n'
              'Was [Em]blind but [D]now I [G]see\n',
        ),
        file(
          'house-of-the-rising-sun.cho',
          '{title: House of the Rising Sun}\n'
              'There [Am]is a [C]house in [D]New Or[F]leans\n'
              'They [Am]call the [C]Rising [E]Sun\n'
              'And it\'s [Am]been the [C]ruin of [D]many a poor [F]boy\n'
              'And [Am]God, I [E]know I\'m [Am]one\n',
        ),
        file(
          'morning-light.cho',
          '{title: Morning Light}\n'
              '[Am]Morning [F]light on the [C]hill, the [G]sun is [Am]rising\n',
        ),
      ];
      await tester.pumpWidget(
        RepaintBoundary(
          key: UniqueKey(),
          child: app.build(
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: TextButton(
                    onPressed: () => showImportDialog(
                      context,
                      pick: ({extensions}) async => files,
                    ),
                    child: const Text('import'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('import'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(lang == 'de' ? 'Dateien auswählen' : 'Choose files'),
      );
      // The import writes to the database outside the fake clock.
      final keys = find.byKey(const Key('import-key-suggestions'));
      for (var i = 0; i < 100 && keys.evaluate().isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(keys, findsOneWidget);
      await tester.pumpAndSettle();
      await shot(tester, '${lang}_47b_import_keys');
      await app.dispose(tester);
    });
  }
}

const _songSelectDirectives = '''{title: Amazing Grace}
{artist: John Newton}
{key: G}
{ccli_license: 1234567}
{ccli: 7654321}
{copyright: Public Domain}

{start_of_verse: label="Verse 1"}
A[G]mazing grace, how [C]sweet the [G]sound
That saved a wretch like [D]me
{end_of_verse}
''';

const _ccliFooter = '''{title: Amazing Grace}
{artist: John Newton}
{key: G}

{start_of_verse: label="Verse 1"}
A[G]mazing grace, how [C]sweet the [G]sound
That saved a wretch like [D]me
{end_of_verse}

CCLI Song # 1234567
© Public Domain
For use solely with the SongSelect® Terms of Use. All rights reserved. www.ccli.com
CCLI License # 7654321
''';

const _ccliFooterDe = '''{title: Amazing Grace}
{artist: John Newton}
{key: G}

{start_of_verse: label="Strophe 1"}
A[G]mazing grace, how [C]sweet the [G]sound
That saved a wretch like [D]me
{end_of_verse}

CCLI-Liednummer 1234567
© Public Domain
Nur zur Verwendung gemäss den SongSelect® Nutzungsbedingungen. Alle Rechte vorbehalten. www.ccli.com
CCLI-Lizenznummer 7654321
''';

const _headings = '''{title: Amazing Grace}
{artist: John Newton}
{key: G}

{comment: Verse 1}
A[G]mazing grace, how [C]sweet the [G]sound
That saved a wretch like [D]me

{comment: Chorus}
I [G]once was [G7]lost, but [C]now am [G]found
Was [Em]blind, but [D]now I [G]see
''';

const _headingsDe = '''{title: Amazing Grace}
{artist: John Newton}
{key: G}

{comment: Strophe 1}
A[G]mazing grace, how [C]sweet the [G]sound
That saved a wretch like [D]me

{comment: Refrain}
I [G]once was [G7]lost, but [C]now am [G]found
Was [Em]blind, but [D]now I [G]see
''';

const _ccliBars = '''{title: Amazing Grace}
{artist: John Newton}
{key: G}

{comment: Intro}
[|][G] [.] [G/B] [.][|][C2] [.] [G] [.][|]

{start_of_verse: label="Verse 1"}
A[G]mazing grace, how [C]sweet the [G]sound
That saved a wretch like [D]me
{end_of_verse}

{comment: Turnaround}
[|][Em] [D] [C] [.][|][G] [.] [.] [.][|]
''';

const _ccliBarsDe = '''{title: Amazing Grace}
{artist: John Newton}
{key: G}

{comment: Intro}
[|][G] [.] [G/B] [.][|][C2] [.] [G] [.][|]

{start_of_verse: label="Strophe 1"}
A[G]mazing grace, how [C]sweet the [G]sound
That saved a wretch like [D]me
{end_of_verse}

{comment: Zwischenspiel}
[|][Em] [D] [C] [.][|][G] [.] [.] [.][|]
''';

const _shortLabels = '''{title: Amazing Grace}
{artist: John Newton}
{key: G}

{start_of_verse: Verse 1}
A[G]mazing [G7]grace, how [C]sweet the [G]sound
That saved a wretch like [D]me
{end_of_verse}

{soc: Chorus}
I [G]once was [G7]lost, but [C]now am [G]found
Was [Em]blind, but [D]now I [G]see
{eoc}

{start_of_verse: label="Verse 2"}
'Twas [G]grace that [G7]taught my [C]heart to [G]fear
{end_of_verse}
''';

const _shortLabelsDe = '''{title: Amazing Grace}
{artist: John Newton}
{key: G}

{start_of_verse: Strophe 1}
A[G]mazing [G7]grace, how [C]sweet the [G]sound
That saved a wretch like [D]me
{end_of_verse}

{soc: Refrain}
I [G]once was [G7]lost, but [C]now am [G]found
Was [Em]blind, but [D]now I [G]see
{eoc}

{start_of_verse: label="Strophe 2"}
'Twas [G]grace that [G7]taught my [C]heart to [G]fear
{end_of_verse}
''';

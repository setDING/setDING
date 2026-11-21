import 'package:chordpro/chordpro.dart' as cp;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/data/backup.dart';
import 'package:setding/data/marker_icons.dart';
import 'package:setding/data/set_archive.dart';
import 'package:setding/l10n/generated/app_localizations.dart';
import 'package:setding/ui/live/live_screen.dart';
import 'package:setding/ui/sets/set_item_label.dart';
import 'package:setding/ui/sets/set_list.dart';
import 'package:setding/ui/sets/set_screen.dart';

import 'set_list_lines.dart';
import 'test_app.dart';

/// Breaks and text items named after their type in any UI language show
/// the type label of the current language once (#289).
void main() {
  final de = lookupAppLocalizations(const Locale('de'));
  final en = lookupAppLocalizations(const Locale('en'));

  group('markerNote', () {
    test('ignores the type label of every supported language', () {
      for (final note in [
        null,
        '',
        '  ',
        'Pause',
        'Break',
        'break ',
        'PAUSE',
      ]) {
        expect(markerNote(MarkerIcons.breakIcon, note), isNull, reason: note);
      }
      expect(markerNote(MarkerIcons.announcement, 'Text'), isNull);
      expect(markerNote(MarkerIcons.announcement, ''), isNull);
    });

    test('keeps a note of its own', () {
      expect(markerNote(MarkerIcons.breakIcon, ' Coffee '), 'Coffee');
      // The label of the other type is a note of its own.
      expect(markerNote(MarkerIcons.announcement, 'Pause'), 'Pause');
      expect(markerNote(MarkerIcons.breakIcon, 'Text'), 'Text');
    });

    test('names an item by the label of the current language', () {
      expect(markerTitle(en, MarkerIcons.breakIcon, 'Pause'), 'Break');
      expect(markerTitle(de, MarkerIcons.breakIcon, 'Break'), 'Pause');
      expect(markerTitle(de, MarkerIcons.breakIcon, null), 'Pause');
      // A text item named "Text" by an older version shows the name of the
      // icon it became (ADR-0047).
      expect(markerTitle(en, MarkerIcons.announcement, ''), 'Announcement');
      expect(markerTitle(de, MarkerIcons.announcement, 'Text'), 'Ansage');
      expect(markerTitle(en, MarkerIcons.encore, 'Zugabe'), 'Encore');
      expect(markerTitle(de, 'from-a-newer-app', null), 'Hinweis');
      expect(markerTitle(de, MarkerIcons.breakIcon, 'Kaffee'), 'Kaffee');
    });
  });

  /// A set with a break from the German UI ("Pause"), one from the English
  /// UI ("Break"), a break without a note, a break with a note of its own
  /// and a text item named "Text".
  Future<String> createSet(TestApp app) async {
    final song = await app.songs.createSong(source: '{title: Song}\n{key: G}');
    final setId = await app.sets.createSet(name: 'Gig');
    await app.sets.addSongs(setId, [song]);
    await app.sets.addMarker(setId, MarkerIcons.breakIcon, 'Pause');
    await app.sets.addMarker(setId, MarkerIcons.breakIcon, 'Break');
    await app.sets.addMarker(setId, MarkerIcons.breakIcon, '');
    await app.sets.addMarker(setId, MarkerIcons.breakIcon, 'Coffee');
    await app.sets.addMarker(setId, MarkerIcons.announcement, 'Text');
    return setId;
  }

  for (final (language, label, other, announcement) in [
    ('en', 'Break', 'Pause', 'Announcement'),
    ('de', 'Pause', 'Break', 'Ansage'),
  ]) {
    testWidgets('set screen shows the $language label once', (tester) async {
      useTabletSize(tester);
      final app = await TestApp.create(prefs: {'language': language});
      final setId = (await tester.runAsync(() => createSet(app)))!;
      await tester.pumpWidget(app.build(home: SetScreen(setId: setId)));
      await tester.pumpAndSettle();

      final tiles = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
      String? title(ListTile t) => (t.title as Text?)?.data;
      String? subtitle(ListTile t) => (t.subtitle as Text?)?.data;
      final breaks = tiles.where((t) => title(t) == label).toList();
      // The three breaks without a note of their own, each without subtitle.
      expect(breaks, hasLength(3));
      expect(breaks.map(subtitle), everyElement(isNull));
      expect(find.text(other), findsNothing);
      final coffee = tiles.firstWhere((t) => title(t) == 'Coffee');
      expect(subtitle(coffee), label);
      final text = tiles.firstWhere((t) => title(t) == announcement);
      expect(subtitle(text), isNull);
      await app.dispose(tester);
    });

    testWidgets('live mode shows the $language label', (tester) async {
      useTabletSize(tester);
      final app = await TestApp.create(prefs: {'language': language});
      final items = await tester.runAsync(() async {
        final song = await app.songs.createSong(
          source: '{title: Song}\n{key: G}\n[G]One',
        );
        final setId = await app.sets.createSet(name: 'Gig');
        await app.sets.addSongs(setId, [song]);
        // Created in the other language.
        await app.sets.addMarker(setId, MarkerIcons.breakIcon, other);
        return [
          for (final v in await app.sets.getItems(setId))
            v.song == null
                ? LiveItem.marker(v.item.icon, v.item.note)
                : LiveItem.song(v.song!),
        ];
      });
      await tester.pumpWidget(app.build(home: LiveScreen(items: items!)));
      await tester.pumpAndSettle();

      final l10n = language == 'de' ? de : en;
      expect(find.text(l10n.liveNext(label)), findsOneWidget);
      // The set overview, from the control bar.
      await tester.tapAt(tester.getCenter(find.byType(PageView)));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(l10n.liveSetOverview));
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: find.byType(ListTile), matching: find.text(label)),
        findsOneWidget,
      );
      expect(find.text(other), findsNothing);
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      // The marker page.
      expect(find.text(label), findsOneWidget);
      expect(find.text(other), findsNothing);
      await app.dispose(tester);
    });

    testWidgets('set list export shows the $language label', (tester) async {
      final app = await TestApp.create(prefs: {'language': language});
      final data = await tester.runAsync(() async {
        final setId = await createSet(app);
        return (
          (await app.sets.getSet(setId))!,
          await app.sets.getItems(setId),
        );
      });
      final text = describeSetList(
        buildSetList(
          data!.$1,
          data.$2,
          notation: cp.ChordNotation.international,
          formatDate: (d) => '',
          untitled: 'Untitled',
          songMissing: 'Missing',
          markerName: (icon) =>
              markerIconName(language == 'de' ? de : en, icon),
        ),
      );
      // Every marker is a divider; the text item named "Text" shows its
      // icon's name (ADR-0047).
      expect(
        text,
        'Gig\n'
        '\n'
        '1. Song – G\n'
        '— $label —\n'
        '— $label —\n'
        '— $label —\n'
        '— Coffee —\n'
        '— $announcement —\n',
      );

      // The set archive keeps the notes as stored: the label is shown in
      // the language of whoever imports it (ADR-0043 §1b).
      final zip = (await tester.runAsync(
        () =>
            SetArchiveService(BackupService(app.db, app.storage))
                .export(data.$1.id),
      ))!;
      final archive = (await tester.runAsync(
        () => SetArchiveService.read(zip),
      ))!;
      final notes = [
        for (final i in archive.set['items'] as List) (i as Map)['note'],
      ];
      expect(notes, [for (final v in data.$2) v.item.note]);
      await app.dispose(tester);
    });
  }

  testWidgets('a new break keeps no note when the label is left', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'de'});
    final setId = (await tester.runAsync(
      () => app.sets.createSet(name: 'Gig'),
    ))!;
    await tester.pumpWidget(app.build(home: SetScreen(setId: setId)));
    await tester.pumpAndSettle();

    Future<void> addBreak(String text) async {
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(de.addMarker));
      await tester.pumpAndSettle();
      if (text.isNotEmpty) {
        await tester.enterText(find.byType(TextField), text);
      }
      await tester.tap(find.text(de.save));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
    }

    // Saved without text, with the label of a language, with a note.
    await addBreak('');
    await addBreak('Break');
    await addBreak('Kaffee');
    final notes = await tester.runAsync(
      () async => [for (final v in await app.sets.getItems(setId)) v.item.note],
    );
    expect(notes, ['', '', 'Kaffee']);
    await app.dispose(tester);
  });
}

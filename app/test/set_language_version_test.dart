import 'package:chordpro/chordpro.dart' as cp;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/data/set_repository.dart';
import 'package:setding/ui/sets/set_screen.dart';

import 'test_app.dart';

const english = '''
{title: River}
{key: D}
{start_of_verse}
[D]I walk along the river
{end_of_verse}
{start_of_chorus}
[G]You are my light
{end_of_chorus}''';

const german = '''
{title: Fluss}
{key: E}
{start_of_verse}
[E]Ich gehe durch die Nacht
{end_of_verse}
{start_of_chorus}
[A]Du bist mein Licht
{end_of_chorus}''';

const swiss = '''
{title: Flussliecht}
{key: E}
{start_of_verse}
[E]Mir sind hüt alli da
{end_of_verse}''';

/// Switching a set item to another language version of its song
/// (ADR-0053, #807).
void main() {
  group('sequenceFits', () {
    final song = cp.parseChordPro(english);

    test('a sequence of parts the version has fits', () {
      expect(sequenceFits('V, C, V, C x2', song), isTrue);
      expect(sequenceFits('Verse, Chorus', song), isTrue);
    });

    test('a part the version lacks does not fit', () {
      expect(sequenceFits('V, C, Bridge', song), isFalse);
      expect(sequenceFits('V, C', cp.parseChordPro(swiss)), isFalse);
      expect(sequenceFits('V', cp.parseChordPro('{title: Empty}')), isFalse);
    });
  });

  Future<(TestApp, String, Map<String, String>)> openSet(
    WidgetTester tester, {
    String? sequence,
  }) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final (setId, ids) = (await tester.runAsync(() async {
      final en = await app.songs.createSong(source: english);
      final de = await app.songs.createSong(source: german);
      final ch = await app.songs.createSong(source: swiss);
      await app.songs.linkLanguageVersions(en, de);
      await app.songs.linkLanguageVersions(en, ch);
      await app.songs.setLanguage(ch, 'gsw');
      // Too short to be detected.
      await app.songs.setLanguage(en, 'en');
      await app.songs.setLanguage(de, 'de');
      final setId = await app.sets.createSet(name: 'Gig');
      await app.sets.addSongs(setId, [en]);
      if (sequence != null) {
        final item = (await app.sets.getItems(setId)).single.item;
        await app.sets.setItemSequence(item.id, sequence);
      }
      return (setId, {'en': en, 'de': de, 'ch': ch});
    }))!;
    await tester.pumpWidget(app.build(home: SetScreen(setId: setId)));
    await tester.pumpAndSettle();
    return (app, setId, ids);
  }

  Future<void> switchTo(WidgetTester tester, String songId) async {
    await tester.tap(
      find.byWidgetPredicate((w) => '${w.key}'.contains('set-item-menu-')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('set-item-action-version')));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.byKey(ValueKey('switch-version-$songId')));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
  }

  testWidgets('switching keeps the transposition and tells a new key', (
    tester,
  ) async {
    final (app, setId, ids) = await openSet(tester, sequence: 'V, C, V');
    await tester.tap(
      find.byWidgetPredicate((w) => '${w.key}'.contains('set-item-menu-')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('set-item-action-version')));
    await tester.pumpAndSettle();
    // The other versions with the key they would have in this set.
    expect(find.text('German'), findsOneWidget);
    expect(find.text('Fluss · in E in this set'), findsOneWidget);
    expect(find.text('Swiss German'), findsOneWidget);
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();

    await switchTo(tester, ids['de']!);
    expect(
      find.text('Switched to: German, in E instead of D in this set'),
      findsOneWidget,
    );
    final item = (await tester.runAsync(() => app.sets.getItems(setId)))!
        .single
        .item;
    expect(item.songId, ids['de']);
    expect(item.transpose, 0);
    expect(item.sequence, 'V, C, V'); // it fits the German version
    expect(find.text('Fluss'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('a sequence that does not fit the new version is removed', (
    tester,
  ) async {
    final (app, setId, ids) = await openSet(tester, sequence: 'V, C, V');
    await switchTo(tester, ids['ch']!);
    expect(
      find.textContaining('does not fit the new version and was removed'),
      findsOneWidget,
    );
    final item = (await tester.runAsync(() => app.sets.getItems(setId)))!
        .single
        .item;
    expect(item.songId, ids['ch']);
    expect(item.sequence, isNull);
    await app.dispose(tester);
  });

  testWidgets('songs without other versions offer no switch', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final setId = (await tester.runAsync(() async {
      final id = await app.songs.createSong(source: english);
      final setId = await app.sets.createSet(name: 'Gig');
      await app.sets.addSongs(setId, [id]);
      return setId;
    }))!;
    await tester.pumpWidget(app.build(home: SetScreen(setId: setId)));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byWidgetPredicate((w) => '${w.key}'.contains('set-item-menu-')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('set-item-action-version')), findsNothing);
    await app.dispose(tester);
  });
}

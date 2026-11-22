import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/data/database.dart' show SongEntry;
import 'package:setding/data/song_repository.dart' show SongListEntry;
import 'package:setding/sync/sync_backend.dart';
import 'package:setding/ui/songs/language_versions.dart';

import 'test_app.dart';

const _ann = AuthUser(id: 'ann', email: 'ann@example.test', name: 'Ann');
const _bob = AuthUser(id: 'bob', email: 'bob@example.test', name: 'Bob');

const english = '''
{title: River}
{artist: Ann}
{key: D}
I walk along the river and you are always there with me,
when the wind is in the willows and the night is calling me.
You are my light, and all the stars will shine for you.''';

const german = '''
{title: Fluss}
{artist: Ann}
{key: D}
Ich gehe durch die Nacht und du bist immer bei mir,
wenn der Wind über das Land zieht, singe ich mit dir.
Du bist mein Licht, auch wenn die Sterne nicht mehr scheinen.''';

/// Linking language versions and showing them (ADR-0053, #806).
void main() {
  Future<void> openSong(WidgetTester tester, String title) async {
    await tester.tap(find.text('Songs').first);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining(title).first);
    await tester.pumpAndSettle();
  }

  testWidgets('a song is linked, its versions open each other, and unlinked', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final (en, de) = (await tester.runAsync(() async {
      final en = await app.songs.createSong(source: english);
      final de = await app.songs.createSong(source: german);
      await app.songs.createSong(source: '{title: Other}\n{artist: Bob}');
      return (en, de);
    }))!;
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    await openSong(tester, 'River');
    expect(find.byKey(const Key('language-versions')), findsNothing);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('song-unlink-version')), findsNothing);
    await tester.tap(find.byKey(const Key('song-link-version')));
    await tester.pumpAndSettle();

    // The song with the same artist and key comes first; the song itself
    // is not offered.
    final candidates = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith(
            'language-version-candidate-',
          ),
    );
    expect(candidates, findsNWidgets(2));
    expect(
      tester.widget(candidates.first).key,
      ValueKey('language-version-candidate-$de'),
    );
    await tester.tap(candidates.first);
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('language-version-chosen-$de')), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('language-versions-save')));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(find.text('Language versions saved'), findsOneWidget);
    final song = (await tester.runAsync<SongEntry?>(
      () => app.songs.getSong(de),
    ))!;
    expect(song.workId, isNotNull);

    // English (the UI language) first, then German.
    expect(find.byKey(const Key('language-versions')), findsOneWidget);
    final chips = tester
        .widgetList<ChoiceChip>(find.byType(ChoiceChip))
        .toList();
    expect(
      [for (final c in chips) (c.label as Text).data],
      ['English', 'German'],
    );
    expect(chips.first.selected, isTrue);

    await tester.tap(find.byKey(ValueKey('language-version-$de')));
    await tester.pumpAndSettle();
    final opened = tester.widget<ChoiceChip>(
      find.byKey(ValueKey('language-version-$de')),
    );
    expect(opened.selected, isTrue);

    await tester.runAsync(() async {
      await tester.tap(find.byType(PopupMenuButton<String>));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('song-unlink-version')));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(find.text('Removed from the language versions'), findsOneWidget);
    expect(find.byKey(const Key('language-versions')), findsNothing);
    final work = song.workId;
    expect(
      (await tester.runAsync<SongEntry?>(() => app.songs.getSong(de)))!.workId,
      isNull,
    );

    await tester.runAsync(() async {
      await tester.tap(find.text('Undo'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(
      (await tester.runAsync<SongEntry?>(() => app.songs.getSong(de)))!.workId,
      work,
    );
    expect(find.byKey(const Key('language-versions')), findsOneWidget);
    expect(en, isNotEmpty);
    await app.dispose(tester);
  });

  testWidgets('several versions are chosen at once and removed again', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final (de, other) = (await tester.runAsync(() async {
      await app.songs.createSong(source: english);
      final de = await app.songs.createSong(source: german);
      final other = await app.songs.createSong(source: '{title: Other}');
      return (de, other);
    }))!;
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    await openSong(tester, 'River');

    Future<void> openPicker() async {
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('song-link-version')));
      await tester.pumpAndSettle();
    }

    Future<void> save() async {
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('language-versions-save')));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
    }

    await openPicker();
    // The title names the song the versions are chosen for.
    expect(find.text('Language versions of River'), findsOneWidget);
    // Nothing changed yet: nothing to save.
    final saveButton = find.byKey(const Key('language-versions-save'));
    expect(tester.widget<TextButton>(saveButton).onPressed, isNull);
    await tester.tap(find.byKey(ValueKey('language-version-candidate-$de')));
    await tester.tap(find.byKey(ValueKey('language-version-candidate-$other')));
    await tester.pumpAndSettle();
    expect(find.text('Linked versions (2)'), findsOneWidget);
    await save();
    expect(find.text('Language versions saved'), findsOneWidget);
    final chips = find.descendant(
      of: find.byKey(const Key('language-versions')),
      matching: find.byType(ChoiceChip),
    );
    expect(chips, findsNWidgets(3));
    await tester.pump(const Duration(seconds: 7));
    await tester.pumpAndSettle();

    // The chosen versions are listed; one is removed there again.
    await openPicker();
    expect(
      find.byKey(ValueKey('language-version-chosen-$other')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(ValueKey('language-version-remove-$other')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(ValueKey('language-version-chosen-$other')),
      findsNothing,
    );
    expect(find.text('Linked versions (1)'), findsOneWidget);
    await save();
    expect(chips, findsNWidgets(2));
    expect(
      (await tester.runAsync<SongEntry?>(() => app.songs.getSong(other)))!
          .workId,
      isNull,
    );

    // Undo links it again.
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(chips, findsNWidgets(3));
    await app.dispose(tester);
  });

  testWidgets('on a phone, the chosen versions are chips above the list', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final de = (await tester.runAsync(() async {
      final en = await app.songs.createSong(source: english);
      final de = await app.songs.createSong(source: german);
      await app.songs.linkLanguageVersions(en, de);
      return de;
    }))!;
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    await openSong(tester, 'River');
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('song-link-version')));
    await tester.pumpAndSettle();
    final chip = find.byKey(ValueKey('language-version-chosen-$de'));
    expect(tester.widget(chip), isA<InputChip>());
    await tester.tap(find.byTooltip('Remove').first);
    await tester.pumpAndSettle();
    expect(chip, findsNothing);
    expect(
      find.text('No other versions yet. Choose songs from the library.'),
      findsOneWidget,
    );
    await app.dispose(tester);
  });

  testWidgets('the song list marks songs with other versions', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    await tester.runAsync(() async {
      final en = await app.songs.createSong(source: english);
      final de = await app.songs.createSong(source: german);
      await app.songs.createSong(source: '{title: Alone}');
      await app.songs.linkLanguageVersions(en, de);
    });
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Songs').first);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('song-status-versions')),
      findsNWidgets(2),
    );
    expect(find.byTooltip('One other language version'), findsNWidgets(2));
    await app.dispose(tester);
  });

  testWidgets('members who cannot edit the song cannot link it', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(
      prefs: {'language': 'en', 'currentBandId': 'b1'},
      user: _bob,
    );
    app.backend.addBand('b1', 'Rock', admin: _ann, organizationId: 'o1');
    app.backend.addMember('b1', _bob, BandRole.member);
    await tester.runAsync(() async {
      final repo = TestApp.songsIn(app, 'o1');
      final en = await repo.createSong(source: english);
      final de = await repo.createSong(source: german);
      await repo.linkLanguageVersions(en, de);
    });
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    await openSong(tester, 'River');
    // Members see the versions but cannot change them.
    expect(find.byKey(const Key('language-versions')), findsOneWidget);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('song-link-version')), findsNothing);
    expect(find.byKey(const Key('song-unlink-version')), findsNothing);
    await app.dispose(tester);
  });

  test('versions are ordered by the UI language, then by language', () {
    SongEntry entry(String id, String title, String? language) => SongEntry(
      id: id,
      libraryId: 'l',
      chordproSource: '',
      title: title,
      chordproProblems: 0,
      chordproConversions: 0,
      revision: 0,
      updatedAt: DateTime(2026),
      deleted: false,
      purged: false,
      detectedLanguage: language,
    );
    final ordered = orderedLanguageVersions([
      entry('1', 'Unknown', null),
      entry('2', 'Fr', 'fr'),
      entry('3', 'De', 'de'),
      entry('4', 'En', 'en'),
    ], 'de');
    expect([for (final s in ordered) s.title], ['De', 'En', 'Fr', 'Unknown']);
  });

  test('likeness counts the same artist, key, tempo and sequence', () {
    const a = SongListEntry(
      id: 'a',
      title: 'A',
      artist: 'Ann',
      songKey: 'D',
      tempo: 90,
      sequence: 'V C',
    );
    const b = SongListEntry(
      id: 'b',
      title: 'B',
      artist: 'ann ',
      songKey: 'D',
      tempo: 100,
    );
    expect(languageVersionLikeness(a, b), 2);
    expect(languageVersionLikeness(a, a), 4);
  });
}

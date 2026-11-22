import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/data/database.dart' show SongEntry;
import 'package:setding/sync/sync_backend.dart';

import 'test_app.dart';

const _ann = AuthUser(id: 'ann', email: 'ann@example.test', name: 'Ann');
const _bob = AuthUser(id: 'bob', email: 'bob@example.test', name: 'Bob');

const english = '''
{title: River}
I walk along the river and you are always there with me,
when the wind is in the willows and the night is calling me.
You are my light, and all the stars will shine for you.''';

const german = '''
{title: Fluss}
Ich gehe durch die Nacht und du bist immer bei mir,
wenn der Wind über das Land zieht, singe ich mit dir.
Du bist mein Licht, auch wenn die Sterne nicht mehr scheinen.''';

/// The language of songs in the song list and the song menu (ADR-0053,
/// #805).
void main() {
  final tags = find.byKey(const ValueKey('song-language-tag'));
  final filter = find.byKey(const Key('songs-language'));

  Future<void> openSongs(WidgetTester tester) async {
    await tester.tap(find.text('Songs').first);
    await tester.pumpAndSettle();
  }

  testWidgets('a library in one language shows no tags and no filter', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    await tester.runAsync(() => app.songs.createSong(source: english));
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    await openSongs(tester);
    expect(find.text('River'), findsOneWidget);
    expect(tags, findsNothing);
    expect(filter, findsNothing);
    await app.dispose(tester);
  });

  testWidgets('songs in several languages get tags and a language filter', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    await tester.runAsync(() async {
      await app.songs.createSong(source: english);
      await app.songs.createSong(source: german);
      await app.songs.createSong(source: '{title: Instrumental}');
    });
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    await openSongs(tester);

    expect(tags, findsNWidgets(2));
    expect(find.text('EN'), findsOneWidget);
    expect(find.text('DE'), findsOneWidget);
    expect(find.byTooltip('German (detected from the lyrics)'), findsOneWidget);

    await tester.tap(filter);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('songs-language-de')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Fluss'), findsOneWidget);
    expect(find.textContaining('River'), findsNothing);
    expect(find.text('Instrumental'), findsNothing);
    expect(tester.widget<FilterChip>(filter).selected, isTrue);

    await tester.tap(filter);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('songs-language-all')));
    await tester.pumpAndSettle();
    expect(find.text('Instrumental'), findsOneWidget);

    // No language: the songs without one, above a divider (#834).
    await tester.tap(filter);
    await tester.pumpAndSettle();
    final none = find.byKey(const ValueKey('songs-language-none'));
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('songs-language-all'))).dy,
      lessThan(tester.getTopLeft(none).dy),
    );
    expect(
      tester.getTopLeft(none).dy,
      lessThan(
        tester.getTopLeft(find.byKey(const ValueKey('songs-language-de'))).dy,
      ),
    );
    final divider = tester.getTopLeft(find.byType(Divider).last).dy;
    expect(tester.getTopLeft(none).dy, lessThan(divider));
    expect(
      divider,
      lessThan(
        tester.getTopLeft(find.byKey(const ValueKey('songs-language-de'))).dy,
      ),
    );
    await tester.tap(none);
    await tester.pumpAndSettle();
    expect(find.text('Instrumental'), findsOneWidget);
    expect(find.textContaining('Fluss'), findsNothing);
    expect(find.textContaining('River'), findsNothing);
    expect(find.text('No language'), findsOneWidget);
    expect(tester.widget<FilterChip>(filter).selected, isTrue);
    await app.dispose(tester);
  });

  testWidgets('the song menu sets the language by hand and back', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final id = (await tester.runAsync(() async {
      await app.songs.createSong(source: english);
      return app.songs.createSong(source: german);
    }))!;
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    await openSongs(tester);
    await tester.tap(find.textContaining('Fluss'));
    await tester.pumpAndSettle();

    Future<void> choose(String key) async {
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('song-language')));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.byKey(ValueKey('song-language-$key')));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
    }

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('song-language')));
    await tester.pumpAndSettle();
    expect(find.text('Automatic: German'), findsOneWidget);
    expect(find.text('Swiss German'), findsOneWidget);
    // A flag in front of every language (#845); *automatic* shows the
    // detected language's flag, *other* a language icon.
    for (final l in ['de', 'gsw', 'en', 'fr', 'it', 'es', 'pt', 'nl']) {
      expect(
        find.descendant(
          of: find.byKey(ValueKey('song-language-$l')),
          matching: find.byKey(ValueKey('song-language-flag-$l')),
        ),
        findsOneWidget,
      );
    }
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('song-language-auto')),
        matching: find.byKey(const ValueKey('song-language-flag-de')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('song-language-other')),
        matching: find.byIcon(Icons.language),
      ),
      findsOneWidget,
    );
    await tester.tapAt(Offset.zero); // closes the dialog
    await tester.pumpAndSettle();

    await choose('gsw');
    var song = (await tester.runAsync<SongEntry?>(
      () => app.songs.getSong(id),
    ))!;
    expect(song.language, 'gsw');

    await choose('auto');
    song = (await tester.runAsync<SongEntry?>(() => app.songs.getSong(id)))!;
    expect(song.language, isNull);
    await app.dispose(tester);
  });

  testWidgets('members who cannot edit the song cannot set its language', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(
      prefs: {'language': 'en', 'currentBandId': 'b1'},
      user: _bob,
    );
    app.backend.addBand('b1', 'Rock', admin: _ann, organizationId: 'o1');
    app.backend.addMember('b1', _bob, BandRole.member);
    await tester.runAsync(
      () => TestApp.songsIn(app, 'o1').createSong(source: english),
    );
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    await openSongs(tester);
    await tester.tap(find.text('River'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('song-language')), findsNothing);
    await app.dispose(tester);
  });
}

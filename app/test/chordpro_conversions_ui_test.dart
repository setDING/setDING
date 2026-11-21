import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/sync/sync_backend.dart';

import 'test_app.dart';

const _ann = AuthUser(id: 'ann', email: 'ann@example.test', name: 'Ann');
const _bob = AuthUser(id: 'bob', email: 'bob@example.test', name: 'Bob');

/// Songs with places the editor offers to convert, shown in the song list
/// and on the overview (#798).
void main() {
  const songSelect =
      '{title: Old}\n{ccli: 6016351}\n{start_of_verse: Verse 1}\n[G]La\n'
      '{end_of_verse}\n';
  const tidy = '{title: Tidy}\n{x_ccli: 1}\n[C]x\n';

  final icon = find.byKey(const ValueKey('song-status-conversions'));

  testWidgets('the overview line filters the song list, which converts all', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final id = (await tester.runAsync(() async {
      await app.songs.createSong(source: tidy);
      return app.songs.createSong(source: songSelect);
    }))!;
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();

    expect(find.text('1 song with possible conversions'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('overview-todo-conversions')));
    await tester.pumpAndSettle();
    expect(find.text('Convertible'), findsOneWidget);
    expect(find.text('Old'), findsOneWidget);
    expect(find.text('Tidy'), findsNothing);
    expect(icon, findsOneWidget);
    expect(
      find.byTooltip('2 places in the ChordPro can be converted'),
      findsOneWidget,
    );

    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('songs-convert-all')));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(find.text('Convert all songs?'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('confirm-action')));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    expect(find.text('1 song converted'), findsOneWidget);
    expect(find.text('Old'), findsNothing);

    final song = (await tester.runAsync(() => app.songs.getSong(id)))!;
    expect(song.chordproSource, contains('{x_ccli: 6016351}'));
    expect(song.chordproSource, contains('{start_of_verse: label="Verse 1"}'));
    expect(song.chordproConversions, 0);
    await app.dispose(tester);
  });

  testWidgets('members who cannot edit the song see no conversions', (
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
      () => TestApp.songsIn(app, 'o1').createSong(source: songSelect),
    );
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('overview-todo-conversions')),
      findsNothing,
    );
    await tester.tap(find.text('Songs').first);
    await tester.pumpAndSettle();
    expect(find.text('Old'), findsOneWidget);
    expect(icon, findsNothing);
    await app.dispose(tester);
  });
}

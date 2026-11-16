import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:realchord/sync/sync_backend.dart';
import 'package:realchord/ui/bands/bands_screen.dart';
import 'package:realchord/ui/songs/song_screen.dart';

import 'test_app.dart';

const _ann = AuthUser(id: 'ann', email: 'ann@example.test', name: 'Ann');
const _bob = AuthUser(id: 'bob', email: 'bob@example.test', name: 'Bob');

void main() {
  Future<TestApp> start(
    WidgetTester tester, {
    AuthUser? user,
    void Function(TestApp app)? server,
  }) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'}, user: user);
    server?.call(app);
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    return app;
  }

  Future<void> openSongs(WidgetTester tester) async {
    await tester.tap(find.text('Songs').first);
    await tester.pumpAndSettle();
  }

  Future<void> switchTo(WidgetTester tester, String band) async {
    await tester.tap(find.byKey(const Key('band-switcher')).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(band).last);
    await tester.pumpAndSettle();
  }

  testWidgets('signed out, the app looks like the single-device MVP', (
    tester,
  ) async {
    final app = await start(tester);
    await openSongs(tester);
    expect(find.byKey(const Key('band-switcher')), findsNothing);
    expect(find.text('New song'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('switching bands shows the library of the organization', (
    tester,
  ) async {
    final app = await start(
      tester,
      user: _ann,
      server: (app) =>
          app.backend.addBand('b1', 'Rock', admin: _ann, organizationId: 'o1'),
    );
    await app.songs.createSong(source: '{title: Local song}');
    await openSongs(tester);
    expect(find.text('Local song'), findsOneWidget);

    await switchTo(tester, 'Rock');
    expect(find.text('Local song'), findsNothing);
    expect(app.prefs.getString('currentBandId'), 'b1');

    await switchTo(tester, 'On this device');
    expect(find.text('Local song'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('members without edit rights only read songs and sets', (
    tester,
  ) async {
    final app = await start(
      tester,
      user: _bob,
      server: (app) {
        app.backend.addBand('b1', 'Rock', admin: _ann, organizationId: 'o1');
        app.backend.addMember('b1', _bob, BandRole.member);
      },
    );
    await app.prefs.setString('currentBandId', 'b1');
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();

    // Sets: no "New set".
    expect(find.text('New set'), findsNothing);
    await openSongs(tester);
    expect(find.text('New song'), findsNothing);
    expect(find.byTooltip('Import files'), findsNothing);
    await app.dispose(tester);
  });

  testWidgets('copies selected songs into an organization library', (
    tester,
  ) async {
    final app = await start(
      tester,
      user: _ann,
      server: (app) =>
          app.backend.addBand('b1', 'Rock', admin: _ann, organizationId: 'o1'),
    );
    app.backend.organizations['o1'] = 'School';
    await app.songs.createSong(source: '{title: Alpha}');
    await app.songs.createSong(source: '{title: Beta}');
    await openSongs(tester);

    await tester.longPress(find.text('Alpha'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Beta'));
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);
    await tester.tap(find.byKey(const Key('songs-copy-to-band')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rock').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('2 songs copied'), findsOneWidget);

    await switchTo(tester, 'Rock');
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('creating a band selects it and creates an organization', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'}, user: _ann);
    await tester.pumpWidget(app.build(home: const BandsScreen()));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'You are not in a band yet. Create a band for your songs and sets.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('band-new')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('band-new-name')), 'Rockers');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(app.backend.bands.values.single.name, 'Rockers');
    expect(app.backend.organizations.values.single, 'Rockers');
    expect(find.text('Rockers'), findsNWidgets(2)); // organization and band
    final bandId = app.backend.bands.keys.single;
    expect(app.prefs.getString('currentBandId'), bandId);
    await app.dispose(tester);
  });

  testWidgets('band admins add people of the organization to the band', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'}, user: _ann);
    app.backend.addBand('b1', 'Rock', admin: _ann, organizationId: 'o1');
    app.backend.addOrgMember('o1', _bob, BandRole.member);
    await tester.pumpWidget(app.build(home: const BandsScreen()));
    await tester.pumpAndSettle();

    // The organization (same name, created with the band) comes first.
    await tester.tap(find.text('Rock').last);
    await tester.pumpAndSettle();
    expect(find.text('Ann (you)'), findsOneWidget);
    await tester.tap(find.byKey(const Key('band-add-member')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bob'));
    await tester.pumpAndSettle();

    expect(find.text('Bob'), findsOneWidget);
    expect(
      app.backend.members.where((m) => m.scopeId == 'b1').map((m) => m.user.id),
      unorderedEquals(['ann', 'bob']),
    );
    await app.dispose(tester);
  });

  testWidgets('the last admin cannot step down', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'}, user: _ann);
    app.backend.addBand('b1', 'Rock', admin: _ann, organizationId: 'o1');
    await tester.pumpWidget(app.build(home: const BandsScreen()));
    await tester.pumpAndSettle();
    // The organization (same name, created with the band) comes first.
    await tester.tap(find.text('Rock').last);
    await tester.pumpAndSettle();

    final own = app.backend.members.single;
    await tester.tap(find.byKey(Key('member-menu-${own.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Make member'));
    await tester.pumpAndSettle();
    expect(find.text('A band needs at least one admin.'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('leaving an organization removes its bands', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'}, user: _bob);
    app.backend.addBand('b1', 'Rock', admin: _ann, organizationId: 'o1');
    app.backend.organizations['o1'] = 'School';
    app.backend.addMember('b1', _bob, BandRole.member);
    await tester.pumpWidget(app.build(home: const BandsScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('School'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('org-leave')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Leave organization'));
    await tester.pumpAndSettle();

    expect(find.text('Rock'), findsNothing);
    expect(app.backend.orgMembers.where((m) => m.user.id == 'bob'), isEmpty);
    await app.dispose(tester);
  });

  testWidgets('members who may edit songs cannot delete them', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(
      prefs: {'language': 'en', 'currentBandId': 'b1'},
      user: _bob,
    );
    app.backend.addBand(
      'b1',
      'Rock',
      admin: _ann,
      organizationId: 'o1',
      membersCanEditSongs: true,
    );
    app.backend.addMember('b1', _bob, BandRole.member);
    final orgSongs = TestApp.songsIn(app, 'o1');
    final id = await orgSongs.createSong(source: '{title: Shared}\n[C]x');
    await tester.pumpWidget(app.build(home: SongScreen(songId: id)));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Edit ChordPro'), findsOneWidget);
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    expect(find.text('Copy to band'), findsOneWidget);
    expect(find.text('Delete'), findsNothing);
    await app.dispose(tester);
  });
}

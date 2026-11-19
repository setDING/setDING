import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setding/data/database.dart' show localBandId;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:setding/providers.dart';
import 'package:setding/sync/sync_backend.dart';
import 'package:setding/ui/bands/bands_screen.dart';
import 'package:setding/ui/live/live_play_button.dart';
import 'package:setding/ui/songs/song_screen.dart';
import 'package:setding/ui/songs/songs_screen.dart';

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

  Future<void> switchLibrary(WidgetTester tester, String library) async {
    await tester.tap(find.byKey(const Key('library-switcher')).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(library).last);
    await tester.pumpAndSettle();
  }

  testWidgets('signed out, the app looks like the single-device MVP', (
    tester,
  ) async {
    final app = await start(tester);
    await openSongs(tester);
    expect(find.byKey(const Key('library-switcher')), findsNothing);
    expect(find.text('New song'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('the songs tab switches libraries, not bands', (tester) async {
    final app = await start(
      tester,
      user: _ann,
      server: (app) {
        app.backend.addOrganization('o1', 'School', admin: _ann);
        app.backend.addBand('b1', 'Rock', admin: _ann, organizationId: 'o1');
        app.backend.addBand('b2', 'Jazz', admin: _ann, organizationId: 'o1');
      },
    );
    await app.songs.createSong(source: '{title: Local song}');
    await openSongs(tester);
    expect(find.text('Local song'), findsOneWidget);
    expect(find.byKey(const Key('band-switcher')), findsNothing);

    // One entry per organization, no bands.
    await tester.tap(find.byKey(const Key('library-switcher')));
    await tester.pumpAndSettle();
    expect(find.text('School'), findsOneWidget);
    expect(find.text('Rock'), findsNothing);
    expect(find.text('Jazz'), findsNothing);
    await tester.tap(find.text('School').last);
    await tester.pumpAndSettle();
    expect(find.text('Local song'), findsNothing);
    expect(app.prefs.getString('currentLibraryId'), 'o1');
    // The band stays as it was.
    expect(app.prefs.getString('currentBandId'), isNull);

    await switchLibrary(tester, 'On this device');
    expect(find.text('Local song'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('the band and the song library are chosen independently', (
    tester,
  ) async {
    final app = await start(
      tester,
      user: _ann,
      server: (app) =>
          app.backend.addBand('b1', 'Rock', admin: _ann, organizationId: 'o1'),
    );
    await app.songs.createSong(source: '{title: Local song}');
    await TestApp.songsIn(app, 'o1').createSong(source: '{title: Org song}');

    // Without a choice, the songs tab follows the band.
    await switchTo(tester, 'Rock');
    await openSongs(tester);
    expect(find.text('Org song'), findsOneWidget);

    await switchLibrary(tester, 'On this device');
    expect(find.text('Local song'), findsOneWidget);
    expect(find.text('Org song'), findsNothing);
    expect(app.prefs.getString('currentBandId'), 'b1');

    // Switching the band keeps the chosen library.
    await tester.tap(find.text('Sets').first);
    await tester.pumpAndSettle();
    await switchTo(tester, 'On this device');
    await switchTo(tester, 'Rock');
    await openSongs(tester);
    expect(find.text('Local song'), findsOneWidget);
    expect(app.prefs.getString('currentLibraryId'), localBandId);

    // Sets pick their songs from the band's library.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SongsScreen)),
    );
    final picker = container.listen(bandSongsProvider(''), (_, _) {});
    await tester.runAsync(() => container.read(bandSongsProvider('').future));
    expect(picker.read().value!.map((s) => s.title), ['Org song']);
    picker.close();
    await app.dispose(tester);
  });

  testWidgets('an organization without own bands is a song library', (
    tester,
  ) async {
    final app = await start(
      tester,
      user: _ann,
      server: (app) {
        app.backend.addOrganization('o2', 'Choir', admin: _bob);
        app.backend.addOrgMember('o2', _ann, OrgRole.member);
      },
    );
    await TestApp.songsIn(app, 'o2').createSong(source: '{title: Hymn}');
    await openSongs(tester);
    await switchLibrary(tester, 'Choir');
    expect(find.text('Hymn'), findsOneWidget);
    // Plain organization members may not edit songs.
    expect(find.text('New song'), findsNothing);
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

    await switchLibrary(tester, 'Rock');
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

  testWidgets('invite-only server: bands only in own organizations', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'}, user: _ann);
    app.backend.config = const ServerConfig(
      registration: RegistrationMode.inviteOnly,
    );
    await tester.pumpWidget(app.build(home: const BandsScreen()));
    await tester.pumpAndSettle();
    // No organization to administer: no new band (ADR-0024).
    expect(find.byKey(const Key('band-new')), findsNothing);
    await app.dispose(tester);

    final admin = await TestApp.create(prefs: {'language': 'en'}, user: _ann);
    admin.backend.config = const ServerConfig(
      registration: RegistrationMode.inviteOnly,
    );
    admin.backend.addBand('b1', 'Rock', admin: _ann, organizationId: 'o1');
    await tester.pumpWidget(admin.build(home: const BandsScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('band-new')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('band-new-org')));
    await tester.pumpAndSettle();
    expect(find.text('New organization'), findsNothing);
    await admin.dispose(tester);
  });

  testWidgets('band admins add people of the organization to the band', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'}, user: _ann);
    app.backend.addBand('b1', 'Rock', admin: _ann, organizationId: 'o1');
    app.backend.addOrgMember('o1', _bob, OrgRole.member);
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

  testWidgets('organization admins create bands on the organization screen', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'}, user: _ann);
    app.backend.addOrganization('o1', 'School', admin: _ann);
    app.backend.addBand('b1', 'Rock', admin: _ann, organizationId: 'o1');
    await tester.pumpWidget(app.build(home: const BandsScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('School'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('org-band-new')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), ' Jazz ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final jazz = app.backend.bands.values.singleWhere((b) => b.name == 'Jazz');
    expect(jazz.organizationId, 'o1');
    // The new band opens, with Ann as its first admin.
    expect(find.text('Ann (you)'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Jazz'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('organization members cannot create bands there', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'}, user: _bob);
    app.backend.addOrganization('o1', 'School', admin: _ann);
    app.backend.addOrgMember('o1', _bob, OrgRole.member);
    await tester.pumpWidget(app.build(home: const BandsScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('School'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('org-band-new')), findsNothing);
    await app.dispose(tester);
  });

  testWidgets('opening an organization or a band shows who joined meanwhile', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'}, user: _ann);
    app.backend.addOrganization('o1', 'School', admin: _ann);
    app.backend.addBand('b1', 'Rock', admin: _ann, organizationId: 'o1');
    await tester.pumpWidget(app.build(home: const BandsScreen()));
    await tester.pumpAndSettle();

    // Bob joins with an invitation while Ann's app shows the band list;
    // no sync runs (widget tests sync only explicitly).
    app.backend.addOrgMember('o1', _bob, OrgRole.member);
    app.backend.addMember('b1', _bob, BandRole.member);

    await tester.tap(find.text('School'));
    await tester.pumpAndSettle();
    expect(find.text('Bob'), findsOneWidget);
    await tester.tap(find.text('Rock'));
    await tester.pumpAndSettle();
    expect(find.text('Bob'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('pulling down on an organization reloads its people', (
    tester,
  ) async {
    const cara = AuthUser(id: 'cara', email: 'cara@example.test', name: 'Cara');
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'}, user: _ann);
    app.backend.addOrganization('o1', 'School', admin: _ann);
    await tester.pumpWidget(app.build(home: const BandsScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('School'));
    await tester.pumpAndSettle();
    expect(find.text('Cara'), findsNothing);

    app.backend.addOrgMember('o1', cara, OrgRole.member);
    await tester.fling(find.text('Ann (you)'), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();
    expect(find.text('Cara'), findsOneWidget);
    await app.dispose(tester);
  });

  group('roles of ADR-0023', () {
    const cara = AuthUser(id: 'cara', email: 'cara@example.test', name: 'Cara');

    testWidgets('leaders give band roles and invite into their band', (
      tester,
    ) async {
      useTabletSize(tester);
      final app = await TestApp.create(prefs: {'language': 'en'}, user: _bob);
      // Cara administers the organization; Bob leads its band.
      app.backend.addOrganization('o1', 'School', admin: cara);
      app.backend.addBand('b1', 'Rock', admin: _bob, organizationId: 'o1');
      final ann = app.backend.addMember('b1', _ann, BandRole.member);
      await tester.pumpWidget(app.build(home: const BandsScreen()));
      await tester.pumpAndSettle();
      expect(find.text('School'), findsOneWidget);
      expect(find.text('Member'), findsOneWidget); // Bob in the organization
      await tester.tap(find.text('Rock'));
      await tester.pumpAndSettle();
      expect(find.text('Leader'), findsOneWidget);

      await tester.tap(find.byKey(Key('member-menu-${ann.id}')));
      await tester.pumpAndSettle();
      expect(find.text('Make leader'), findsOneWidget);
      await tester.tap(find.text('Make set planner'));
      await tester.pumpAndSettle();
      expect(ann.role, BandRole.planner);
      expect(find.text('Set planner'), findsOneWidget);

      await tester.tap(find.byKey(const Key('invite-create')));
      await tester.pumpAndSettle();
      expect(app.backend.invites.single.bandId, 'b1');
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      await app.dispose(tester);
    });

    testWidgets('organization admins make librarians', (tester) async {
      useTabletSize(tester);
      final app = await TestApp.create(prefs: {'language': 'en'}, user: _ann);
      app.backend.addBand('b1', 'Rock', admin: _ann, organizationId: 'o1');
      final bob = app.backend.addOrgMember('o1', _bob, OrgRole.member);
      await tester.pumpWidget(app.build(home: const BandsScreen()));
      await tester.pumpAndSettle();
      // The organization (same name, created with the band) comes first.
      await tester.tap(find.text('Rock').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('person-menu-${bob.id}')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Make librarian'));
      await tester.pumpAndSettle();
      expect(bob.role, OrgRole.librarian);
      expect(find.text('Librarian'), findsOneWidget);
      await app.dispose(tester);
    });

    testWidgets('leaders do not edit songs of others', (tester) async {
      useTabletSize(tester);
      final app = await TestApp.create(
        prefs: {'language': 'en', 'currentBandId': 'b1'},
        user: _bob,
      );
      app.backend.addBand('b1', 'Rock', admin: _ann, organizationId: 'o1');
      app.backend.addMember('b1', _bob, BandRole.admin);
      final id = await TestApp.songsIn(
        app,
        'o1',
        userId: 'ann',
      ).createSong(source: '{title: Shared}\n[C]x');
      await tester.pumpWidget(app.build(home: SongScreen(songId: id)));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Attachments'), findsNothing);
      expect(find.byKey(const Key('edit-song')), findsNothing);
      expect(find.byKey(const Key('edit-song-divider')), findsNothing);
      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      expect(find.text('Edit ChordPro'), findsNothing);
      await app.dispose(tester);
    });
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

  testWidgets('leaders edit their own songs but cannot delete them', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(
      prefs: {'language': 'en', 'currentBandId': 'b1'},
      user: _bob,
    );
    app.backend.addBand('b1', 'Rock', admin: _ann, organizationId: 'o1');
    app.backend.addMember('b1', _bob, BandRole.admin);
    // Created by Bob on this device (ADR-0023).
    final orgSongs = TestApp.songsIn(app, 'o1', userId: 'bob');
    final id = await orgSongs.createSong(source: '{title: Shared}\n[C]x');
    await tester.pumpWidget(app.build(home: SongScreen(songId: id)));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Attachments'));
    await tester.pumpAndSettle();
    expect(find.text('Attach file'), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('edit-song')), findsOneWidget);
    expect(find.byKey(const Key('edit-song-divider')), findsOneWidget);
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    expect(find.text('Copy to band'), findsOneWidget);
    expect(find.text('Delete'), findsNothing);
    await app.dispose(tester);
  });

  testWidgets('members without edit rights see no edit buttons on a song', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(
      prefs: {'language': 'en', 'currentBandId': 'b1'},
      user: _bob,
    );
    app.backend.addBand('b1', 'Rock', admin: _ann, organizationId: 'o1');
    app.backend.addMember('b1', _bob, BandRole.member);
    final orgSongs = TestApp.songsIn(app, 'o1');
    final id = await orgSongs.createSong(source: '{title: Shared}\n[C]x');
    await tester.pumpWidget(app.build(home: SongScreen(songId: id)));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Play live'), findsOneWidget);
    // The live button is the last action of the app bar (#444).
    expect(
      tester.widget<AppBar>(find.byType(AppBar)).actions!.last,
      isA<LivePlayButton>(),
    );
    expect(find.byTooltip('Attachments'), findsNothing);
    // Neither the pencil nor its divider (#600).
    expect(find.byKey(const Key('edit-song')), findsNothing);
    expect(find.byKey(const Key('edit-song-divider')), findsNothing);
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    expect(find.text('Edit ChordPro'), findsNothing);
    await app.dispose(tester);
  });
}

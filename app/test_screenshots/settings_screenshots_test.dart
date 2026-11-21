// Screenshots of the organization, band and settings screens.
// See screenshot_support.dart.

import 'package:setding/ui/bands/band_screen.dart';
import 'package:setding/ui/bands/organization_screen.dart';
import 'package:setding/ui/settings_screen.dart';
import 'package:setding/sync/sync_backend.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/test_app.dart';

import 'screenshot_support.dart';

void main() {
  setUpScreenshots();

  // Organization, band and invitation screens for the user documentation
  // (website, ADR-0030), signed in as the organization admin.
  for (final (lang, dark) in [('de', false), ('en', true)]) {
    screenshotTest('organization and band $lang', (tester) async {
      useTabletSize(tester);
      const ann = AuthUser(
        id: 'ann',
        email: 'ann@example.test',
        name: 'Ann Keller',
      );
      const people = [
        AuthUser(id: 'ben', email: 'ben@example.test', name: 'Ben Frei'),
        AuthUser(id: 'cara', email: 'cara@example.test', name: 'Cara Meier'),
        AuthUser(id: 'dan', email: 'dan@example.test', name: 'Dan Huber'),
        AuthUser(id: 'eva', email: 'eva@example.test', name: 'Eva Graf'),
      ];
      final app = await TestApp.create(
        prefs: {'language': lang, 'themeMode': dark ? 'dark' : 'light'},
        user: ann,
      );
      final school = lang == 'de' ? 'Musikschule Bern' : 'Music School';
      app.backend.addOrganization('o1', school, admin: ann);
      app.backend.addBand('b1', 'Rock Band', admin: ann, organizationId: 'o1');
      app.backend.addBand('b2', 'Jazz Combo', admin: ann, organizationId: 'o1');
      app.backend.addOrgMember('o1', people[0], OrgRole.librarian);
      app.backend.addMember('b1', people[1], BandRole.planner);
      app.backend.addMember('b1', people[2], BandRole.member);
      app.backend.addMember('b2', people[3], BandRole.member);

      await tester.pumpWidget(
        RepaintBoundary(
          key: UniqueKey(),
          child: app.build(
            home: const OrganizationScreen(organizationId: 'o1'),
          ),
        ),
      );
      await shot(tester, '${lang}_12_organization');

      // The invitation button is below the people.
      await tester.scrollUntilVisible(
        find.byKey(const Key('invite-create')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('invite-create')));
      await tester.pumpAndSettle();
      await shot(tester, '${lang}_13_invite');

      await tester.pumpWidget(
        RepaintBoundary(
          key: UniqueKey(),
          child: app.build(home: const BandScreen(bandId: 'b1')),
        ),
      );
      await shot(tester, '${lang}_14_band');

      await tester.pumpWidget(
        RepaintBoundary(
          key: UniqueKey(),
          child: app.build(home: const SettingsScreen()),
        ),
      );
      await shot(tester, '${lang}_15_settings');
      // The musician settings: instrument, voice, diagrams, beat.
      await tester.tap(find.text(lang == 'de' ? 'Musiker' : 'Musician'));
      await shot(tester, '${lang}_16_settings_musician');
      // On a wide screen the sections flow into two columns (#774).
      tester.view.physicalSize = const Size(1680, 900);
      await tester.tap(find.byKey(const Key('settings-category-general')));
      await shot(tester, '${lang}_18_settings_general');
      useTabletSize(tester);
      await tester.pumpAndSettle();
      // Song display styles (ADR-0033) with a preset of colours.
      await tester.tap(find.byKey(const Key('settings-category-songDisplay')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('song-display-preset-colorCoded')));
      await shot(tester, '${lang}_20_settings_song_display');
      // The editor: controls next to the preview (#478).
      await tester.tap(find.byKey(const Key('song-display-customise')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('song-display-type-chorus')));
      await shot(tester, '${lang}_21_song_display_editor');
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      // Not every category fits on a landscape tablet.
      final live = find.byKey(const Key('settings-category-live'));
      await tester.ensureVisible(live);
      await tester.pumpAndSettle();
      await tester.tap(live);
      await shot(tester, '${lang}_19_settings_live');
      await app.dispose(tester);
    });
  }
}

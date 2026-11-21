import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/ui/settings/settings_layout.dart';
import 'package:setding/ui/settings_screen.dart';

import 'test_app.dart';

/// The layout rules of the settings categories (ADR-0050): every option is
/// in a titled section and has a leading icon, on a phone without overflow.
/// A new setting that does not follow them fails here.
void main() {
  // The categories with settings; the account and the organizations and
  // bands list the account and its organizations instead.
  const exempt = {SettingsCategory.account, SettingsCategory.bands};

  // Every option shown: drums with the click (edge flash, song map, the
  // click's details and its device settings) and developer mode (test
  // features), and a keyboard with MIDI on (its category).
  final setups = <String, Map<String, Object>>{
    'drums': {'instrument': 'drums', 'click': true, 'developerMode': true},
    'keyboard': {'instrument': 'keyboard', 'midiEnabled': true},
  };

  for (final MapEntry(key: name, value: prefs) in setups.entries) {
    testWidgets('$name: every option is in a section and has an icon', (
      tester,
    ) async {
      // A phone: the narrowest layout, each category on its own page.
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final app = await TestApp.create(prefs: {'language': 'de', ...prefs});
      await tester.pumpWidget(app.build(home: const SettingsScreen()));
      await tester.pumpAndSettle();

      final categories = [
        for (final c in SettingsCategory.values)
          if (!exempt.contains(c) &&
              (c != SettingsCategory.development || name == 'drums') &&
              (c != SettingsCategory.midi || name == 'keyboard'))
            c,
      ];

      for (final category in categories) {
        await openSettingsCategory(tester, category);
        // The tiles of the opened page, not of the category list.
        final tiles = find.byType(ListTile);
        final inList = find.descendant(
          of: find.byType(SettingsScreen),
          matching: find.byType(ListTile),
        );
        final listed = inList.evaluate().toSet();
        final shown = [
          for (final e in tiles.evaluate())
            if (!listed.contains(e)) e,
        ];
        expect(shown, isNotEmpty, reason: '$category');
        expect(
          find.byType(SettingsSection),
          findsWidgets,
          reason: '$category has no section',
        );
        for (final e in shown) {
          final tile = e.widget as ListTile;
          final label = tile.title is Text
              ? (tile.title! as Text).data
              : tile.key.toString();
          expect(
            tile.leading,
            isNotNull,
            reason: '$category: "$label" has no icon',
          );
          var inSection = false;
          var note = false;
          e.visitAncestorElements((a) {
            if (a.widget is SettingsSection) inSection = true;
            if (a.widget.key == const Key('settings-experimental-note')) {
              note = true;
            }
            return !inSection && !note;
          });
          expect(
            inSection || note,
            isTrue,
            reason: '$category: "$label" is not in a section',
          );
        }
        tester.state<NavigatorState>(find.byType(Navigator).last).pop();
        await tester.pumpAndSettle();
      }
      await app.dispose(tester);
    });
  }
}

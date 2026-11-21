import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/data/database.dart';
import 'package:setding/data/marker_icons.dart';
import 'package:setding/l10n/generated/app_localizations.dart';
import 'package:setding/ui/live/live_screen.dart';
import 'package:setding/ui/sets/set_item_label.dart';
import 'package:setding/ui/sets/set_screen.dart';

import 'test_app.dart';

/// The *Add marker* dialog with an icon and a text (ADR-0047).
void main() {
  final de = lookupAppLocalizations(const Locale('de'));
  final en = lookupAppLocalizations(const Locale('en'));

  Future<(TestApp, String)> openSet(WidgetTester tester, String lang) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': lang});
    final setId = (await tester.runAsync(
      () => app.sets.createSet(name: 'Gig'),
    ))!;
    await tester.pumpWidget(app.build(home: SetScreen(setId: setId)));
    await tester.pumpAndSettle();
    return (app, setId);
  }

  Future<void> openDialog(WidgetTester tester, AppLocalizations l10n) async {
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.addMarker));
    await tester.pumpAndSettle();
  }

  String fieldText(WidgetTester tester) => tester
      .widget<TextField>(find.byKey(const ValueKey('marker-text')))
      .controller!
      .text;

  Future<void> save(WidgetTester tester, AppLocalizations l10n) async {
    await tester.tap(find.text(l10n.save));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
  }

  Future<List<SetItemEntry>> items(
    WidgetTester tester,
    TestApp app,
    String setId,
  ) async => [
    for (final v in (await tester.runAsync(() => app.sets.getItems(setId)))!)
      v.item,
  ];

  testWidgets('one command adds a marker; the text follows the icon until '
      'it is changed', (tester) async {
    final (app, setId) = await openSet(tester, 'de');
    // The old commands are gone.
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    expect(find.text('Pause hinzufügen'), findsNothing);
    expect(find.text('Text hinzufügen'), findsNothing);
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();

    await openDialog(tester, de);
    expect(find.text(de.addMarker), findsWidgets);
    // A break by default, prefilled with its name.
    expect(fieldText(tester), 'Pause');
    await tester.tap(find.byKey(const ValueKey('marker-icon-encore')));
    await tester.pumpAndSettle();
    expect(fieldText(tester), 'Zugabe');
    // The preview shows the name.
    expect(find.text('Zugabe'), findsWidgets);

    // A text of its own stays when another icon is chosen.
    await tester.enterText(
      find.byKey(const ValueKey('marker-text')),
      'Zugabe: Last Call',
    );
    await tester.tap(find.byKey(const ValueKey('marker-icon-light')));
    await tester.pumpAndSettle();
    expect(fieldText(tester), 'Zugabe: Last Call');
    await save(tester, de);

    // The default name is stored empty, so every member sees it in their
    // own language.
    await openDialog(tester, de);
    await tester.tap(find.byKey(const ValueKey('marker-icon-encore')));
    await tester.pumpAndSettle();
    await save(tester, de);

    expect(
      [for (final i in await items(tester, app, setId)) (i.icon, i.note)],
      [(MarkerIcons.light, 'Zugabe: Last Call'), (MarkerIcons.encore, '')],
    );
    // The set editor shows the icon and the title.
    expect(find.byIcon(markerIconData(MarkerIcons.light)), findsOneWidget);
    expect(find.byIcon(markerIconData(MarkerIcons.encore)), findsOneWidget);
    expect(find.text('Zugabe'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('the text is limited to 24 characters', (tester) async {
    final (app, setId) = await openSet(tester, 'en');
    await openDialog(tester, en);
    await tester.enterText(
      find.byKey(const ValueKey('marker-text')),
      'A very long announcement for the audience',
    );
    await tester.pumpAndSettle();
    expect(fieldText(tester), hasLength(MarkerIcons.maxTextLength));
    await save(tester, en);
    expect(
      (await items(tester, app, setId)).single.note,
      'A very long announcement',
    );
    await app.dispose(tester);
  });

  testWidgets('editing a marker changes its icon and text', (tester) async {
    final (app, setId) = await openSet(tester, 'en');
    await tester.runAsync(
      () => app.sets.addMarker(setId, MarkerIcons.breakIcon, 'Coffee'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Coffee'), findsOneWidget);
    expect(find.text('Break'), findsNothing); // no icon name below the text
    await tester.tap(find.text('Coffee'));
    await tester.pumpAndSettle();
    expect(find.text(en.editMarker), findsOneWidget);
    expect(fieldText(tester), 'Coffee');
    await tester.tap(find.byKey(const ValueKey('marker-icon-drinks')));
    await tester.pumpAndSettle();
    expect(fieldText(tester), 'Coffee');
    await tester.enterText(find.byKey(const ValueKey('marker-text')), '');
    await save(tester, en);
    final item = (await items(tester, app, setId)).single;
    expect((item.icon, item.note), (MarkerIcons.drinks, ''));
    expect(find.text('Drinks'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('live mode shows the marker with its icon', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    await tester.pumpWidget(
      app.build(
        home: const LiveScreen(
          items: [LiveItem.marker(MarkerIcons.encore, '')],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(markerIconData(MarkerIcons.encore)), findsOneWidget);
    expect(find.text('Encore'), findsOneWidget);
    await app.dispose(tester);
  });
}

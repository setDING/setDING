import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/sync/sync_backend.dart';
import 'package:setding/ui/bands/band_screen.dart';
import 'package:setding/ui/bands/organization_screen.dart';
import 'package:setding/ui/settings/midi_test_screen.dart';
import 'package:setding/ui/widgets/page_width.dart';

import 'test_app.dart';

const _ann = AuthUser(id: 'ann', email: 'ann@example.test', name: 'Ann');

/// Pages of tiles limit their content to [pageMaxWidth] on large screens
/// (docs/development/ui-design.md, "Layout and spacing", #770).
void main() {
  testWidgets('PageWidth limits wide screens and keeps narrow ones', (
    tester,
  ) async {
    Future<double> widthOn(double screen) async {
      tester.view.physicalSize = Size(screen, 800);
      tester.view.devicePixelRatio = 1.0;
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: PageWidth(child: SizedBox.expand(key: Key('content'))),
        ),
      );
      return tester.getSize(find.byKey(const Key('content'))).width;
    }

    addTearDown(tester.view.reset);
    expect(await widthOn(1280), pageMaxWidth);
    expect(await widthOn(400), 400);
  });

  /// The widest list tile on the screen.
  double widestTile(WidgetTester tester) => find
      .byType(ListTile)
      .evaluate()
      .map((e) => tester.getSize(find.byWidget(e.widget)).width)
      .reduce((a, b) => a > b ? a : b);

  Future<TestApp> pump(WidgetTester tester, Widget home) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'}, user: _ann);
    app.backend.addBand('b1', 'Rock', admin: _ann, organizationId: 'o1');
    app.backend.organizations['o1'] = 'School';
    await tester.pumpWidget(app.build(home: home));
    await tester.pumpAndSettle();
    return app;
  }

  for (final (name, home) in [
    ('organization', const OrganizationScreen(organizationId: 'o1')),
    ('band', const BandScreen(bandId: 'b1')),
    ('MIDI test', const MidiTestScreen()),
  ]) {
    testWidgets('the $name page is limited on a wide screen', (tester) async {
      final app = await pump(tester, home);
      expect(find.byType(PageWidth), findsOneWidget);
      expect(find.byType(ListTile), findsWidgets);
      expect(widestTile(tester), lessThanOrEqualTo(pageMaxWidth));
      await app.dispose(tester);
    });
  }
}

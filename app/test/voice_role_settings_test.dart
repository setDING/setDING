import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/l10n/generated/app_localizations.dart';
import 'package:setding/ui/settings_screen.dart';

import 'test_app.dart';

/// The optional voice or role for conditional parts (ADR-0012, #939).
void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final de = lookupAppLocalizations(const Locale('de'));

  test('an instrument entered as voice is recognised', () {
    expect(voiceIsInstrument(en, 'bass'), isTrue);
    expect(voiceIsInstrument(en, ' Bass '), isTrue);
    expect(voiceIsInstrument(de, 'Gesang'), isTrue);
    expect(voiceIsInstrument(de, 'drums'), isTrue);
    expect(voiceIsInstrument(en, 'alto'), isFalse);
    expect(voiceIsInstrument(en, 'Ann'), isFalse);
    expect(voiceIsInstrument(en, ''), isFalse);
  });

  Future<void> showMusician(WidgetTester tester, String voice) async {
    useTabletSize(tester);
    final app = await TestApp.create(
      prefs: {'language': 'en', 'instrument': 'guitar', 'userName': voice},
    );
    await tester.pumpWidget(app.build(home: const SettingsScreen()));
    await tester.pumpAndSettle();
    await tapSettingsCategory(tester, 'musician');
  }

  testWidgets('an instrument as voice shows a hint', (tester) async {
    await showMusician(tester, 'bass');
    expect(find.text(en.settingsUserName), findsOneWidget);
    expect(find.text(en.settingsUserNameIsInstrument('bass')), findsOneWidget);
  });

  testWidgets('a real voice shows no hint', (tester) async {
    await showMusician(tester, 'alto');
    expect(find.text('alto'), findsOneWidget);
    expect(find.textContaining('is an instrument'), findsNothing);
  });
}

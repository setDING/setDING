import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/l10n/generated/app_localizations.dart';
import 'package:setding/platform/input_devices.dart';
import 'package:setding/ui/home_tab.dart';
import 'package:setding/ui/live/page_turner.dart';
import 'package:setding/ui/sets/set_screen.dart';
import 'package:setding/ui/settings_screen.dart';

import 'test_app.dart';

/// The overview's readiness tile (#911): warnings always, the rest folded
/// into one line, and each line leads to what fixes it.
void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  final card = find.byKey(const Key('overview-readiness'));
  final details = find.byKey(const Key('overview-readiness-details'));
  Finder line(String check) =>
      find.byKey(ValueKey('overview-readiness-$check'));

  void usePhoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  /// MIDI on for a keyboard that is not plugged in (ADR-0039).
  const midiNotConnected = <String, Object>{
    'language': 'en',
    'instrument': 'keyboard',
    'midiEnabled': true,
    'midiOutputName': 'Nord Stage 3 MIDI',
  };

  Future<void> showDetails(WidgetTester tester) async {
    await tester.ensureVisible(details);
    await tester.tap(details);
    await tester.pumpAndSettle();
  }

  testWidgets('all ok: one line, the details on request', (tester) async {
    usePhoneSize(tester);
    final app = await TestApp.create(
      prefs: {'language': 'en', 'userName': 'Ann'},
    );
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();

    expect(card, findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.text(l10n.readinessAllSetNoSet)),
      findsOneWidget,
    );
    expect(line('musician'), findsNothing);

    await showDetails(tester);
    expect(find.byKey(const Key('overview-readiness-all-set')), findsNothing);
    expect(
      find.descendant(
        of: line('musician'),
        matching: find.text('Musician: Guitar · Ann'),
      ),
      findsOneWidget,
    );
    // Not signed in, no MIDI, no next set, no automatic backup, and no
    // page turner used on this device (#930).
    for (final check in ['midi', 'offline', 'sync', 'backup', 'pageTurner']) {
      expect(line(check), findsNothing, reason: check);
    }

    await tester.tap(details);
    await tester.pumpAndSettle();
    expect(line('musician'), findsNothing);
    await app.dispose(tester);
  });

  testWidgets('a warning is always shown and leads to its setting', (
    tester,
  ) async {
    usePhoneSize(tester);
    final app = await TestApp.create(prefs: midiNotConnected);
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: line('midi'),
        matching: find.text(l10n.readinessMidiNotConnected),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('overview-readiness-all-set')), findsNothing);
    // The others stay folded.
    expect(line('musician'), findsNothing);

    await tester.tap(line('midi'));
    await tester.pumpAndSettle();
    // Narrow: the settings tab with the MIDI category as its own page.
    expect(find.widgetWithText(AppBar, l10n.settingsSectionMidi), findsOne);
    Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, l10n.navSettings), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('on wide screens the category is selected next to the list', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: midiNotConnected);
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();

    await tester.tap(line('midi'));
    await tester.pumpAndSettle();
    final midi = tester.widget<ListTile>(
      find.byKey(Key('settings-category-${SettingsCategory.midi.name}')),
    );
    expect(midi.selected, isTrue);
    expect(find.widgetWithText(AppBar, l10n.settingsSectionMidi), findsNothing);
    await app.dispose(tester);
  });

  testWidgets('the page turner responds to the test on the overview only', (
    tester,
  ) async {
    usePhoneSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    // Where pairing is not possible (web, Linux); on Android and Windows
    // the line asks to pair the page turner instead (#928).
    app.inputDevices.support = InputDeviceSupport.none;
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    await showDetails(tester);
    // No page turner used here yet (#930): no line until one is pressed.
    expect(line('pageTurner'), findsNothing);

    // On another tab the key is not a test.
    await openTab(tester, HomeTab.sets);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await openTab(tester, HomeTab.overview);
    expect(line('pageTurner'), findsNothing);
    expect(app.prefs.getString(PageTurnerNotifier.lastUsedKey), isNull);

    // Page Down, which has no page scroll on the overview to fail.
    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: line('pageTurner'),
        matching: find.text(l10n.readinessPageTurnerResponds),
      ),
      findsOneWidget,
    );
    expect(app.prefs.getString(PageTurnerNotifier.lastUsedKey), isNotNull);
    await app.dispose(tester);
  });

  testWidgets('the next set offline; a tap opens it', (tester) async {
    usePhoneSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    await tester.runAsync(() async {
      final song = await app.songs.createSong(source: '{title: One}\n[C]La');
      final now = DateTime.now();
      final next = await app.sets.createSet(
        name: 'Gig',
        gigDate: DateTime(now.year, now.month, now.day + 2),
      );
      await app.sets.addSongs(next, [song]);
    });
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: card, matching: find.text('All set for “Gig”')),
      findsOneWidget,
    );
    await showDetails(tester);
    expect(
      find.descendant(
        of: line('offline'),
        matching: find.text(l10n.readinessOfflineReady),
      ),
      findsOneWidget,
    );
    await tester.ensureVisible(line('offline'));
    await tester.tap(line('offline'));
    await tester.pumpAndSettle();
    expect(find.byType(SetScreen), findsOneWidget);
    await app.dispose(tester);
  });
}

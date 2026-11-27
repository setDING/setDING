import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/l10n/generated/app_localizations.dart';
import 'package:setding/platform/input_devices.dart';
import 'package:setding/settings/settings.dart';
import 'package:setding/ui/home_tab.dart';
import 'package:setding/ui/live/page_turner.dart';
import 'package:setding/ui/overview/readiness.dart';
import 'package:setding/ui/widgets/dialogs.dart' show messageActionDuration;

import 'test_app.dart';

/// Pairing the page turner and detecting its connection (ADR-0057, #913).
void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  const pedal = InputDeviceInfo(
    name: 'AirTurn DUO',
    vendorId: 0x1234,
    productId: 0x5678,
  );

  group('matching', () {
    test('with IDs, vendor and product alone', () {
      expect(pedal.matches(pedal), isTrue);
      expect(
        const InputDeviceInfo(
          name: 'AirTurn DUO',
          vendorId: 0x1234,
          productId: 0x9999,
        ).matches(pedal),
        isFalse,
      );
      // A firmware update changes the name (an AirTurn DUO500 reports
      // "DUO500 v3.0.13 6887"); the second device of the same page turner
      // matches too.
      expect(
        const InputDeviceInfo(
          name: 'DUO500 v3.1.0 7001',
          vendorId: 0x0122,
          productId: 0x000d,
        ).matches(
          const InputDeviceInfo(
            name: 'DUO500 v3.0.13 6887',
            vendorId: 0x0122,
            productId: 0x000d,
          ),
        ),
        isTrue,
      );
    });

    test('without IDs, the name alone', () {
      const generic = InputDeviceInfo(name: 'BT Keyboard');
      expect(generic.matches(generic), isTrue);
      // IDs on one side only: the name.
      expect(
        const InputDeviceInfo(
          name: 'BT Keyboard',
          vendorId: 1,
          productId: 2,
        ).matches(generic),
        isTrue,
      );
      expect(const InputDeviceInfo(name: 'Other').matches(generic), isFalse);
    });

    test('from the platform channel', () {
      expect(
        InputDeviceInfo.fromMap({
          'name': ' AirTurn DUO ',
          'vendorId': 0x1234,
          'productId': 0x5678,
        }),
        pedal,
      );
      expect(InputDeviceInfo.fromMap({}), const InputDeviceInfo(name: ''));
    });
  });

  test('the connection per platform support', () {
    PageTurnerConnection of(
      InputDeviceSupport support,
      InputDeviceInfo? paired,
      List<InputDeviceInfo>? connected,
    ) => pageTurnerConnection(
      support: support,
      paired: paired,
      connected: connected,
    );
    const devices = InputDeviceSupport.devices;
    expect(of(devices, pedal, null), PageTurnerConnection.unknown);
    // Not paired (#928), also while the devices are loaded.
    expect(of(devices, null, [pedal]), PageTurnerConnection.notPaired);
    expect(of(devices, null, null), PageTurnerConnection.notPaired);
    expect(of(devices, pedal, [pedal]), PageTurnerConnection.connected);
    expect(of(devices, pedal, []), PageTurnerConnection.notConnected);
    const ios = InputDeviceSupport.keyboardOnly;
    expect(
      of(ios, null, [const InputDeviceInfo(name: '')]),
      PageTurnerConnection.keyboardConnected,
    );
    expect(of(ios, null, []), PageTurnerConnection.noKeyboard);
    expect(
      of(InputDeviceSupport.none, pedal, []),
      PageTurnerConnection.unknown,
    );
  });

  group('readiness line', () {
    String time(DateTime t) => '${t.day}.${t.month}.';
    final at = DateTime(2026, 11, 20);
    ReadinessItem line(
      PageTurnerConnection connection, {
      PageTurnerState state = const PageTurnerState(),
    }) => pageTurnerReadiness(
      l10n,
      time,
      mode: PageTurnMode.full,
      state: state,
      paired: pedal,
      connection: connection,
    );

    test('the paired page turner connected or not', () {
      final connected = line(PageTurnerConnection.connected);
      expect(connected.level, ReadinessLevel.ok);
      expect(connected.title, 'Page turner AirTurn DUO connected');
      final missing = line(PageTurnerConnection.notConnected);
      expect(missing.level, ReadinessLevel.warning);
      expect(missing.title, 'Page turner AirTurn DUO not connected');
      expect(
        line(
          PageTurnerConnection.connected,
          state: PageTurnerState(lastUsed: at, responded: true),
        ).title,
        l10n.readinessPageTurnerResponds,
      );
    });

    test('iOS: a missing keyboard is a warning once one was used', () {
      expect(line(PageTurnerConnection.noKeyboard).level, ReadinessLevel.info);
      final used = line(
        PageTurnerConnection.noKeyboard,
        state: PageTurnerState(lastUsed: at),
      );
      expect(used.level, ReadinessLevel.warning);
      expect(used.title, l10n.readinessKeyboardNotConnected);
      final keyboard = line(PageTurnerConnection.keyboardConnected);
      expect(keyboard.level, ReadinessLevel.ok);
      expect(keyboard.detail, startsWith(l10n.readinessKeyboardConnected));
    });
  });

  /// The live settings with the page turner tile, switching on *I use a
  /// page turner* (#930) when it is off.
  /// Scrolls [finder] to the middle of the settings, clear of the app bar
  /// at the top, however long the page is.
  Future<void> centre(WidgetTester tester, Finder finder) async {
    await tester.runAsync(
      () => Scrollable.ensureVisible(tester.element(finder), alignment: 0.5),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openLiveSettings(WidgetTester tester) async {
    await openTab(tester, HomeTab.settings);
    await tester.tap(find.byKey(const Key('settings-category-live')));
    await tester.pumpAndSettle();
    final tile = find.byKey(const Key('settings-page-turner'));
    if (tile.evaluate().isEmpty) {
      final use = find.byKey(const Key('settings-page-turner-use'));
      await centre(tester, use);
      await tester.tap(use);
      await tester.pumpAndSettle();
    }
    await centre(tester, tile);
  }

  final tile = find.byKey(const Key('settings-page-turner'));

  testWidgets('pairing by a key press, connection, forget with undo', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    await openLiveSettings(tester);
    expect(
      find.descendant(
        of: tile,
        matching: find.text(l10n.settingsPageTurnerNone),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('settings-page-turner-pair')));
    // The dialog spins until a key arrives: no pumpAndSettle while open.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('page-turner-pair-dialog')), findsOneWidget);
    app.inputDevices.press(pedal);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('page-turner-pair-dialog')), findsNothing);
    expect(find.text('Page turner paired: AirTurn DUO'), findsOneWidget);
    expect(
      app.prefs.getString(PairedPageTurnerNotifier.nameKey),
      'AirTurn DUO',
    );
    expect(app.prefs.getInt(PairedPageTurnerNotifier.vendorKey), 0x1234);
    final paired = find.byKey(const Key('settings-page-turner-paired'));
    expect(
      tester.widget<Text>(paired).textSpan!.toPlainText(),
      'AirTurn DUO · not connected',
    );

    app.inputDevices.connect(pedal);
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(paired).textSpan!.toPlainText(),
      'AirTurn DUO · connected',
    );

    await tester.tap(find.byKey(const Key('settings-page-turner-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-page-turner-forget')));
    await tester.pumpAndSettle();
    expect(app.prefs.getString(PairedPageTurnerNotifier.nameKey), isNull);
    expect(
      find.descendant(
        of: tile,
        matching: find.text(l10n.settingsPageTurnerNone),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text(l10n.undo));
    await tester.pumpAndSettle();
    expect(
      app.prefs.getString(PairedPageTurnerNotifier.nameKey),
      'AirTurn DUO',
    );
    expect(paired, findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('cancelling the pairing keeps nothing', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    await openLiveSettings(tester);
    await tester.tap(find.byKey(const Key('settings-page-turner-pair')));
    // The dialog spins until a key arrives: no pumpAndSettle while open.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text(l10n.cancel));
    await tester.pumpAndSettle();
    app.inputDevices.press(pedal);
    await tester.pumpAndSettle();
    expect(app.prefs.getString(PairedPageTurnerNotifier.nameKey), isNull);
    await app.dispose(tester);
  });

  testWidgets('without device information the setting says why', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    app.inputDevices.support = InputDeviceSupport.keyboardOnly;
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    await openLiveSettings(tester);
    expect(
      find.descendant(
        of: tile,
        matching: find.text(l10n.settingsPageTurnerKeyboardOnly),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('settings-page-turner-pair')), findsNothing);
    await app.dispose(tester);
  });

  testWidgets('the overview warns when the paired page turner is missing', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(
      prefs: {
        'language': 'en',
        PairedPageTurnerNotifier.nameKey: pedal.name,
        PairedPageTurnerNotifier.vendorKey: pedal.vendorId,
        PairedPageTurnerNotifier.productKey: pedal.productId,
      },
    );
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    final line = find.byKey(const Key('overview-readiness-pageTurner'));
    expect(
      find.descendant(
        of: line,
        matching: find.text('Page turner AirTurn DUO not connected'),
      ),
      findsOneWidget,
    );

    // Connected: ok, folded into the summary line.
    app.inputDevices.connect(pedal);
    await tester.pumpAndSettle();
    expect(line, findsNothing);
    expect(find.byKey(const Key('overview-readiness-all-set')), findsOneWidget);
    await app.dispose(tester);
  });

  // Regression test for #928: after forgetting the page turner, the
  // overview still said "Page turner responds" from the quick test.
  testWidgets('without a pairing the overview says so, not "responds"', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(
      prefs: {
        'language': 'en',
        PairedPageTurnerNotifier.nameKey: pedal.name,
        PairedPageTurnerNotifier.vendorKey: pedal.vendorId,
        PairedPageTurnerNotifier.productKey: pedal.productId,
      },
    );
    app.inputDevices.connected.add(pedal);
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    // The quick test on the overview.
    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.pumpAndSettle();

    await openLiveSettings(tester);
    await tester.tap(find.byKey(const Key('settings-page-turner-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-page-turner-forget')));
    await tester.pumpAndSettle();

    await openTab(tester, HomeTab.overview);
    final details = find.byKey(const Key('overview-readiness-details'));
    await tester.ensureVisible(details);
    await tester.tap(details);
    await tester.pumpAndSettle();
    final line = find.byKey(const Key('overview-readiness-pageTurner'));
    expect(
      find.descendant(
        of: line,
        matching: find.text(l10n.readinessPageTurnerResponds),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: line,
        matching: find.text(l10n.readinessPageTurnerNotPaired),
      ),
      findsOneWidget,
    );
    await app.dispose(tester);
  });

  group('page turner in use (#930)', () {
    Future<void> pumpOverview(WidgetTester tester, TestApp app) async {
      await tester.pumpWidget(app.build());
      await tester.pumpAndSettle();
    }

    final offer = find.byKey(const Key('page-turner-offer'));

    /// One pedal press: the platform's device event and Flutter's key.
    Future<void> pressPedal(
      WidgetTester tester,
      TestApp app, {
      LogicalKeyboardKey key = LogicalKeyboardKey.pageDown,
    }) async {
      app.inputDevices.press(pedal);
      await tester.sendKeyEvent(key);
      await tester.pump();
    }

    testWidgets('a pedal pressed on the overview is offered for pairing', (
      tester,
    ) async {
      useTabletSize(tester);
      final app = await TestApp.create(prefs: {'language': 'en'});
      await pumpOverview(tester, app);

      await pressPedal(tester, app);
      expect(offer, findsOneWidget);
      expect(find.text('Page turner detected: AirTurn DUO'), findsOneWidget);
      // The message slides in before its action can be tapped.
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('page-turner-offer-pair')));
      await tester.pumpAndSettle();
      expect(find.text('Page turner paired: AirTurn DUO'), findsOneWidget);
      expect(
        app.prefs.getString(PairedPageTurnerNotifier.nameKey),
        'AirTurn DUO',
      );
      expect(app.prefs.getBool(PageTurnerUseNotifier.key), isTrue);

      // The paired one is not offered again.
      await tester.pump(const Duration(seconds: 10));
      await pressPedal(tester, app);
      expect(offer, findsNothing);
      await app.dispose(tester);
    });

    testWidgets('offered once per device; not answering is "not now"', (
      tester,
    ) async {
      useTabletSize(tester);
      final app = await TestApp.create(prefs: {'language': 'en'});
      await pumpOverview(tester, app);
      await pressPedal(tester, app);
      expect(offer, findsOneWidget);
      // The message goes away by itself (ADR-0051); its time starts once
      // it has slid in.
      await tester.pumpAndSettle();
      await tester.pump(messageActionDuration);
      await tester.pumpAndSettle();
      expect(offer, findsNothing);

      await pressPedal(tester, app);
      expect(offer, findsNothing);
      expect(app.prefs.getString(PairedPageTurnerNotifier.nameKey), isNull);

      // Switching "I use a page turner" off and on again asks again (owner
      // test of #930).
      await openLiveSettings(tester);
      final use = find.byKey(const Key('settings-page-turner-use'));
      await centre(tester, use);
      await tester.tap(use);
      await tester.pumpAndSettle();
      await tester.tap(use);
      await tester.pumpAndSettle();
      await openTab(tester, HomeTab.overview);
      await pressPedal(tester, app);
      expect(offer, findsOneWidget);
      await app.dispose(tester);
    });

    testWidgets('no offer without a page-turn key, on another tab or '
        'when no page turner is used', (tester) async {
      useTabletSize(tester);
      final app = await TestApp.create(
        prefs: {'language': 'en', PageTurnerUseNotifier.key: false},
      );
      await pumpOverview(tester, app);
      await pressPedal(tester, app);
      expect(offer, findsNothing);

      await app.prefs.setBool(PageTurnerUseNotifier.key, true);
      await tester.pumpWidget(const SizedBox());
      await pumpOverview(tester, app);
      // A device key alone, e.g. a letter on a Bluetooth keyboard.
      app.inputDevices.press(pedal);
      await tester.pump();
      expect(offer, findsNothing);
      // On another tab (Arrow Right: Page Down has no page scroll to fail
      // only on the overview).
      await openTab(tester, HomeTab.sets);
      await pressPedal(tester, app, key: LogicalKeyboardKey.arrowRight);
      expect(offer, findsNothing);
      await app.dispose(tester);
    });

    testWidgets('switched off: no page turner line and no pairing tile', (
      tester,
    ) async {
      useTabletSize(tester);
      final app = await TestApp.create(
        prefs: {
          'language': 'en',
          PairedPageTurnerNotifier.nameKey: pedal.name,
          PairedPageTurnerNotifier.vendorKey: pedal.vendorId,
          PairedPageTurnerNotifier.productKey: pedal.productId,
        },
      );
      await pumpOverview(tester, app);
      final line = find.byKey(const Key('overview-readiness-pageTurner'));
      // Paired, not connected: a warning.
      expect(line, findsOneWidget);

      await openLiveSettings(tester);
      final use = find.byKey(const Key('settings-page-turner-use'));
      await centre(tester, use);
      await tester.tap(use);
      await tester.pumpAndSettle();
      expect(app.prefs.getBool(PageTurnerUseNotifier.key), isFalse);
      expect(find.byKey(const Key('settings-page-turner')), findsNothing);

      await openTab(tester, HomeTab.overview);
      expect(line, findsNothing);
      expect(
        find.byKey(const Key('overview-readiness-all-set')),
        findsOneWidget,
      );
      await app.dispose(tester);
    });
  });
}

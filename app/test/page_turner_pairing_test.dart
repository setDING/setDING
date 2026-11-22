import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/l10n/generated/app_localizations.dart';
import 'package:setding/platform/input_devices.dart';
import 'package:setding/settings/settings.dart';
import 'package:setding/ui/home_tab.dart';
import 'package:setding/ui/live/page_turner.dart';
import 'package:setding/ui/overview/readiness.dart';

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
    expect(of(devices, null, [pedal]), PageTurnerConnection.unknown);
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

  Future<void> openLiveSettings(WidgetTester tester) async {
    await openTab(tester, HomeTab.settings);
    await tester.tap(find.byKey(const Key('settings-category-live')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('settings-page-turner')));
    await tester.pumpAndSettle();
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
}

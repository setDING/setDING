import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/data/database.dart' show localOwnerId;
import 'package:setding/midi/midi_connection.dart';
import 'package:setding/midi/midi_output.dart';
import 'package:setding/settings/settings.dart';
import 'package:setding/ui/settings_screen.dart';

import 'test_app.dart';

const _nord = MidiPortInfo(id: 'usb-1', name: 'Nord Stage 3', connected: false);
const _other = MidiPortInfo(id: 'usb-2', name: 'USB MIDI', connected: false);

/// The device settings category "Keyboard (MIDI)" (ADR-0039).
void main() {
  Future<TestApp> pumpMidiSettings(WidgetTester tester) async {
    useTabletSize(tester);
    tester.view.physicalSize = const Size(1280, 2400);
    final app = await TestApp.create(
      prefs: {'language': 'en', 'instrument': 'keyboard'},
    );
    app.midiOutput.ports = [_nord, _other];
    await tester.pumpWidget(app.build(home: const SettingsScreen()));
    await tester.pumpAndSettle();
    await openSettingsCategory(tester, SettingsCategory.midi);
    return app;
  }

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(SettingsScreen)));

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('a device category, off by default with only the switch', (
    tester,
  ) async {
    final app = await pumpMidiSettings(tester);
    expect(find.text('Keyboard (MIDI)'), findsWidgets);
    expect(find.byKey(const Key('settings-scope-device')), findsOneWidget);
    expect(find.byKey(const Key('settings-midi-enabled')), findsOneWidget);
    expect(find.byKey(const Key('settings-midi-status')), findsNothing);
    expect(find.byKey(const Key('settings-midi-profile')), findsNothing);
    // MIDI is not touched while it is off.
    expect(app.midiOutput.connects, isEmpty);
    await app.dispose(tester);
  });

  testWidgets('switched on: choose the output, it connects; profile, Nord '
      'addresses and channel are device settings', (tester) async {
    final app = await pumpMidiSettings(tester);
    final container = containerOf(tester);
    await tap(tester, find.byKey(const Key('settings-midi-enabled')));
    expect(container.read(settingsProvider).midiEnabled, isTrue);
    expect(find.text('Not connected'), findsOneWidget);
    expect(find.byKey(const Key('settings-midi-output-USB MIDI')), findsOne);

    await tap(
      tester,
      find.byKey(const Key('settings-midi-output-Nord Stage 3')),
    );
    expect(container.read(settingsProvider).midiOutputName, 'Nord Stage 3');
    expect(find.text('Connected to Nord Stage 3'), findsOneWidget);
    expect(container.read(midiConnectionProvider).connected, isTrue);

    // The Nord hints and its addresses, only with the Nord profile.
    final hint = find.byKey(const Key('settings-midi-nord-hint'));
    final addresses = find.byKey(const Key('settings-nord-addresses'));
    expect(hint, findsOneWidget);
    expect(find.textContaining('Program Change'), findsOneWidget);
    await tap(tester, find.text('Songs'));
    expect(container.read(settingsProvider).nordAddresses, NordAddresses.songs);

    final channel = find.byKey(const Key('settings-midi-channel'));
    await tap(
      tester,
      find.descendant(of: channel, matching: find.byType(DropdownButton<int>)),
    );
    await tester.tap(find.text('10').last);
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).midiChannel, 10);

    await tap(tester, find.text('Generic'));
    expect(
      container.read(settingsProvider).midiProfile,
      MidiProfileKind.generic,
    );
    expect(hint, findsNothing);
    expect(addresses, findsNothing);

    // Stored on this device only, never in the personal settings.
    expect(app.prefs.getBool('midiEnabled'), isTrue);
    expect(app.prefs.getString('midiOutputName'), 'Nord Stage 3');
    expect(app.prefs.getString('midiProfile'), 'generic');
    expect(app.prefs.getString('nordAddresses'), 'songs');
    expect(app.prefs.getInt('midiChannel'), 10);
    expect(
      app.personal(localOwnerId).keys.where((k) => k.startsWith('midi')),
      isEmpty,
    );
    await app.dispose(tester);
  });

  testWidgets('the remembered output is listed when it is not plugged in; a '
      'device plugged in appears', (tester) async {
    final app = await pumpMidiSettings(tester);
    app.midiOutput.ports = [];
    await tester.runAsync(
      () => containerOf(tester)
          .read(settingsProvider.notifier)
          .update(
            (s) =>
                s.copyWith(midiEnabled: true, midiOutputName: 'Nord Stage 3'),
          ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Nord Stage 3 (not plugged in)'), findsOneWidget);
    expect(find.byKey(const Key('settings-midi-no-devices')), findsOneWidget);
    expect(find.text('Not connected'), findsOneWidget);

    app.midiOutput.plugIn([_nord]);
    await tester.pumpAndSettle();
    expect(find.text('Nord Stage 3 (not plugged in)'), findsNothing);
    expect(find.byKey(const Key('settings-midi-no-devices')), findsNothing);
    expect(find.text('Connected to Nord Stage 3'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('German texts', (tester) async {
    useTabletSize(tester);
    tester.view.physicalSize = const Size(1280, 2400);
    final app = await TestApp.create(
      prefs: {'language': 'de', 'instrument': 'keyboard', 'midiEnabled': true},
    );
    await tester.pumpWidget(app.build(home: const SettingsScreen()));
    await tester.pumpAndSettle();
    await openSettingsCategory(tester, SettingsCategory.midi);
    expect(find.text('MIDI-Programmwechsel'), findsOneWidget);
    expect(find.text('Nicht verbunden'), findsOneWidget);
    expect(find.byKey(const Key('settings-midi-no-devices')), findsOneWidget);
    await app.dispose(tester);
  });
}

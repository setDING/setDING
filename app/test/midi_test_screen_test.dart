import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/midi/midi_message.dart';
import 'package:setding/midi/midi_output.dart';
import 'package:setding/midi/midi_profile.dart';
import 'package:setding/ui/settings/midi_guide.dart';
import 'package:setding/ui/settings/midi_test_screen.dart';
import 'package:setding/ui/settings_screen.dart';
import 'package:setding/util/log.dart';

import 'test_app.dart';

/// Prototype of MIDI program changes (ADR-0039, #512).
void main() {
  const nord = MidiPortInfo(id: 'nord', name: 'Nord Stage 3', connected: false);

  Future<TestApp> open(WidgetTester tester) async {
    useTabletSize(tester);
    // Tall enough that the guided test and the free fields are both built.
    tester.view.physicalSize = const Size(1280, 3000);
    final app = await TestApp.create(prefs: {'language': 'en'});
    app.midiOutput.ports = [nord];
    await tester.pumpWidget(app.build(home: const MidiTestScreen()));
    await tester.pumpAndSettle();
    return app;
  }

  Future<void> connect(WidgetTester tester) async {
    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();
  }

  testWidgets('reached from the test features in developer mode', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(
      prefs: {'language': 'en', 'developerMode': true},
    );
    await tester.pumpWidget(app.build(home: const SettingsScreen()));
    await tester.pumpAndSettle();
    await tapSettingsCategory(tester, 'development');
    final tile = find.byKey(const Key('settings-midi-test'));
    await tester.scrollUntilVisible(
      tile,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(find.byType(MidiTestScreen), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('lists the devices and sends nothing before connecting', (
    tester,
  ) async {
    final app = await open(tester);
    expect(find.text('Nord Stage 3'), findsOneWidget);
    final send = tester.widget<ButtonStyleButton>(
      find.byKey(const Key('midi-send')),
    );
    expect(send.onPressed, isNull);

    await connect(tester);
    expect(app.midiOutput.connected, {'nord'});
    expect(find.text('Connected'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('sends a Nord program with the full bank select', (tester) async {
    final app = await open(tester);
    await connect(tester);

    Future<void> pick(String key, String value) async {
      final dropdown = find.byKey(Key(key));
      await tester.ensureVisible(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text(value).last);
      await tester.pumpAndSettle();
    }

    // K:33 as on the display: block 2, place 12 (#512).
    await pick('midi-bank', 'K');
    await pick('midi-page', '3');
    await pick('midi-button', '3');
    expect(find.text('K:33'), findsOneWidget);
    expect(find.text('B0 00 00 B0 20 02 C0 0C'), findsOneWidget);

    await tester.tap(find.byKey(const Key('midi-send')));
    await tester.pump();
    expect(app.midiOutput.sent, [
      [0xB0, 0, 0, 0xB0, 32, 2, 0xC0, 12],
    ]);
    await tester.drag(find.byType(ListView), const Offset(0, -4000));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Sent: B0 00 00 B0 20 02 C0 0C'),
      findsOneWidget,
    );
    await app.dispose(tester);
  });

  testWidgets('Motif XF voices and performances with the mode change '
      '(#591)', (tester) async {
    final app = await open(tester);
    await connect(tester);

    Future<void> pick(String key, String value) async {
      final dropdown = find.byKey(Key(key));
      await tester.ensureVisible(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text(value).last);
      await tester.pumpAndSettle();
    }

    final segment = find.text('Motif XF');
    await tester.ensureVisible(segment);
    await tester.tap(segment);
    await tester.pumpAndSettle();
    expect(find.text('Performance USR1 A01'), findsOneWidget);
    expect(
      find.text('F0 43 10 7F 12 0A 00 01 01 F7 B0 00 3F B0 20 40 C0 00'),
      findsOneWidget,
    );

    await pick('midi-motif-bank', 'Voice USR1');
    await pick('midi-motif-index', 'C05');
    expect(find.text('Voice USR1 C05'), findsOneWidget);
    await tester.tap(find.byKey(const Key('midi-send')));
    await tester.pump();
    expect(app.midiOutput.sent, [
      [
        0xF0, 0x43, 0x10, 0x7F, 0x12, 0x0A, 0, 1, 0, 0xF7, //
        0xB0, 0, 63, 0xB0, 32, 8, 0xC0, 36,
      ],
    ]);
    await app.dispose(tester);
  });

  testWidgets('Nord songs by song and part, live memories with MSB 6', (
    tester,
  ) async {
    final app = await open(tester);
    await connect(tester);

    await tester.tap(find.text('Nord song'));
    await tester.pumpAndSettle();
    expect(find.text('B0 00 01 B0 20 00 C0 00'), findsOneWidget);
    // Song 2, part 3 = place 7.
    await tester.tap(find.byKey(const Key('midi-song')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('midi-part')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('3').last);
    await tester.pumpAndSettle();
    expect(find.text('B0 00 01 B0 20 00 C0 07'), findsOneWidget);

    await tester.tap(find.text('Nord live'));
    await tester.pumpAndSettle();
    expect(find.text('B0 00 06 B0 20 00 C0 00'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('raw values on another channel; invalid values block sending', (
    tester,
  ) async {
    final app = await open(tester);
    await connect(tester);

    await tester.tap(find.byKey(const Key('midi-channel')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Raw values'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('midi-program')), '128');
    await tester.pump();
    expect(find.text('C1 7F'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('midi-lsb')), '5');
    await tester.pump();
    expect(find.text('B1 20 05 C1 7F'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('midi-program')), '0');
    await tester.pump();
    expect(find.text('Check the values'), findsOneWidget);
    await tester.tap(find.byKey(const Key('midi-send')));
    await tester.pump();
    expect(app.midiOutput.sent, isEmpty);
    await app.dispose(tester);
  });

  testWidgets('logs what the keyboard sends', (tester) async {
    final app = await open(tester);
    await connect(tester);

    app.midiOutput
      ..receive([0xB0, 0, 1])
      ..receive([0xB0, 32, 3])
      ..receive([0xC0, 7])
      ..receive([0xF8])
      ..receive([0xFE])
      ..receive([0x90, 60, 100]);
    await tester.pump();
    // The log is at the end of the list.
    await tester.drag(find.byType(ListView), const Offset(0, -4000));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Received: CC 0 = 1 (channel 1) – B0 00 01'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Received: CC 32 = 3 (channel 1) – B0 20 03'),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Received: program change 8 (value 7, channel 1) – C0 07',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Received: 90 3C 64'), findsOneWidget);
    // Real-time bytes (clock, active sensing) are not logged.
    expect(find.textContaining('Received: F8'), findsNothing);
    expect(find.textContaining('Received: FE'), findsNothing);
    // The lines are kept in the app log for after the test.
    expect(
      Log.export(),
      contains('[midi-test] Received: CC 32 = 3 (channel 1) – B0 20 03'),
    );
    await app.dispose(tester);
  });

  testWidgets('finds a keyboard plugged in later', (tester) async {
    final app = await open(tester);
    app.midiOutput.plugIn(const []);
    await tester.pumpAndSettle();
    expect(find.textContaining('No MIDI device found'), findsOneWidget);

    app.midiOutput.plugIn([nord]);
    await tester.pumpAndSettle();
    expect(find.text('Nord Stage 3'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('an unplugged keyboard is no longer connected', (tester) async {
    final app = await open(tester);
    await connect(tester);
    expect(find.text('Connected'), findsOneWidget);

    app.midiOutput.plugIn(const []);
    await tester.pumpAndSettle();
    expect(find.text('Connected'), findsNothing);
    final send = tester.widget<ButtonStyleButton>(
      find.byKey(const Key('midi-send')),
    );
    expect(send.onPressed, isNull);
    await app.dispose(tester);
  });

  testWidgets('a failed connection is logged', (tester) async {
    final app = await open(tester);
    app.midiOutput.failConnect = true;
    await connect(tester);
    expect(find.text('Connected'), findsNothing);
    await tester.drag(find.byType(ListView), const Offset(0, -4000));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Error: Bad state: device busy'),
      findsOneWidget,
    );
    await app.dispose(tester);
  });

  testWidgets('leaving the screen disconnects the keyboard', (tester) async {
    final app = await open(tester);
    await connect(tester);
    await tester.pumpWidget(app.build(home: const SizedBox()));
    await tester.pumpAndSettle();
    expect(app.midiOutput.disconnected, ['nord']);
    expect(app.midiOutput.connected, isEmpty);
    await app.dispose(tester);
  });

  testWidgets('sends a control change, e.g. the Nord song mode', (
    tester,
  ) async {
    final app = await open(tester);
    await connect(tester);

    await tester.tap(find.text('Control change'));
    await tester.pumpAndSettle();
    // Defaults: CC 3 (song mode on the Nord Stage 3) = 127.
    expect(find.text('B0 03 7F'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('midi-cc')), '5');
    await tester.enterText(find.byKey(const Key('midi-cc-value')), '2');
    await tester.pump();
    expect(find.text('B0 05 02'), findsOneWidget);
    await tester.tap(find.byKey(const Key('midi-send')));
    await tester.pump();
    expect(app.midiOutput.sent, [
      [0xB0, 5, 2],
    ]);

    await tester.enterText(find.byKey(const Key('midi-cc-value')), '128');
    await tester.pump();
    expect(find.text('Check the values'), findsOneWidget);
    await app.dispose(tester);
  });

  group('guided test', () {
    Finder answer(String name) => find.byKey(Key('midi-guide-answer-$name'));

    Future<void> tapKey(WidgetTester tester, Finder f) async {
      await tester.ensureVisible(f);
      await tester.pumpAndSettle();
      await tester.tap(f);
      await tester.pumpAndSettle();
    }

    testWidgets('answers only after sending; the answer is logged', (
      tester,
    ) async {
      Log.clear();
      final app = await open(tester);
      expect(find.textContaining('Step 1 of 10: Program A:11'), findsOneWidget);
      final send = tester.widget<ButtonStyleButton>(
        find.byKey(const Key('midi-guide-send')),
      );
      expect(send.onPressed, isNull);

      await connect(tester);
      expect(
        tester.widget<ButtonStyleButton>(answer('asExpected')).onPressed,
        isNull,
      );
      await tapKey(tester, find.byKey(const Key('midi-guide-send')));
      expect(app.midiOutput.sent, [
        [0xB0, 0, 0, 0xB0, 32, 0, 0xC0, 0],
      ]);
      await tapKey(tester, answer('asExpected'));

      expect(
        find.textContaining('Step 2 of 10: Live memory 1'),
        findsOneWidget,
      );
      expect(
        Log.export(),
        contains('[midi-test] Step 1 (Program A:11): As expected'),
      );
      await app.dispose(tester);
    });

    testWidgets('walks through every step to the end', (tester) async {
      final app = await open(tester);
      await connect(tester);

      for (var i = 0; i < 10; i++) {
        await tapKey(tester, find.byKey(const Key('midi-guide-send')));
        await tapKey(tester, answer('nothing'));
      }
      expect(
        find.text('Test finished. The answers are in the log.'),
        findsOneWidget,
      );
      expect(app.midiOutput.sent, [
        [0xB0, 0, 0, 0xB0, 32, 0, 0xC0, 0], // A:11
        [0xB0, 0, 6, 0xB0, 32, 0, 0xC0, 0], // live 1
        [0xB0, 0, 6, 0xB0, 32, 0, 0xC0, 2], // live 3
        [0xB0, 0, 6, 0xB0, 32, 0, 0xC0, 4], // live 5
        [0xB0, 0, 0, 0xB0, 32, 0, 0xC0, 0], // A:11
        [0xB0, 3, 127], // song mode on
        [0xB0, 0, 1, 0xB0, 32, 0, 0xC0, 7], // song 2, part 3
        [0xB0, 0, 1, 0xB0, 32, 1, 0xC0, 4], // song 26, part 5
        [0xB0, 3, 0], // song mode off
        [0xB0, 0, 0, 0xB0, 32, 0, 0xC0, 0], // A:11
      ]);

      await tapKey(tester, find.byKey(const Key('midi-guide-restart')));
      expect(find.textContaining('Step 1 of 10'), findsOneWidget);
      await app.dispose(tester);
    });

    testWidgets('skip and back without sending', (tester) async {
      final app = await open(tester);
      await connect(tester);

      for (var i = 0; i < 6; i++) {
        await tapKey(tester, find.byKey(const Key('midi-guide-skip')));
      }
      expect(
        find.textContaining('Step 7 of 10: Song 2, part 3'),
        findsOneWidget,
      );
      await tapKey(tester, find.byKey(const Key('midi-guide-back')));
      expect(find.textContaining('Step 6 of 10: Song mode on'), findsOneWidget);
      expect(app.midiOutput.sent, isEmpty);
      await app.dispose(tester);
    });

    Future<void> chooseGuide(WidgetTester tester, String label) async {
      await tapKey(tester, find.byKey(const Key('midi-guide-kind')));
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }

    String received(WidgetTester tester) =>
        tester.widget<Text>(find.byKey(const Key('midi-guide-received'))).data!;

    testWidgets('one send and one receive test per keyboard (#613)', (
      tester,
    ) async {
      final app = await open(tester);
      final kind = tester.widget<DropdownButton<MidiGuide>>(
        find.byKey(const Key('midi-guide-kind')),
      );
      expect(kind.items!.map((i) => i.value), MidiGuide.values);
      expect(kind.value, MidiGuide.nordSend);
      await app.dispose(tester);
    });

    testWidgets('Motif XF send test: with the mode change, across the '
        'banks (#613)', (tester) async {
      final app = await open(tester);
      await connect(tester);
      await chooseGuide(tester, 'Motif XF – send');
      expect(
        find.textContaining('Step 1 of 7: Performance USR1 A01'),
        findsOneWidget,
      );
      expect(find.textContaining('Utility → MIDI'), findsOneWidget);
      for (var i = 0; i < 7; i++) {
        await tapKey(tester, find.byKey(const Key('midi-guide-send')));
        await tapKey(tester, answer('asExpected'));
      }
      expect(app.midiOutput.sent, [
        for (final p in [
          MotifXf.performance(0, 0),
          MotifXf.voice(0, 0),
          MotifXf.voice(7, 127),
          MotifXf.voice(11, 0),
          MotifXf.voice(12, 0),
          MotifXf.voice(13, 0),
          MotifXf.performance(1, 17),
        ])
          const MotifXfProfile().bytes(p, 1),
      ]);
      // Every step starts with the SysEx mode change.
      expect(app.midiOutput.sent.every((b) => b.first == 0xF0), isTrue);
      await app.dispose(tester);
    });

    testWidgets('free receive: whatever arrives is shown in the profile\'s '
        'terms and judged against the display (#615)', (tester) async {
      Log.clear();
      final app = await open(tester);
      await connect(tester);
      await chooseGuide(tester, 'Nord Stage 3 – receive');
      expect(find.byKey(const Key('midi-guide-send')), findsNothing);
      expect(find.byKey(const Key('midi-guide-step')), findsNothing);
      expect(received(tester), 'Choose a sound on the keyboard …');
      final matches = find.byKey(const Key('midi-guide-matches'));
      final noMatch = find.byKey(const Key('midi-guide-no-match'));
      expect(tester.widget<ButtonStyleButton>(matches).onPressed, isNull);
      expect(find.text('Nothing checked yet'), findsOneWidget);

      // K:33 in separate messages.
      app.midiOutput
        ..receive([0xB0, 0, 0])
        ..receive([0xB0, 32, 2])
        ..receive([0xC0, 12]);
      await tester.pumpAndSettle();
      expect(received(tester), 'Received: Program K:33');
      expect(find.text('CC 0 = 0, CC 32 = 2, PC 12'), findsOneWidget);
      await tapKey(tester, matches);
      expect(
        Log.export(),
        contains(
          'Received Program K:33 (CC 0 = 0, CC 32 = 2, PC 12): Matches the '
          'display',
        ),
      );
      expect(received(tester), 'Choose a sound on the keyboard …');
      expect(find.text('1 sound checked'), findsOneWidget);

      // A newer program replaces one not yet judged.
      app.midiOutput.receive([0xB0, 0, 6, 0xB0, 32, 0, 0xC0, 1]);
      await tester.pumpAndSettle();
      app.midiOutput.receive([0xB0, 0, 1, 0xB0, 32, 0, 0xC0, 7]);
      await tester.pumpAndSettle();
      expect(received(tester), 'Received: Song 2, part 3');
      await tapKey(tester, noMatch);
      expect(
        Log.export(),
        contains(
          'Song 2, part 3 (CC 0 = 1, CC 32 = 0, '
          'PC 7): Does not match',
        ),
      );
      expect(find.text('2 sounds checked'), findsOneWidget);
      await app.dispose(tester);
    });

    testWidgets('free receive with the Motif XF, on the chosen channel', (
      tester,
    ) async {
      final app = await open(tester);
      await connect(tester);
      await chooseGuide(tester, 'Motif XF – receive');
      expect(find.textContaining('Transmit Channel'), findsOneWidget);
      final channel = find.byKey(const Key('midi-channel'));
      await tapKey(tester, channel);
      await tester.tap(find.text('5').last);
      await tester.pumpAndSettle();
      // Channel 1 is not listened to.
      app.midiOutput.receive([0xB0, 0, 63, 0xB0, 32, 2, 0xC0, 36]);
      await tester.pumpAndSettle();
      expect(received(tester), 'Choose a sound on the keyboard …');
      app.midiOutput.receive([0xB4, 0, 63, 0xB4, 32, 2, 0xC4, 36]);
      await tester.pumpAndSettle();
      expect(received(tester), 'Received: Voice PRE3 C05');
      await app.dispose(tester);
    });
  });
}

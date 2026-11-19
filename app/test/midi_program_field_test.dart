import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/midi/midi_message.dart';
import 'package:setding/midi/midi_output.dart';
import 'package:setding/ui/songs/song_screen.dart';

import 'test_app.dart';

const _nord = MidiPortInfo(id: 'usb-1', name: 'Nord Stage 3', connected: false);

/// The keyboard program in the song's personal adjustments, its picker and
/// the "Test" button (ADR-0039, #563).
void main() {
  const midiOn = {
    'language': 'en',
    'midiEnabled': true,
    'midiOutputName': 'Nord Stage 3',
  };

  late TestApp app;
  late String songId;

  /// Opens the personal adjustments of a song with [program] stored.
  Future<void> pumpSong(
    WidgetTester tester, {
    Map<String, Object> prefs = midiOn,
    MidiProgram? program,
    List<MidiPortInfo> ports = const [_nord],
    Size? size,
  }) async {
    useTabletSize(tester);
    if (size != null) tester.view.physicalSize = size;
    app = await TestApp.create(prefs: prefs);
    app.midiOutput.ports = ports;
    songId = (await tester.runAsync(() async {
      final id = await app.songs.createSong(source: '{title: X}\n[G]One');
      if (program != null) await app.songs.setMidiProgram(id, program);
      return id;
    }))!;
    await tester.pumpWidget(app.build(home: SongScreen(songId: songId)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-personal-adjustments')));
    await tester.pumpAndSettle();
  }

  Future<MidiProgram?> stored(WidgetTester tester) =>
      tester.runAsync<MidiProgram?>(() => app.songs.midiProgram(songId));

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> openPicker(WidgetTester tester) =>
      tap(tester, find.byKey(const Key('midi-program-value')));

  Future<void> save(WidgetTester tester) async {
    await tap(tester, find.byKey(const Key('midi-program-save')));
    // Let the repository write and the overlay stream report it.
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
  }

  String preview(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('midi-program-preview'))).data!;

  final field = find.byKey(const Key('midi-program-field'));
  final testButton = find.byKey(const Key('midi-program-test'));

  bool enabled(WidgetTester tester, Finder button) =>
      tester.widget<ButtonStyleButton>(button).onPressed != null;

  group('visibility', () {
    testWidgets('hidden while MIDI is off and the song has no program', (
      tester,
    ) async {
      await pumpSong(tester, prefs: {'language': 'en'});
      expect(find.byKey(const Key('personal-adjustments')), findsOneWidget);
      expect(field, findsNothing);
      await app.dispose(tester);
    });

    testWidgets('shown while MIDI is on, without a program', (tester) async {
      await pumpSong(tester);
      expect(field, findsOneWidget);
      expect(find.text('Keyboard program'), findsOneWidget);
      expect(find.text('Choose program'), findsOneWidget);
      expect(testButton, findsNothing);
      expect(find.byKey(const Key('midi-program-remove')), findsNothing);
      await app.dispose(tester);
    });

    testWidgets('shown with a stored program while MIDI is off: readable, '
        'removable, Test disabled', (tester) async {
      await pumpSong(
        tester,
        prefs: {'language': 'en'},
        program: const MidiProgram(msb: 0, lsb: 2, program: 12),
      );
      expect(field, findsOneWidget);
      expect(find.text('Program K:33'), findsOneWidget);
      expect(find.textContaining('MIDI program changes are off'), findsOne);
      expect(enabled(tester, testButton), isFalse);
      await tap(tester, find.byKey(const Key('midi-program-remove')));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      expect(await stored(tester), isNull);
      // Nothing left to show on a device without MIDI.
      expect(field, findsNothing);
      await app.dispose(tester);
    });
  });

  group('Nord programs', () {
    testWidgets('bank chips and the page × button grid with a preview', (
      tester,
    ) async {
      await pumpSong(tester);
      await openPicker(tester);
      // Programs and live memories in the Nord addresses "Programs".
      expect(find.byKey(const Key('midi-kind-program')), findsOneWidget);
      expect(find.byKey(const Key('midi-kind-live')), findsOneWidget);
      expect(find.byKey(const Key('midi-kind-song')), findsNothing);
      expect(preview(tester), 'Program A:11');

      await tap(tester, find.byKey(const Key('midi-bank-10')));
      await tap(tester, find.byKey(const Key('midi-cell-33')));
      expect(preview(tester), 'Program K:33');
      await save(tester);
      expect(
        await stored(tester),
        const MidiProgram(msb: 0, lsb: 2, program: 12),
      );
      expect(find.text('Program K:33'), findsOneWidget);
      // Choosing sends nothing.
      expect(app.midiOutput.sent, isEmpty);
      await app.dispose(tester);
    });

    testWidgets('programs at the borders of the blocks of 125', (tester) async {
      await pumpSong(tester);
      for (final (bank, cell, label, expected) in [
        (4, '55', 'E:55', const MidiProgram(msb: 0, lsb: 0, program: 124)),
        (5, '11', 'F:11', const MidiProgram(msb: 0, lsb: 1, program: 0)),
        (15, '55', 'P:55', const MidiProgram(msb: 0, lsb: 3, program: 24)),
      ]) {
        await openPicker(tester);
        await tap(tester, find.byKey(Key('midi-bank-$bank')));
        await tap(tester, find.byKey(Key('midi-cell-$cell')));
        expect(preview(tester), 'Program $label');
        await save(tester);
        expect(await stored(tester), expected, reason: label);
        expect(find.text('Program $label'), findsOneWidget);
      }
      // The picker starts with the stored program.
      await openPicker(tester);
      expect(preview(tester), 'Program P:55');
      await app.dispose(tester);
    });

    testWidgets('live memories', (tester) async {
      await pumpSong(tester);
      await openPicker(tester);
      await tap(tester, find.byKey(const Key('midi-kind-live')));
      expect(preview(tester), 'Live memory 1');
      await tap(tester, find.byKey(const Key('midi-live-2')));
      expect(preview(tester), 'Live memory 3');
      await save(tester);
      expect(
        await stored(tester),
        const MidiProgram(msb: 6, lsb: 0, program: 2),
      );
      expect(find.text('Live memory 3'), findsOneWidget);
      await app.dispose(tester);
    });

    testWidgets('cancel keeps the stored program', (tester) async {
      await pumpSong(
        tester,
        program: const MidiProgram(msb: 6, lsb: 0, program: 0),
      );
      await openPicker(tester);
      expect(preview(tester), 'Live memory 1');
      await tap(tester, find.byKey(const Key('midi-live-4')));
      expect(preview(tester), 'Live memory 5');
      await tap(tester, find.text('Cancel'));
      expect(
        await stored(tester),
        const MidiProgram(msb: 6, lsb: 0, program: 0),
      );
      await app.dispose(tester);
    });
  });

  group('Nord songs', () {
    testWidgets('song stepper and part, only songs offered', (tester) async {
      await pumpSong(tester, prefs: {...midiOn, 'nordAddresses': 'songs'});
      await openPicker(tester);
      // Only one kind: no selector.
      expect(find.byKey(const Key('midi-program-kind')), findsNothing);
      expect(preview(tester), 'Song 1, part 1');
      final down = find.byKey(const Key('midi-song-down'));
      expect(tester.widget<IconButton>(down).onPressed, isNull);
      await tap(tester, find.byKey(const Key('midi-song-up')));
      await tap(tester, find.byKey(const Key('midi-song-up')));
      await tap(tester, find.byKey(const Key('midi-song-up')));
      await tap(tester, down);
      await tap(tester, find.byKey(const Key('midi-part-3')));
      expect(preview(tester), 'Song 3, part 4');
      await save(tester);
      // (3 − 1) × 5 + 4 − 1 = 13.
      expect(
        await stored(tester),
        const MidiProgram(msb: 1, lsb: 0, program: 13),
      );
      expect(find.text('Song 3, part 4'), findsOneWidget);
      await app.dispose(tester);
    });

    testWidgets('song 26 is in the second block', (tester) async {
      await pumpSong(
        tester,
        prefs: {...midiOn, 'nordAddresses': 'songs'},
        program: const MidiProgram(msb: 1, lsb: 0, program: 124),
      );
      expect(find.text('Song 25, part 5'), findsOneWidget);
      await openPicker(tester);
      await tap(tester, find.byKey(const Key('midi-song-up')));
      await tap(tester, find.byKey(const Key('midi-part-0')));
      expect(preview(tester), 'Song 26, part 1');
      await save(tester);
      expect(
        await stored(tester),
        const MidiProgram(msb: 1, lsb: 1, program: 0),
      );
      await app.dispose(tester);
    });

    testWidgets('a program stored in the other mode stays readable and '
        'editable as a program', (tester) async {
      await pumpSong(
        tester,
        prefs: {...midiOn, 'nordAddresses': 'songs'},
        program: const MidiProgram(msb: 0, lsb: 2, program: 12),
      );
      expect(find.text('Program K:33'), findsOneWidget);
      await openPicker(tester);
      expect(find.byKey(const Key('midi-kind-program')), findsOneWidget);
      expect(find.byKey(const Key('midi-kind-song')), findsOneWidget);
      expect(find.byKey(const Key('midi-kind-live')), findsNothing);
      expect(preview(tester), 'Program K:33');
      await tap(tester, find.byKey(const Key('midi-cell-34')));
      await save(tester);
      expect(
        await stored(tester),
        const MidiProgram(msb: 0, lsb: 2, program: 13),
      );
      await app.dispose(tester);
    });

    testWidgets('a value the Nord does not send is shown with its raw values', (
      tester,
    ) async {
      await pumpSong(
        tester,
        program: const MidiProgram(msb: 0, lsb: 3, program: 124),
      );
      expect(find.text('Program 125 · MSB 0 · LSB 3'), findsOneWidget);
      await openPicker(tester);
      expect(find.byKey(const Key('midi-kind-generic')), findsOneWidget);
      expect(preview(tester), 'Program 125 · MSB 0 · LSB 3');
      await app.dispose(tester);
    });
  });

  group('generic profile', () {
    testWidgets('MSB, LSB and program with validation', (tester) async {
      await pumpSong(tester, prefs: {...midiOn, 'midiProfile': 'generic'});
      await openPicker(tester);
      expect(find.byKey(const Key('midi-program-kind')), findsNothing);
      final saveButton = find.byKey(const Key('midi-program-save'));
      final msb = find.byKey(const Key('midi-generic-msb'));
      final lsb = find.byKey(const Key('midi-generic-lsb'));
      final program = find.byKey(const Key('midi-generic-program'));
      expect(preview(tester), 'Program 1');
      expect(enabled(tester, saveButton), isTrue);

      await tester.enterText(msb, '200');
      await tester.pumpAndSettle();
      expect(find.text('Enter a number from 0 to 127'), findsOneWidget);
      expect(enabled(tester, saveButton), isFalse);
      await tester.enterText(msb, '0');
      await tester.enterText(program, '');
      await tester.pumpAndSettle();
      expect(find.text('Enter a number from 1 to 128'), findsOneWidget);
      expect(enabled(tester, saveButton), isFalse);
      await tester.enterText(program, '129');
      await tester.pumpAndSettle();
      expect(enabled(tester, saveButton), isFalse);
      await tester.enterText(program, '0');
      await tester.pumpAndSettle();
      expect(enabled(tester, saveButton), isFalse);
      // Only digits can be typed.
      await tester.enterText(lsb, '-2x');
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(lsb).controller!.text, '2');

      await tester.enterText(program, '13');
      await tester.pumpAndSettle();
      expect(preview(tester), 'Program 13 · MSB 0 · LSB 2');
      await save(tester);
      expect(
        await stored(tester),
        const MidiProgram(msb: 0, lsb: 2, program: 12),
      );
      expect(find.text('Program 13 · MSB 0 · LSB 2'), findsOneWidget);
      await app.dispose(tester);
    });

    testWidgets('an empty bank select is not stored', (tester) async {
      await pumpSong(
        tester,
        prefs: {...midiOn, 'midiProfile': 'generic'},
        program: const MidiProgram(msb: 0, lsb: 2, program: 12),
      );
      await openPicker(tester);
      await tester.enterText(find.byKey(const Key('midi-generic-msb')), '');
      await tester.enterText(find.byKey(const Key('midi-generic-lsb')), '');
      await tester.enterText(
        find.byKey(const Key('midi-generic-program')),
        '128',
      );
      await tester.pumpAndSettle();
      await save(tester);
      expect(await stored(tester), const MidiProgram(program: 127));
      expect(find.text('Program 128'), findsOneWidget);
      await app.dispose(tester);
    });
  });

  testWidgets('remove: the program is gone, the field stays while MIDI is '
      'on', (tester) async {
    await pumpSong(
      tester,
      program: const MidiProgram(msb: 0, lsb: 0, program: 0),
    );
    expect(find.text('Program A:11'), findsOneWidget);
    await tap(tester, find.byKey(const Key('midi-program-remove')));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(await stored(tester), isNull);
    expect(field, findsOneWidget);
    expect(find.text('Choose program'), findsOneWidget);
    await app.dispose(tester);
  });

  group('Test', () {
    testWidgets('sends exactly the bank select and program change once, on '
        'the channel of the device', (tester) async {
      await pumpSong(
        tester,
        prefs: {...midiOn, 'midiChannel': 3},
        program: const MidiProgram(msb: 0, lsb: 2, program: 12),
      );
      // Opening the song sends nothing.
      expect(app.midiOutput.sent, isEmpty);
      expect(enabled(tester, testButton), isTrue);
      await tap(tester, testButton);
      expect(app.midiOutput.sent, [
        [0xB2, 0, 0, 0xB2, 32, 2, 0xC2, 12],
      ]);
      expect(app.midiOutput.sentTo, ['usb-1']);
      expect(find.text('Sent to Nord Stage 3'), findsOneWidget);
      await app.dispose(tester);
    });

    testWidgets('a program without bank select sends only the program change', (
      tester,
    ) async {
      await pumpSong(
        tester,
        prefs: {...midiOn, 'midiProfile': 'generic'},
        program: const MidiProgram(program: 4),
      );
      await tap(tester, testButton);
      expect(app.midiOutput.sent, [
        [0xC0, 4],
      ]);
      await app.dispose(tester);
    });

    testWidgets('disabled while the keyboard is not connected', (tester) async {
      await pumpSong(
        tester,
        ports: const [],
        program: const MidiProgram(msb: 6, lsb: 0, program: 1),
      );
      expect(enabled(tester, testButton), isFalse);
      expect(find.byKey(const Key('midi-program-not-connected')), findsOne);
      await tester.tap(testButton, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(app.midiOutput.sent, isEmpty);

      // Plugged in: connects, Test works.
      app.midiOutput.plugIn(const [_nord]);
      await tester.pumpAndSettle();
      expect(enabled(tester, testButton), isTrue);
      await tap(tester, testButton);
      expect(app.midiOutput.sent, [
        [0xB0, 0, 6, 0xB0, 32, 0, 0xC0, 1],
      ]);
      await app.dispose(tester);
    });
  });

  group('phone width', () {
    for (final prefs in [
      midiOn,
      {...midiOn, 'nordAddresses': 'songs'},
      {...midiOn, 'midiProfile': 'generic'},
    ]) {
      testWidgets('the picker fits (${prefs.length})', (tester) async {
        await pumpSong(
          tester,
          prefs: prefs,
          size: const Size(360, 740),
          program: const MidiProgram(msb: 0, lsb: 2, program: 12),
        );
        expect(tester.takeException(), isNull);
        await openPicker(tester);
        expect(tester.takeException(), isNull);
        if (prefs.length == 3) {
          await tap(tester, find.byKey(const Key('midi-kind-live')));
          expect(tester.takeException(), isNull);
          await tap(tester, find.byKey(const Key('midi-kind-program')));
        }
        await save(tester);
        expect(tester.takeException(), isNull);
        await app.dispose(tester);
      });
    }
  });

  testWidgets('German texts', (tester) async {
    await pumpSong(
      tester,
      prefs: {...midiOn, 'language': 'de'},
      program: const MidiProgram(msb: 1, lsb: 0, program: 7),
    );
    expect(find.text('Keyboard-Programm'), findsOneWidget);
    expect(find.text('Song 2, Teil 3'), findsOneWidget);
    expect(find.text('Test'), findsOneWidget);
    await openPicker(tester);
    expect(find.text('Live-Speicher'), findsOneWidget);
    await app.dispose(tester);
  });
}

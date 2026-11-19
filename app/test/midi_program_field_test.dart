import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/data/song_repository.dart';
import 'package:flutter/rendering.dart';
import 'package:setding/l10n/generated/app_localizations.dart';
import 'package:setding/midi/midi_message.dart';
import 'package:setding/midi/midi_profile.dart';
import 'package:setding/midi/midi_output.dart';
import 'package:setding/ui/songs/midi_program_field.dart';
import 'package:setding/ui/songs/song_screen.dart';

import 'test_app.dart';

const _nord = MidiPortInfo(id: 'usb-1', name: 'Nord Stage 3', connected: false);

/// The keyboard program in the song's personal adjustments, its picker and
/// the "Test" button (ADR-0039, #563).
void main() {
  const midiOn = {
    'language': 'en',
    'instrument': 'keyboard',
    'midiEnabled': true,
    'midiOutputName': 'Nord Stage 3',
  };

  late TestApp app;
  late String songId;

  /// The device profile of the current test (ADR-0042).
  late String profileId;

  setUp(MidiProgramPicker.resetLastKind);

  /// Opens the personal adjustments of a song with [program] stored.
  Future<void> pumpSong(
    WidgetTester tester, {
    Map<String, Object> prefs = midiOn,
    MidiProgram? program,
    MidiPrograms others = const MidiPrograms(),
    List<MidiPortInfo> ports = const [_nord],
    Size? size,
  }) async {
    profileId = prefs['midiProfile'] as String? ?? 'nordStage3';
    useTabletSize(tester);
    if (size != null) tester.view.physicalSize = size;
    app = await TestApp.create(prefs: prefs);
    app.midiOutput.ports = ports;
    songId = (await tester.runAsync(() async {
      final id = await app.songs.createSong(source: '{title: X}\n[G]One');
      for (final MapEntry(:key, :value) in {
        ...others.byProfile,
        profileId: ?program,
      }.entries) {
        await app.songs.setMidiProgram(
          id,
          key,
          value,
          deviceProfile: profileId,
        );
      }
      return id;
    }))!;
    await tester.pumpWidget(app.build(home: SongScreen(songId: songId)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-personal-adjustments')));
    await tester.pumpAndSettle();
  }

  Future<MidiProgram?> stored(WidgetTester tester) => tester
      .runAsync<MidiProgram?>(() => app.songs.midiProgram(songId, profileId));

  Future<MidiPrograms> storedAll(WidgetTester tester) async =>
      (await tester.runAsync<MidiPrograms>(
        () async => SongRepository.midiProgramsOf(
          await app.songs.getOverlay(songId),
          profileId,
        ),
      ))!;

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
      switch (tester.widget(button)) {
        final IconButton b => b.onPressed,
        final ButtonStyleButton b => b.onPressed,
        final w => throw StateError('not a button: $w'),
      } !=
      null;

  group('visibility', () {
    testWidgets('hidden while MIDI is off and the song has no program', (
      tester,
    ) async {
      await pumpSong(
        tester,
        prefs: {'language': 'en', 'instrument': 'keyboard'},
      );
      expect(find.byKey(const Key('personal-adjustments')), findsOneWidget);
      expect(field, findsNothing);
      await app.dispose(tester);
    });

    testWidgets('hidden for another instrument, even with MIDI on and a '
        'stored program (#578)', (tester) async {
      await pumpSong(
        tester,
        prefs: {...midiOn, 'instrument': 'guitar'},
        program: const MidiProgram(msb: 0, lsb: 2, program: 12),
      );
      expect(find.byKey(const Key('personal-adjustments')), findsOneWidget);
      expect(field, findsNothing);
      await app.dispose(tester);
    });

    testWidgets('shown while MIDI is on, without a program', (tester) async {
      await pumpSong(tester);
      expect(field, findsOneWidget);
      expect(find.text('Keyboard programs'), findsOneWidget);
      expect(find.text('This device: Nord Stage 3'), findsOneWidget);
      // This device's profile is listed even without a program (#597);
      // the other profiles without a program are not.
      final active = find.byKey(const Key('midi-program-active'));
      expect(
        find.descendant(of: active, matching: find.text('Nord Stage 3')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: active, matching: find.text('Choose program')),
        findsOneWidget,
      );
      expect(find.text('Motif XF'), findsNothing);
      expect(find.text('Generic'), findsNothing);
      expect(testButton, findsNothing);
      expect(find.byKey(const Key('midi-program-remove')), findsNothing);
      await app.dispose(tester);
    });

    testWidgets('shown with a stored program while MIDI is off: readable, '
        'removable, Test disabled', (tester) async {
      await pumpSong(
        tester,
        prefs: {'language': 'en', 'instrument': 'keyboard'},
        program: const MidiProgram(msb: 0, lsb: 2, program: 12),
      );
      expect(field, findsOneWidget);
      expect(find.text('K:33'), findsOneWidget);
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
      // Programs, live memories and songs, always (#586).
      expect(find.byKey(const Key('midi-kind-program')), findsOneWidget);
      expect(find.byKey(const Key('midi-kind-live')), findsOneWidget);
      expect(find.byKey(const Key('midi-kind-song')), findsOneWidget);
      expect(preview(tester), 'Program A:11');
      // Sending while selecting is offered in live mode only (#607).
      expect(
        find.byKey(const Key('midi-program-preview-switch')),
        findsNothing,
      );

      await tap(tester, find.byKey(const Key('midi-bank-10')));
      await tap(tester, find.byKey(const Key('midi-cell-33')));
      expect(preview(tester), 'Program K:33');
      await save(tester);
      expect(
        await stored(tester),
        const MidiProgram(msb: 0, lsb: 2, program: 12),
      );
      expect(find.text('K:33'), findsOneWidget);
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
        expect(find.text(label), findsOneWidget);
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
      expect(find.text('Live 3'), findsOneWidget);
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
    testWidgets('song stepper and part, with the OS hint', (tester) async {
      await pumpSong(tester);
      await openPicker(tester);
      expect(find.byKey(const Key('midi-song-hint')), findsNothing);
      await tap(tester, find.byKey(const Key('midi-kind-song')));
      expect(preview(tester), 'Song 1, part 1');
      expect(find.byKey(const Key('midi-song-hint')), findsOneWidget);
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
      expect(find.text('S3:4'), findsOneWidget);
      await app.dispose(tester);
    });

    testWidgets('song 26 is in the second block', (tester) async {
      await pumpSong(
        tester,
        program: const MidiProgram(msb: 1, lsb: 0, program: 124),
      );
      expect(find.text('S25:5'), findsOneWidget);
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

    testWidgets('a new program starts with the kind saved last', (
      tester,
    ) async {
      await pumpSong(tester);
      await openPicker(tester);
      await tap(tester, find.byKey(const Key('midi-kind-song')));
      await tap(tester, find.byKey(const Key('midi-part-2')));
      await save(tester);
      expect(
        await stored(tester),
        const MidiProgram(msb: 1, lsb: 0, program: 2),
      );
      await tap(tester, find.byKey(const Key('midi-program-remove')));
      expect(await stored(tester), isNull);
      // The next new program starts as a song, not as program A:11.
      await openPicker(tester);
      expect(preview(tester), 'Song 1, part 1');
      await tap(tester, find.text('Cancel'));
      expect(await stored(tester), isNull);
      await app.dispose(tester);
    });

    testWidgets('a stored program opens with its own kind', (tester) async {
      await pumpSong(
        tester,
        program: const MidiProgram(msb: 0, lsb: 2, program: 12),
      );
      expect(find.text('K:33'), findsOneWidget);
      await openPicker(tester);
      expect(preview(tester), 'Program K:33');
      await tap(tester, find.byKey(const Key('midi-kind-song')));
      await tap(tester, find.byKey(const Key('midi-part-1')));
      await save(tester);
      expect(
        await stored(tester),
        const MidiProgram(msb: 1, lsb: 0, program: 1),
      );
      expect(find.text('S1:2'), findsOneWidget);
      await app.dispose(tester);
    });

    testWidgets('a value the Nord does not send is shown with its raw values', (
      tester,
    ) async {
      await pumpSong(
        tester,
        program: const MidiProgram(msb: 0, lsb: 3, program: 124),
      );
      expect(find.text('125 (0/3)'), findsOneWidget);
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
      expect(find.text('13 (0/2)'), findsOneWidget);
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
      expect(find.text('128'), findsOneWidget);
      await app.dispose(tester);
    });
  });

  testWidgets('remove: the program is gone, the field stays while MIDI is '
      'on', (tester) async {
    await pumpSong(
      tester,
      program: const MidiProgram(msb: 0, lsb: 0, program: 0),
    );
    expect(find.text('A:11'), findsOneWidget);
    await tap(tester, find.byKey(const Key('midi-program-remove')));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(await stored(tester), isNull);
    expect(field, findsOneWidget);
    expect(find.text('Choose program'), findsOneWidget);
    await app.dispose(tester);
  });

  group('Motif XF (#591)', () {
    const motifOn = {...midiOn, 'midiProfile': 'motifXf'};

    testWidgets('performance by bank, group and number, with a preview', (
      tester,
    ) async {
      await pumpSong(tester, prefs: motifOn);
      await openPicker(tester);
      expect(find.byKey(const Key('midi-kind-performance')), findsOneWidget);
      expect(find.byKey(const Key('midi-kind-voice')), findsOneWidget);
      expect(find.byKey(const Key('midi-kind-program')), findsNothing);
      expect(find.byKey(const Key('midi-motif-hint')), findsOneWidget);
      expect(preview(tester), 'Performance USR1 A01');

      await tap(tester, find.byKey(const Key('midi-motif-bank-1')));
      await tap(tester, find.byKey(const Key('midi-motif-group-2')));
      await tap(tester, find.byKey(const Key('midi-motif-number-4')));
      expect(preview(tester), 'Performance USR2 C05');
      await save(tester);
      expect(
        await stored(tester),
        const MidiProgram(msb: 63, lsb: 65, program: 36),
      );
      expect(find.text('P USR2 C05'), findsOneWidget);
      expect(app.midiOutput.sent, isEmpty);
      await app.dispose(tester);
    });

    testWidgets('voices; a drum bank keeps the choice inside the bank', (
      tester,
    ) async {
      await pumpSong(tester, prefs: motifOn);
      await openPicker(tester);
      await tap(tester, find.byKey(const Key('midi-kind-voice')));
      expect(preview(tester), 'Voice PRE1 A01');
      await tap(tester, find.byKey(const Key('midi-motif-group-7')));
      await tap(tester, find.byKey(const Key('midi-motif-number-15')));
      expect(preview(tester), 'Voice PRE1 H16');
      // User drums have 32 voices, groups A–B: H16 becomes B16.
      await tap(tester, find.byKey(const Key('midi-motif-bank-14')));
      expect(preview(tester), 'Voice UDR B16');
      expect(find.byKey(const Key('midi-motif-group-2')), findsNothing);
      await tap(tester, find.byKey(const Key('midi-motif-bank-8')));
      await tap(tester, find.byKey(const Key('midi-motif-group-0')));
      await tap(tester, find.byKey(const Key('midi-motif-number-0')));
      expect(preview(tester), 'Voice USR1 A01');
      await save(tester);
      expect(
        await stored(tester),
        const MidiProgram(msb: 63, lsb: 8, program: 0),
      );
      // Opens again with the stored voice.
      await openPicker(tester);
      expect(preview(tester), 'Voice USR1 A01');
      await app.dispose(tester);
    });

    testWidgets('Test sends the mode change first', (tester) async {
      await pumpSong(
        tester,
        prefs: motifOn,
        program: const MidiProgram(msb: 63, lsb: 64, program: 0),
      );
      expect(find.text('P USR1 A01'), findsOneWidget);
      await tap(tester, testButton);
      expect(app.midiOutput.sent, [
        [
          0xF0, 0x43, 0x10, 0x7F, 0x12, 0x0A, 0, 1, 1, 0xF7, //
          0xB0, 0, 63, 0xB0, 32, 64, 0xC0, 0,
        ],
      ]);
      await app.dispose(tester);
    });
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

  group('other keyboards (ADR-0042)', () {
    const nord = MidiProgram(msb: 0, lsb: 2, program: 12);
    const generic = MidiProgram(msb: 1, program: 4);

    testWidgets('the programs of other profiles are listed, editable and '
        'removable; nothing is sent', (tester) async {
      await pumpSong(
        tester,
        program: nord,
        others: const MidiPrograms({'generic': generic}),
      );
      expect(find.text('K:33'), findsOneWidget);
      // Both in one list: this device's profile first (#597).
      expect(
        tester.getTopLeft(find.byKey(const Key('midi-program-active'))).dy,
        lessThan(
          tester.getTopLeft(find.byKey(const Key('midi-other-generic'))).dy,
        ),
      );
      final other = find.byKey(const Key('midi-other-generic'));
      expect(
        find.descendant(of: other, matching: find.text('Generic')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: other, matching: find.text('5 (1/–)')),
        findsOneWidget,
      );

      // Edited with the generic picker.
      await tap(tester, find.byKey(const Key('midi-other-value-generic')));
      expect(find.byKey(const Key('midi-generic-program')), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('midi-generic-program')),
        '9',
      );
      await save(tester);
      expect(
        await storedAll(tester),
        const MidiPrograms({
          'nordStage3': nord,
          'generic': MidiProgram(msb: 1, program: 8),
        }),
      );

      await tap(tester, find.byKey(const Key('midi-other-remove-generic')));
      expect(await storedAll(tester), const MidiPrograms({'nordStage3': nord}));
      expect(find.byKey(const Key('midi-other-generic')), findsNothing);
      expect(app.midiOutput.sent, isEmpty);
      await app.dispose(tester);
    });

    testWidgets('a program for another keyboard is prepared', (tester) async {
      await pumpSong(tester, program: nord);
      await tap(tester, find.byKey(const Key('midi-program-add-other')));
      await tap(tester, find.byKey(const Key('midi-add-generic')));
      await tester.enterText(
        find.byKey(const Key('midi-generic-program')),
        '3',
      );
      await save(tester);
      expect(
        await storedAll(tester),
        const MidiPrograms({
          'nordStage3': nord,
          'generic': MidiProgram(program: 2),
        }),
      );
      // Generic has a program now: only the Motif is left to add.
      await tap(tester, find.byKey(const Key('midi-program-add-other')));
      expect(find.byKey(const Key('midi-add-generic')), findsNothing);
      expect(find.byKey(const Key('midi-add-motifXf')), findsOneWidget);
      await app.dispose(tester);
    });

    testWidgets('changing the profile shows the other program first', (
      tester,
    ) async {
      await pumpSong(
        tester,
        prefs: {...midiOn, 'midiProfile': 'generic'},
        program: generic,
        others: const MidiPrograms({'nordStage3': nord}),
      );
      expect(find.text('This device: Generic'), findsOneWidget);
      expect(
        tester
            .widget<ActionChip>(find.byKey(const Key('midi-program-value')))
            .label,
        isA<Text>().having((t) => t.data, 'text', '5 (1/–)'),
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('midi-other-nordStage3')),
          matching: find.text('K:33'),
        ),
        findsOneWidget,
      );
      await app.dispose(tester);
    });

    testWidgets('a profile this client does not know can only be removed', (
      tester,
    ) async {
      await pumpSong(
        tester,
        program: nord,
        others: const MidiPrograms({
          'futureKeys': MidiProgram(msb: 63, lsb: 8, program: 0),
        }),
      );
      final other = find.byKey(const Key('midi-other-futureKeys'));
      expect(
        find.descendant(
          of: other,
          matching: find.text('Unknown keyboard (futureKeys)'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('midi-other-value-futureKeys')),
        findsNothing,
      );
      await tap(tester, find.byKey(const Key('midi-other-remove-futureKeys')));
      expect(await storedAll(tester), const MidiPrograms({'nordStage3': nord}));
      await app.dispose(tester);
    });
  });

  group('short labels (#599)', () {
    testWidgets('every kind in its short form, the full form as tooltip', (
      tester,
    ) async {
      await pumpSong(tester);
      final l10n = lookupAppLocalizations(const Locale('en'));
      final cases = <MidiPatch, (String, String)>{
        const NordProgram(10, 3, 3): ('K:33', 'Program K:33'),
        const NordLiveMemory(2): ('Live 2', 'Live memory 2'),
        const NordSong(1, 2): ('S1:2', 'Song 1, part 2'),
        const MotifVoice(0, 0): ('PRE1 A01', 'Voice PRE1 A01'),
        const MotifPerformance(1, 17): ('P USR2 B02', 'Performance USR2 B02'),
        const GenericProgram(msb: 0, lsb: 3, program: 125): (
          '125 (0/3)',
          'Program 125 · MSB 0 · LSB 3',
        ),
        const GenericProgram(msb: 1, program: 5): (
          '5 (1/–)',
          'Program 5 · MSB 1',
        ),
        const GenericProgram(program: 128): ('128', 'Program 128'),
      };
      for (final MapEntry(key: patch, value: (short, full)) in cases.entries) {
        expect(midiPatchShortLabel(l10n, patch), short, reason: full);
        expect(midiPatchLabel(l10n, patch), full);
      }
      await app.dispose(tester);
    });

    testWidgets('the chip keeps the whole program on a tablet', (tester) async {
      // The test font draws every character as wide as it is high, so
      // the labels here are short ones.
      await pumpSong(
        tester,
        size: const Size(800, 1280),
        program: const MidiProgram(msb: 6, lsb: 0, program: 2),
        others: const MidiPrograms({
          'generic': MidiProgram(msb: 1, program: 4),
        }),
      );
      expect(tester.takeException(), isNull);
      expect(find.byTooltip('Live memory 3'), findsOneWidget);
      expect(find.byTooltip('Program 5 · MSB 1'), findsOneWidget);
      for (final text in ['Live 3', '5 (1/–)']) {
        final label = tester.renderObject<RenderParagraph>(find.text(text));
        expect(label.didExceedMaxLines, isFalse, reason: text);
      }
      await app.dispose(tester);
    });
  });

  group('phone width', () {
    testWidgets('the program rows fit (#599)', (tester) async {
      await pumpSong(
        tester,
        prefs: {...midiOn, 'midiProfile': 'motifXf'},
        size: const Size(360, 740),
        program: const MidiProgram(msb: 63, lsb: 65, program: 20),
        others: const MidiPrograms({
          'generic': MidiProgram(msb: 127, lsb: 127, program: 127),
          'nordStage3': MidiProgram(msb: 1, lsb: 3, program: 124),
        }),
      );
      expect(tester.takeException(), isNull);
      expect(find.byTooltip('Performance USR2 B05'), findsOneWidget);
      await app.dispose(tester);
    });

    for (final (name, prefs) in [
      ('Nord', midiOn),
      ('generic', {...midiOn, 'midiProfile': 'generic'}),
      ('Motif XF', {...midiOn, 'midiProfile': 'motifXf'}),
    ]) {
      testWidgets('the picker fits ($name)', (tester) async {
        await pumpSong(
          tester,
          prefs: prefs,
          size: const Size(360, 740),
          program: const MidiProgram(msb: 0, lsb: 2, program: 12),
        );
        expect(tester.takeException(), isNull);
        await openPicker(tester);
        expect(tester.takeException(), isNull);
        if (name == 'Nord') {
          for (final kind in ['live', 'song', 'program']) {
            await tap(tester, find.byKey(Key('midi-kind-$kind')));
            expect(tester.takeException(), isNull, reason: kind);
          }
        }
        if (name == 'Motif XF') {
          for (final kind in ['voice', 'performance']) {
            await tap(tester, find.byKey(Key('midi-kind-$kind')));
            expect(tester.takeException(), isNull, reason: kind);
          }
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
    expect(find.text('Keyboard-Programme'), findsOneWidget);
    expect(find.text('Dieses Gerät: Nord Stage 3'), findsOneWidget);
    expect(find.text('S2:3'), findsOneWidget);
    expect(find.byTooltip('Song 2, Teil 3'), findsOneWidget);
    expect(
      find.byTooltip('Sendet das Programm einmal ans Keyboard'),
      findsOneWidget,
    );
    await openPicker(tester);
    expect(find.text('Live-Speicher'), findsOneWidget);
    await app.dispose(tester);
  });
}

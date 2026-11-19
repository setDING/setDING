import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/data/database.dart' show SetItemType;
import 'package:setding/midi/midi_message.dart';
import 'package:setding/midi/midi_output.dart';
import 'package:setding/ui/live/live_screen.dart';

import 'test_app.dart';

const _nord = MidiPortInfo(id: 'usb-1', name: 'Nord Stage 3', connected: false);
const _piano = MidiProgram(msb: 0, lsb: 0, program: 1);
const _organ = MidiProgram(msb: 0, lsb: 2, program: 12);

/// The keyboard program of the current song in live mode (ADR-0039).
void main() {
  const midiOn = {'midiEnabled': true, 'midiOutputName': 'Nord Stage 3'};

  /// [verses] verses of short chord lines: more than one page.
  String versesSong(int verses) =>
      '{title: Long}\n${List.generate(verses, (_) => '{start_of_verse}\n${List.filled(4, '[C]La la [G]la').join('\n')}\n{end_of_verse}').join('\n')}';

  /// The ids of the songs [start] created, in order.
  var ids = <String>[];

  /// Live mode with songs of [sources] and their [programs]; a null source
  /// is a break.
  Future<TestApp> start(
    WidgetTester tester, {
    Map<String, Object> prefs = midiOn,
    bool plugged = true,
    required List<String?> sources,
    List<MidiProgram?> programs = const [],
    String storedFor = 'nordStage3',
    MidiPrograms alsoStored = const MidiPrograms(),
  }) async {
    useTabletSize(tester);
    final app = await TestApp.create(
      prefs: {'language': 'en', 'instrument': 'keyboard', ...prefs},
    );
    if (plugged) app.midiOutput.ports = [_nord];
    ids = [];
    final items = (await tester.runAsync(() async {
      final items = <LiveItem>[];
      for (final (i, source) in sources.indexed) {
        if (source == null) {
          items.add(const LiveItem.marker(SetItemType.pause, 'Break'));
          continue;
        }
        final id = await app.songs.createSong(source: source);
        ids.add(id);
        if (i < programs.length && programs[i] != null) {
          await app.songs.setMidiProgram(
            id,
            storedFor,
            programs[i],
            deviceProfile: storedFor,
          );
        }
        for (final MapEntry(:key, :value) in alsoStored.byProfile.entries) {
          await app.songs.setMidiProgram(
            id,
            key,
            value,
            deviceProfile: storedFor,
          );
        }
        items.add(LiveItem.song((await app.songs.getSong(id))!));
      }
      return items;
    }))!;
    await tester.pumpWidget(app.build(home: LiveScreen(items: items)));
    await tester.pumpAndSettle();
    return app;
  }

  List<List<int>> bytes(List<MidiProgram> programs) => [
    for (final p in programs) p.bytes(1),
  ];

  Future<void> tapRight(WidgetTester tester) async {
    final page = tester.getRect(find.byType(PageView));
    await tester.tapAt(Offset(page.right - 20, page.bottom - 20));
    await tester.pumpAndSettle();
  }

  /// Lets the current item stay current long enough to send.
  Future<void> stay(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
  }

  testWidgets('sends the program on start and on song change, never for '
      'the prepared neighbour or a break', (tester) async {
    final app = await start(
      tester,
      sources: [
        '{title: One}\n[C]La',
        '{title: Two}\n[D]La',
        null,
        '{title: Four}\n[E]La',
      ],
      programs: [_piano, _organ, null, _piano],
    );
    final midi = app.midiOutput;
    await stay(tester);
    // The second song is prepared ahead, but only the first one is sent.
    expect(midi.sent, bytes([_piano]));
    expect(midi.sentTo, ['usb-1']);

    await tapRight(tester);
    await stay(tester);
    expect(midi.sent, bytes([_piano, _organ]));

    // The break sends nothing; the keyboard keeps its program.
    await tapRight(tester);
    await stay(tester);
    expect(midi.sent, bytes([_piano, _organ]));

    await tapRight(tester);
    await stay(tester);
    expect(midi.sent, bytes([_piano, _organ, _piano]));
    await app.dispose(tester);
  });

  testWidgets("only the program of the device's profile is sent "
      '(ADR-0042)', (tester) async {
    // Programs for the Nord only: a device with the generic profile sends
    // nothing.
    var app = await start(
      tester,
      prefs: {...midiOn, 'midiProfile': 'generic'},
      sources: ['{title: One}\n[C]La'],
      programs: [_organ],
    );
    await stay(tester);
    expect(app.midiOutput.sent, isEmpty);
    await app.dispose(tester);

    // Programs for both: the generic one is sent.
    app = await start(
      tester,
      prefs: {...midiOn, 'midiProfile': 'generic'},
      sources: ['{title: One}\n[C]La'],
      programs: [_piano],
      storedFor: 'generic',
      alsoStored: const MidiPrograms({'nordStage3': _organ}),
    );
    await stay(tester);
    expect(app.midiOutput.sent, bytes([_piano]));
    await app.dispose(tester);
  });

  testWidgets('a song turned past quickly sends nothing', (tester) async {
    final app = await start(
      tester,
      sources: [
        '{title: One}\n[C]La',
        '{title: Two}\n[D]La',
        '{title: Three}\n[E]La',
      ],
      programs: [_piano, _organ, _piano],
    );
    final midi = app.midiOutput;
    await stay(tester);
    expect(midi.sent, bytes([_piano]));
    // The second song is current for less than 300 ms.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text('2 / 3'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text('3 / 3'), findsOneWidget);
    await stay(tester);
    // The organ of the second song was never sent.
    expect(midi.sent, bytes([_piano, _piano]));
    await app.dispose(tester);
  });

  testWidgets('turning a page within a song sends nothing', (tester) async {
    final app = await start(
      tester,
      sources: [versesSong(16), '{title: Two}\n[D]La'],
      programs: [_organ, _piano],
    );
    final midi = app.midiOutput;
    await stay(tester);
    expect(find.text('Page 1/2'), findsOneWidget);
    expect(midi.sent, bytes([_organ]));

    await tapRight(tester);
    await stay(tester);
    expect(find.text('Page 2/2'), findsOneWidget);
    expect(midi.sent, bytes([_organ]));

    await tapRight(tester);
    await stay(tester);
    expect(midi.sent, bytes([_organ, _piano]));
    await app.dispose(tester);
  });

  testWidgets('"Send program again" and the indicator while connected', (
    tester,
  ) async {
    final app = await start(
      tester,
      sources: ['{title: One}\n[C]La'],
      programs: [_piano],
    );
    final midi = app.midiOutput;
    await stay(tester);
    expect(find.byKey(const Key('live-midi-connected')), findsOneWidget);
    expect(find.byTooltip('Keyboard connected: Nord Stage 3'), findsOneWidget);
    expect(find.byKey(const Key('live-midi-program')), findsOneWidget);
    expect(midi.sent, bytes([_piano]));

    await tester.tapAt(tester.getCenter(find.byType(PageView)));
    await tester.pumpAndSettle();
    // A long press on the keyboard symbol sends at once (#607).
    await tester.longPress(find.byKey(const Key('live-midi-button')));
    await tester.pumpAndSettle();
    expect(midi.sent, bytes([_piano, _piano]));
    expect(find.byKey(const Key('live-midi-sheet')), findsNothing);
    await app.dispose(tester);
  });

  testWidgets('not connected: the indicator says so and nothing is sent', (
    tester,
  ) async {
    final app = await start(
      tester,
      plugged: false,
      sources: ['{title: One}\n[C]La'],
      programs: [_piano],
    );
    await stay(tester);
    expect(find.byKey(const Key('live-midi-not-connected')), findsOneWidget);
    expect(find.byTooltip('Keyboard not connected'), findsOneWidget);
    expect(app.midiOutput.sent, isEmpty);
    // No dialog.
    expect(find.byType(AlertDialog), findsNothing);
    await app.dispose(tester);
  });

  testWidgets("the indicator shows the current song's program (#605)", (
    tester,
  ) async {
    final app = await start(
      tester,
      plugged: false,
      sources: ['{title: One}\n[C]La', '{title: Two}\n[D]La', null],
      programs: [_piano, null],
    );
    await stay(tester);
    expect(find.byKey(const Key('live-midi-not-connected')), findsOneWidget);
    final label = find.byKey(const Key('live-midi-program'));
    expect(label, findsOneWidget);
    expect(tester.widget<Text>(label).data, 'A:12');

    // A song without a program and a break show none.
    await tapRight(tester);
    expect(label, findsNothing);
    await tapRight(tester);
    expect(label, findsNothing);
    await app.dispose(tester);
  });

  testWidgets('the program shown is the one of the device\'s profile '
      '(ADR-0042, #605)', (tester) async {
    final app = await start(
      tester,
      prefs: {...midiOn, 'midiProfile': 'generic'},
      sources: ['{title: One}\n[C]La'],
      programs: [_organ],
    );
    // Only a Nord program: the generic profile shows none.
    expect(find.byKey(const Key('live-midi-program')), findsNothing);
    await app.dispose(tester);
  });

  testWidgets('MIDI off: no indicator, no "Send program again", nothing '
      'sent', (tester) async {
    final app = await start(
      tester,
      prefs: const {},
      sources: ['{title: One}\n[C]La'],
      programs: [_piano],
    );
    await stay(tester);
    expect(find.byKey(const Key('live-midi-connected')), findsNothing);
    expect(find.byKey(const Key('live-midi-not-connected')), findsNothing);
    await tester.tapAt(tester.getCenter(find.byType(PageView)));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Set overview'), findsOneWidget);
    expect(find.byKey(const Key('live-midi-button')), findsNothing);
    expect(app.midiOutput.sent, isEmpty);
    await app.dispose(tester);
  });

  testWidgets('another instrument: no indicator, no "Send program again", '
      'nothing sent although MIDI is on (#578)', (tester) async {
    final app = await start(
      tester,
      prefs: const {...midiOn, 'instrument': 'guitar'},
      sources: ['{title: One}\n[C]La'],
      programs: [_piano],
    );
    await stay(tester);
    expect(find.byKey(const Key('live-midi-connected')), findsNothing);
    expect(find.byKey(const Key('live-midi-not-connected')), findsNothing);
    await tester.tapAt(tester.getCenter(find.byType(PageView)));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Set overview'), findsOneWidget);
    expect(find.byKey(const Key('live-midi-button')), findsNothing);
    expect(app.midiOutput.sent, isEmpty);
    await app.dispose(tester);
  });

  testWidgets('a break offers no "Send program again"', (tester) async {
    final app = await start(tester, sources: [null]);
    await tester.tapAt(tester.getCenter(find.byType(PageView)));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Set overview'), findsOneWidget);
    expect(find.byKey(const Key('live-midi-button')), findsNothing);
    expect(find.byKey(const Key('live-midi-connected')), findsOneWidget);
    await app.dispose(tester);
  });

  group('the keyboard program sheet (#607)', () {
    Future<void> openSheet(WidgetTester tester) async {
      // The controls may still be shown from before.
      if (find.byKey(const Key('live-midi-button')).evaluate().isEmpty) {
        await tester.tapAt(tester.getCenter(find.byType(PageView)));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byKey(const Key('live-midi-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('live-midi-sheet')), findsOneWidget);
    }

    Future<MidiProgram?> stored(WidgetTester tester, TestApp app, int i) =>
        tester
            .runAsync(() => app.songs.midiProgram(ids[i], 'nordStage3'))
            .then((p) => p);

    String current(WidgetTester tester) => tester
        .widget<Text>(find.byKey(const Key('live-midi-sheet-current')))
        .data!;

    // Bank B with the page and button of _piano (A:12).
    const bankB = MidiProgram(msb: 0, lsb: 0, program: 26);

    testWidgets('shows the program and sends it again', (tester) async {
      final app = await start(
        tester,
        sources: ['{title: One}\n[C]La'],
        programs: [_piano],
      );
      await stay(tester);
      await openSheet(tester);
      expect(current(tester), 'Program A:12');
      await tester.tap(find.byKey(const Key('live-midi-sheet-send')));
      await tester.pumpAndSettle();
      expect(app.midiOutput.sent, bytes([_piano, _piano]));
      expect(find.byKey(const Key('live-midi-sheet')), findsNothing);
      await app.dispose(tester);
    });

    testWidgets('changing saves and sends at once; Undo restores and sends '
        'the old program', (tester) async {
      final app = await start(
        tester,
        sources: ['{title: One}\n[C]La'],
        programs: [_piano],
      );
      await stay(tester);
      await openSheet(tester);
      await tester.tap(find.byKey(const Key('live-midi-sheet-change')));
      await tester.pumpAndSettle();
      // Without the preview nothing is sent while choosing.
      await tester.tap(find.byKey(const Key('midi-bank-1')));
      await tester.pumpAndSettle();
      expect(app.midiOutput.sent, bytes([_piano]));
      await tester.tap(find.byKey(const Key('midi-program-save')));
      await tester.pumpAndSettle();
      expect(await stored(tester, app, 0), bankB);
      expect(app.midiOutput.sent, bytes([_piano, bankB]));
      expect(find.text('Keyboard program saved'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('live-midi-program'))).data,
        'B:12',
      );

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(await stored(tester, app, 0), _piano);
      expect(app.midiOutput.sent, bytes([_piano, bankB, _piano]));
      await app.dispose(tester);
    });

    testWidgets('the preview sends each choice, Cancel sends the song\'s '
        'program again, and the switch is remembered', (tester) async {
      final app = await start(
        tester,
        sources: ['{title: One}\n[C]La'],
        programs: [_piano],
      );
      await stay(tester);
      await openSheet(tester);
      await tester.tap(find.byKey(const Key('live-midi-sheet-change')));
      await tester.pumpAndSettle();
      final toggle = find.byKey(const Key('midi-program-preview-switch'));
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      // Switching it on sends nothing: the keyboard plays the program.
      expect(app.midiOutput.sent, bytes([_piano]));
      expect(app.prefs.getBool('midiPreview'), isTrue);
      await tester.ensureVisible(find.byKey(const Key('midi-bank-1')));
      await tester.tap(find.byKey(const Key('midi-bank-1')));
      await tester.pumpAndSettle();
      expect(app.midiOutput.sent, bytes([_piano, bankB]));

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(app.midiOutput.sent, bytes([_piano, bankB, _piano]));
      expect(await stored(tester, app, 0), _piano);

      // Next time the preview is on from the start.
      await openSheet(tester);
      await tester.tap(find.byKey(const Key('live-midi-sheet-change')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(toggle);
      expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
      await app.dispose(tester);
    });

    testWidgets('with the preview on, opening the picker for a song '
        'without a program sends nothing until a choice', (tester) async {
      final app = await start(
        tester,
        prefs: {...midiOn, 'midiPreview': true},
        sources: ['{title: One}\n[C]La'],
      );
      await stay(tester);
      await openSheet(tester);
      await tester.tap(find.byKey(const Key('live-midi-sheet-change')));
      await tester.pumpAndSettle();
      expect(app.midiOutput.sent, isEmpty);
      await tester.tap(find.byKey(const Key('midi-bank-1')));
      await tester.pumpAndSettle();
      expect(
        app.midiOutput.sent,
        bytes([const MidiProgram(msb: 0, lsb: 0, program: 25)]),
      );
      // Cancelled: the song has no program, the keyboard keeps the sound.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(app.midiOutput.sent.length, 1);
      expect(await stored(tester, app, 0), isNull);
      await app.dispose(tester);
    });

    testWidgets('a song without a program offers to set one; nothing to '
        'send or remove', (tester) async {
      final app = await start(tester, sources: ['{title: One}\n[C]La']);
      await stay(tester);
      await openSheet(tester);
      expect(current(tester), 'None: the keyboard keeps its sound');
      expect(find.text('Choose program'), findsOneWidget);
      expect(
        tester
            .widget<ListTile>(find.byKey(const Key('live-midi-sheet-send')))
            .enabled,
        isFalse,
      );
      expect(find.byKey(const Key('live-midi-sheet-remove')), findsNothing);
      await app.dispose(tester);
    });

    testWidgets('"Same as previous song" takes the nearest earlier song '
        'with a program, skipping breaks and songs without one', (
      tester,
    ) async {
      final app = await start(
        tester,
        sources: [
          '{title: One}\n[C]La',
          '{title: Two}\n[D]La',
          null,
          '{title: Four}\n[E]La',
          '{title: Five}\n[F]La',
        ],
        programs: [_piano, _organ, null, null, null],
      );
      for (var i = 0; i < 4; i++) {
        await tapRight(tester);
      }
      await stay(tester);
      expect(find.text('5 / 5'), findsOneWidget);
      final sentBefore = app.midiOutput.sent.length;
      await openSheet(tester);
      final previous = find.byKey(const Key('live-midi-sheet-previous'));
      expect(
        find.descendant(of: previous, matching: find.text('K:33 – from “Two”')),
        findsOneWidget,
      );
      await tester.tap(previous);
      await tester.pumpAndSettle();
      expect(await stored(tester, app, 3), _organ);
      expect(app.midiOutput.sent.length, sentBefore + 1);
      expect(app.midiOutput.sent.last, _organ.bytes(1));
      await app.dispose(tester);
    });

    testWidgets('"Same as previous song" is off for the first song', (
      tester,
    ) async {
      final app = await start(
        tester,
        sources: ['{title: One}\n[C]La'],
        programs: [_piano],
      );
      await openSheet(tester);
      final previous = find.byKey(const Key('live-midi-sheet-previous'));
      expect(tester.widget<ListTile>(previous).enabled, isFalse);
      expect(find.text('No earlier song with a program'), findsOneWidget);
      await app.dispose(tester);
    });

    testWidgets('removing sends nothing; Undo brings it back', (tester) async {
      final app = await start(
        tester,
        sources: ['{title: One}\n[C]La'],
        programs: [_piano],
      );
      await stay(tester);
      await openSheet(tester);
      await tester.tap(find.byKey(const Key('live-midi-sheet-remove')));
      await tester.pumpAndSettle();
      expect(await stored(tester, app, 0), isNull);
      expect(app.midiOutput.sent, bytes([_piano]));
      expect(find.text('Keyboard program removed'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(await stored(tester, app, 0), _piano);
      expect(app.midiOutput.sent, bytes([_piano]));
      await app.dispose(tester);
    });

    group('taking over from the keyboard (#608)', () {
      const takeOverOn = {...midiOn, 'midiTakeOver': true};
      final tile = find.byKey(const Key('live-midi-sheet-take-over'));

      testWidgets('off: the sheet does not listen', (tester) async {
        final app = await start(
          tester,
          sources: ['{title: One}\n[C]La'],
          programs: [_piano],
        );
        await openSheet(tester);
        expect(tile, findsNothing);
        await app.dispose(tester);
      });

      testWidgets('the Motif XF profile offers nothing to take over', (
        tester,
      ) async {
        final app = await start(
          tester,
          prefs: {...takeOverOn, 'midiProfile': 'motifXf'},
          sources: ['{title: One}\n[C]La'],
        );
        await openSheet(tester);
        expect(tile, findsNothing);
        await app.dispose(tester);
      });

      testWidgets('shows what the keyboard sends and takes it over without '
          'sending; Undo restores', (tester) async {
        final app = await start(
          tester,
          prefs: takeOverOn,
          sources: ['{title: One}\n[C]La'],
          programs: [_piano],
        );
        await stay(tester);
        await openSheet(tester);
        expect(
          find.descendant(
            of: tile,
            matching: find.text('Choose a sound on the keyboard'),
          ),
          findsOneWidget,
        );
        expect(tester.widget<ListTile>(tile).enabled, isFalse);

        // Another channel is not this keyboard.
        app.midiOutput.receive([0xB1, 0, 0, 0xB1, 32, 2, 0xC1, 12]);
        await tester.pumpAndSettle();
        expect(tester.widget<ListTile>(tile).enabled, isFalse);

        // K:33, as the Nord sends it, in separate messages.
        app.midiOutput
          ..receive([0xB0, 0, 0])
          ..receive([0xB0, 32, 2])
          ..receive([0xC0, 12]);
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: tile,
            matching: find.text('Take over: Program K:33'),
          ),
          findsOneWidget,
        );
        await tester.tap(tile);
        await tester.pumpAndSettle();
        expect(await stored(tester, app, 0), _organ);
        // The keyboard plays it already.
        expect(app.midiOutput.sent, bytes([_piano]));
        expect(find.text('Keyboard program saved'), findsOneWidget);

        await tester.tap(find.text('Undo'));
        await tester.pumpAndSettle();
        expect(await stored(tester, app, 0), _piano);
        expect(app.midiOutput.sent, bytes([_piano]));

        // Closed: nothing is listened to any more.
        app.midiOutput.receive([0xC0, 3]);
        await tester.pumpAndSettle();
        expect(await stored(tester, app, 0), _piano);
        await app.dispose(tester);
      });

      testWidgets("the song's own program cannot be taken over again", (
        tester,
      ) async {
        final app = await start(
          tester,
          prefs: takeOverOn,
          sources: ['{title: One}\n[C]La'],
          programs: [_organ],
        );
        await openSheet(tester);
        app.midiOutput.receive([0xB0, 0, 0, 0xB0, 32, 2, 0xC0, 12]);
        await tester.pumpAndSettle();
        expect(tester.widget<ListTile>(tile).enabled, isFalse);
        expect(find.text("This is the song's program already"), findsOneWidget);
        await app.dispose(tester);
      });
    });
  });
}

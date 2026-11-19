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
    final items = (await tester.runAsync(() async {
      final items = <LiveItem>[];
      for (final (i, source) in sources.indexed) {
        if (source == null) {
          items.add(const LiveItem.marker(SetItemType.pause, 'Break'));
          continue;
        }
        final id = await app.songs.createSong(source: source);
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
    await tester.tap(find.byTooltip('Send program again'));
    await tester.pumpAndSettle();
    expect(midi.sent, bytes([_piano, _piano]));
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
    expect(find.byTooltip('Send program again'), findsNothing);
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
    expect(find.byTooltip('Send program again'), findsNothing);
    expect(app.midiOutput.sent, isEmpty);
    await app.dispose(tester);
  });

  testWidgets('a break offers no "Send program again"', (tester) async {
    final app = await start(tester, sources: [null]);
    await tester.tapAt(tester.getCenter(find.byType(PageView)));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Set overview'), findsOneWidget);
    expect(find.byTooltip('Send program again'), findsNothing);
    expect(find.byKey(const Key('live-midi-connected')), findsOneWidget);
    await app.dispose(tester);
  });
}

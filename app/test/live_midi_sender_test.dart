import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:setding/midi/live_midi_sender.dart';
import 'package:setding/midi/midi_message.dart';

/// Sending the keyboard program of the current song in live mode
/// (ADR-0039). Run as widget tests for the fake clock of `tester.pump`.
void main() {
  const piano = MidiProgram(msb: 0, lsb: 0, program: 1);
  const organ = MidiProgram(msb: 0, lsb: 2, program: 12);
  const delay = Duration(milliseconds: 300);

  late Map<String, MidiProgram?> programs;
  late List<String> reads;
  late List<MidiProgram> sent;
  late bool enabled;
  late LiveMidiSender sender;

  void setUpSender() {
    programs = {'a': piano, 'b': organ, 'c': piano, 'none': null};
    reads = [];
    sent = [];
    enabled = true;
    sender = LiveMidiSender(
      enabled: () => enabled,
      program: (id) async {
        reads.add(id);
        return programs[id];
      },
      send: (program) {
        sent.add(program);
        return true;
      },
    );
  }

  testWidgets('sends the program of the first song once it stayed current', (
    tester,
  ) async {
    setUpSender();
    sender.show(0, 'a');
    await tester.pump(delay - const Duration(milliseconds: 1));
    expect(sent, isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    expect(sent, [piano]);
    // Once only.
    await tester.pump(delay * 3);
    expect(sent, [piano]);
    sender.dispose();
  });

  testWidgets('another song sends its program', (tester) async {
    setUpSender();
    sender.show(0, 'a');
    await tester.pump(delay);
    sender.show(1, 'b');
    await tester.pump(delay);
    expect(sent, [piano, organ]);
    sender.dispose();
  });

  testWidgets('songs swiped past quickly send nothing', (tester) async {
    setUpSender();
    sender.show(0, 'a');
    await tester.pump(const Duration(milliseconds: 100));
    sender.show(1, 'b');
    await tester.pump(const Duration(milliseconds: 200));
    sender.show(2, 'c');
    await tester.pump(delay);
    expect(sent, [piano]);
    expect(reads, ['c']);
    sender.dispose();
  });

  testWidgets('the same program is sent again for the next song', (
    tester,
  ) async {
    setUpSender();
    sender.show(0, 'a');
    await tester.pump(delay);
    sender.show(1, 'c');
    await tester.pump(delay);
    expect(sent, [piano, piano]);
    // The same song again later in the set sends too.
    sender.show(2, 'a');
    await tester.pump(delay);
    expect(sent, [piano, piano, piano]);
    sender.dispose();
  });

  testWidgets('songs without a program, breaks and text items send nothing', (
    tester,
  ) async {
    setUpSender();
    sender.show(0, 'none');
    await tester.pump(delay);
    sender.show(1, null);
    await tester.pump(delay);
    expect(sent, isEmpty);
    expect(reads, ['none']);
    // A break reached quickly stops the song before it from sending.
    sender.show(2, 'a');
    await tester.pump(const Duration(milliseconds: 100));
    sender.show(3, null);
    await tester.pump(delay);
    expect(sent, isEmpty);
    expect(await sender.sendAgain(), isFalse);
    sender.dispose();
  });

  testWidgets('showing the current item again sends nothing', (tester) async {
    setUpSender();
    sender.show(0, 'a');
    await tester.pump(delay);
    sender.show(0, 'a');
    await tester.pump(delay);
    expect(sent, [piano]);
    sender.dispose();
  });

  testWidgets('sends the program as stored at the moment of sending', (
    tester,
  ) async {
    setUpSender();
    sender.show(0, 'a');
    await tester.pump(const Duration(milliseconds: 100));
    programs['a'] = organ;
    await tester.pump(delay);
    expect(sent, [organ]);
    sender.dispose();
  });

  testWidgets('a program read for an item no longer current is not sent', (
    tester,
  ) async {
    final slow = Completer<MidiProgram?>();
    final sent = <MidiProgram>[];
    final sender = LiveMidiSender(
      enabled: () => true,
      program: (id) => id == 'a' ? slow.future : Future.value(organ),
      send: (program) {
        sent.add(program);
        return true;
      },
    );
    sender.show(0, 'a');
    await tester.pump(delay);
    sender.show(1, 'b');
    slow.complete(piano);
    await tester.pump(delay);
    expect(sent, [organ]);
    sender.dispose();
  });

  testWidgets('while MIDI is off nothing is read or sent', (tester) async {
    setUpSender();
    enabled = false;
    sender.show(0, 'a');
    await tester.pump(delay);
    expect(await sender.sendAgain(), isFalse);
    expect(reads, isEmpty);
    expect(sent, isEmpty);
    sender.dispose();
  });

  testWidgets('"Send program again" sends the current song now', (
    tester,
  ) async {
    setUpSender();
    sender.show(0, 'a');
    await tester.pump(delay);
    expect(await sender.sendAgain(), isTrue);
    expect(sent, [piano, piano]);
    // Right after a song change: sent now, and not a second time.
    sender.show(1, 'b');
    expect(await sender.sendAgain(), isTrue);
    await tester.pump(delay);
    expect(sent, [piano, piano, organ]);
    sender.dispose();
  });

  testWidgets('nothing is sent after live mode was left', (tester) async {
    setUpSender();
    sender.show(0, 'a');
    sender.dispose();
    await tester.pump(delay);
    expect(sent, isEmpty);
  });

  testWidgets('a failing read is only logged', (tester) async {
    final sender = LiveMidiSender(
      enabled: () => true,
      program: (_) async => throw StateError('database closed'),
      send: (_) => fail('nothing to send'),
    );
    sender.show(0, 'a');
    await tester.pump(delay);
    expect(await sender.sendAgain(), isFalse);
    sender.dispose();
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:setding/midi/midi_message.dart';

void main() {
  group('MidiProgram.bytes', () {
    test('bank select MSB and LSB come before the program change', () {
      const p = MidiProgram(msb: 0, lsb: 2, program: 12);
      expect(p.bytes(1), [0xB0, 0, 0, 0xB0, 32, 2, 0xC0, 12]);
    });

    test('uses the channel in every status byte', () {
      const p = MidiProgram(msb: 1, lsb: 7, program: 49);
      expect(p.bytes(16), [0xBF, 0, 1, 0xBF, 32, 7, 0xCF, 49]);
    });

    test('leaves out a bank select that is not set', () {
      expect(const MidiProgram(program: 5).bytes(1), [0xC0, 5]);
      expect(const MidiProgram(lsb: 3, program: 5).bytes(2), [
        0xB1,
        32,
        3,
        0xC1,
        5,
      ]);
    });

    test('rejects channels outside 1–16', () {
      const p = MidiProgram(program: 0);
      expect(() => p.bytes(0), throwsRangeError);
      expect(() => p.bytes(17), throwsRangeError);
    });
  });

  group('MidiProgram JSON (ADR-0039)', () {
    test('stores the raw values, without an unset bank select', () {
      expect(const MidiProgram(msb: 0, lsb: 2, program: 12).toJson(), {
        'msb': 0,
        'lsb': 2,
        'program': 12,
      });
      expect(const MidiProgram(program: 5).toJson(), {'program': 5});
      expect(const MidiProgram(lsb: 3, program: 5).toJson(), {
        'lsb': 3,
        'program': 5,
      });
    });

    test('reads what it stores', () {
      for (final p in const [
        MidiProgram(msb: 1, lsb: 7, program: 49),
        MidiProgram(program: 0),
        MidiProgram(msb: 6, program: 127),
      ]) {
        expect(MidiProgram.fromJson(p.toJson()), p);
      }
      // JSON numbers may arrive as doubles.
      expect(
        MidiProgram.fromJson({'msb': 0.0, 'program': 12.0}),
        const MidiProgram(msb: 0, program: 12),
      );
      expect(
        MidiProgram.fromJson({'msb': null, 'lsb': null, 'program': 3}),
        const MidiProgram(program: 3),
      );
    });

    test('anything else is no program', () {
      for (final json in <Object?>[
        null,
        'x',
        42,
        <String, dynamic>{},
        {'msb': 0},
        {'program': 128},
        {'program': -1},
        {'program': 1.5},
        {'program': '1'},
        {'msb': 128, 'program': 1},
        {'lsb': 'a', 'program': 1},
      ]) {
        expect(MidiProgram.fromJson(json), isNull, reason: '$json');
      }
    });
  });

  group('NordStage3', () {
    // Observed on a Nord Stage 3 (#512).
    test('programs are counted through in blocks of 125', () {
      expect(
        NordStage3.program(0, 1, 1),
        const MidiProgram(msb: 0, lsb: 0, program: 0),
      );
      // K:33 = 10 * 25 + 12 = 262 = block 2, place 12.
      expect(
        NordStage3.program(10, 3, 3),
        const MidiProgram(msb: 0, lsb: 2, program: 12),
      );
      expect(
        NordStage3.program(15, 5, 5),
        const MidiProgram(msb: 0, lsb: 3, program: 24),
      );
    });

    test('the second block starts with F:11', () {
      expect(
        NordStage3.program(4, 5, 5),
        const MidiProgram(msb: 0, lsb: 0, program: 124),
      );
      expect(
        NordStage3.program(5, 1, 1),
        const MidiProgram(msb: 0, lsb: 1, program: 0),
      );
    });

    test('names as on the display', () {
      expect(NordStage3.programName(10, 3, 3), 'K:33');
      expect(NordStage3.programName(15, 5, 5), 'P:55');
    });

    test('songs use MSB 1, the same blocks and 5 parts per song', () {
      expect(NordStage3.song(1), const MidiProgram(msb: 1, lsb: 0, program: 0));
      expect(
        NordStage3.song(1, 2),
        const MidiProgram(msb: 1, lsb: 0, program: 1),
      );
      expect(NordStage3.song(2), const MidiProgram(msb: 1, lsb: 0, program: 5));
      // Observed: song 26 part 1.
      expect(
        NordStage3.song(26),
        const MidiProgram(msb: 1, lsb: 1, program: 0),
      );
      expect(
        NordStage3.song(NordStage3.maxSong, 5),
        const MidiProgram(msb: 1, lsb: 3, program: 124),
      );
    });

    test('live memories as the Nord sends them: MSB 6, program 0–4', () {
      expect(NordStage3.live(1), const MidiProgram(msb: 6, lsb: 0, program: 0));
      expect(NordStage3.live(5), const MidiProgram(msb: 6, lsb: 0, program: 4));
    });

    test('rejects values outside the ranges', () {
      expect(() => NordStage3.program(16, 1, 1), throwsRangeError);
      expect(() => NordStage3.program(0, 0, 1), throwsRangeError);
      expect(() => NordStage3.program(0, 1, 6), throwsRangeError);
      expect(() => NordStage3.song(0), throwsRangeError);
      expect(() => NordStage3.song(101), throwsRangeError);
      expect(() => NordStage3.song(1, 6), throwsRangeError);
      expect(() => NordStage3.live(0), throwsRangeError);
      expect(() => NordStage3.live(6), throwsRangeError);
    });
  });

  group('midiControlChange', () {
    test('status byte with channel, controller, value', () {
      expect(midiControlChange(1, 3, 127), [0xB0, 3, 127]);
      expect(midiControlChange(16, 5, 0), [0xBF, 5, 0]);
    });

    test('rejects values outside 0–127 and channels outside 1–16', () {
      expect(() => midiControlChange(0, 3, 1), throwsRangeError);
      expect(() => midiControlChange(1, 128, 1), throwsRangeError);
      expect(() => midiControlChange(1, 3, -1), throwsRangeError);
    });
  });

  test('midiHex writes upper-case pairs', () {
    expect(midiHex([0xB0, 0, 32, 0xC0, 12]), 'B0 00 20 C0 0C');
  });

  group('MidiEvent.parse', () {
    test('reads control and program changes with their channel', () {
      final cc = MidiEvent.parse([0xB2, 32, 5]);
      expect(cc, isA<MidiControlChange>());
      cc as MidiControlChange;
      expect((cc.channel, cc.controller, cc.value), (3, 32, 5));

      final pc = MidiEvent.parse([0xC0, 12]);
      expect(pc, isA<MidiProgramChange>());
      pc as MidiProgramChange;
      expect((pc.channel, pc.program), (1, 12));
    });

    test('returns null for other or incomplete messages', () {
      expect(MidiEvent.parse([]), isNull);
      expect(MidiEvent.parse([0x90, 60, 100]), isNull);
      expect(MidiEvent.parse([0xB0, 0]), isNull);
      expect(MidiEvent.parse([0xF8]), isNull);
    });
  });

  group('MidiProgramReceiver (#608)', () {
    test('collects bank select and program change sent one by one', () {
      final r = MidiProgramReceiver(1);
      expect(r.add([0xB0, 0, 0]), isNull);
      expect(r.add([0xB0, 32, 2]), isNull);
      expect(r.add([0xC0, 12]), const MidiProgram(msb: 0, lsb: 2, program: 12));
    });

    test('reads several messages in one packet', () {
      final r = MidiProgramReceiver(3);
      expect(
        r.add([0xB2, 0, 6, 0xB2, 32, 0, 0xC2, 4]),
        const MidiProgram(msb: 6, lsb: 0, program: 4),
      );
    });

    test('keeps the bank for a later program change; none before any', () {
      final r = MidiProgramReceiver(1);
      expect(r.add([0xC0, 7]), const MidiProgram(program: 7));
      r.add([0xB0, 0, 1, 0xB0, 32, 1, 0xC0, 0]);
      expect(r.add([0xC0, 5]), const MidiProgram(msb: 1, lsb: 1, program: 5));
    });

    test('skips other channels, other messages, real-time bytes and SysEx', () {
      final r = MidiProgramReceiver(1);
      expect(r.add([0xB1, 0, 5, 0xC1, 9]), isNull);
      expect(r.add([0xF8, 0xFE, 0x90, 60, 100, 0xB0, 7, 100]), isNull);
      expect(
        r.add([0xF0, 0x43, 0x10, 0x7F, 0xF7, 0xB0, 0, 0, 0xF8, 0xC0, 3]),
        const MidiProgram(msb: 0, program: 3),
      );
    });

    test('ignores incomplete and broken messages', () {
      final r = MidiProgramReceiver(1);
      expect(r.add([0xC0]), isNull);
      expect(r.add([0xB0, 0, 0xC0, 2]), const MidiProgram(program: 2));
    });
  });
}

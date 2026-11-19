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

  group('NordStage3', () {
    test('program C:13 is CC 0 = 0, CC 32 = 2, program change 12', () {
      expect(
        NordStage3.program(2, 13),
        const MidiProgram(msb: 0, lsb: 2, program: 12),
      );
    });

    test('first and last program of the banks', () {
      expect(
        NordStage3.program(0, 1),
        const MidiProgram(msb: 0, lsb: 0, program: 0),
      );
      expect(
        NordStage3.program(7, 50),
        const MidiProgram(msb: 0, lsb: 7, program: 49),
      );
    });

    test('songs use MSB 1', () {
      expect(
        NordStage3.song(4, 3),
        const MidiProgram(msb: 1, lsb: 4, program: 2),
      );
    });

    test('live memories are program changes 50–54 without bank select', () {
      expect(NordStage3.live(1), const MidiProgram(program: 50));
      expect(NordStage3.live(5), const MidiProgram(program: 54));
    });

    test('rejects values outside the ranges', () {
      expect(() => NordStage3.program(8, 1), throwsRangeError);
      expect(() => NordStage3.program(0, 0), throwsRangeError);
      expect(() => NordStage3.program(0, 51), throwsRangeError);
      expect(() => NordStage3.song(-1, 1), throwsRangeError);
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
}

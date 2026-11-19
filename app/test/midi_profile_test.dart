import 'package:flutter_test/flutter_test.dart';
import 'package:setding/midi/midi_message.dart';
import 'package:setding/midi/midi_profile.dart';

/// Device profiles of MIDI program changes (ADR-0039).
void main() {
  const nord = NordStage3Profile();
  const generic = GenericProfile();
  const motif = MotifXfProfile();

  group('Nord Stage 3', () {
    test('programs both ways, across the block borders', () {
      final cases = {
        const NordProgram(0, 1, 1): const MidiProgram(
          msb: 0,
          lsb: 0,
          program: 0,
        ),
        // E:55 is the last of the first block, F:11 the first of the next.
        const NordProgram(4, 5, 5): const MidiProgram(
          msb: 0,
          lsb: 0,
          program: 124,
        ),
        const NordProgram(5, 1, 1): const MidiProgram(
          msb: 0,
          lsb: 1,
          program: 0,
        ),
        const NordProgram(10, 3, 3): const MidiProgram(
          msb: 0,
          lsb: 2,
          program: 12,
        ),
        const NordProgram(15, 5, 5): const MidiProgram(
          msb: 0,
          lsb: 3,
          program: 24,
        ),
      };
      for (final MapEntry(key: patch, value: midi) in cases.entries) {
        expect(nord.toMidi(patch), midi, reason: '$patch');
        expect(nord.toPatch(midi), patch, reason: '$midi');
      }
      expect(
        (nord.toPatch(cases.values.elementAt(3)) as NordProgram).label,
        'K:33',
      );
    });

    test('every program translates back to itself', () {
      for (var bank = 0; bank < NordStage3.banks.length; bank++) {
        for (var page = 1; page <= NordStage3.pages; page++) {
          for (var button = 1; button <= NordStage3.buttons; button++) {
            final patch = NordProgram(bank, page, button);
            expect(nord.toPatch(nord.toMidi(patch)), patch);
          }
        }
      }
    });

    test('songs with parts both ways, across the block borders', () {
      final cases = {
        const NordSong(1): const MidiProgram(msb: 1, lsb: 0, program: 0),
        const NordSong(2, 3): const MidiProgram(msb: 1, lsb: 0, program: 7),
        const NordSong(25, 5): const MidiProgram(msb: 1, lsb: 0, program: 124),
        const NordSong(26): const MidiProgram(msb: 1, lsb: 1, program: 0),
        const NordSong(26, 5): const MidiProgram(msb: 1, lsb: 1, program: 4),
        const NordSong(NordStage3.maxSong, 5): const MidiProgram(
          msb: 1,
          lsb: 3,
          program: 124,
        ),
      };
      for (final MapEntry(key: patch, value: midi) in cases.entries) {
        expect(nord.toMidi(patch), midi, reason: '$patch');
        expect(nord.toPatch(midi), patch, reason: '$midi');
      }
    });

    test('live memories both ways', () {
      for (var n = 1; n <= NordStage3.liveMemories; n++) {
        final midi = MidiProgram(msb: 6, lsb: 0, program: n - 1);
        expect(nord.toMidi(NordLiveMemory(n)), midi);
        expect(nord.toPatch(midi), NordLiveMemory(n));
      }
    });

    test('the kind follows the stored MSB', () {
      const program = MidiProgram(msb: 0, lsb: 2, program: 12);
      const song = MidiProgram(msb: 1, lsb: 0, program: 7);
      const live = MidiProgram(msb: 6, lsb: 0, program: 2);
      expect(nord.toPatch(program), const NordProgram(10, 3, 3));
      expect(nord.toPatch(song), const NordSong(2, 3));
      expect(nord.toPatch(live), const NordLiveMemory(3));
    });

    test('a new program starts with program A:11', () {
      expect(nord.initialPatch, const NordProgram(0, 1, 1));
    });

    test('values the Nord does not send are shown as generic', () {
      for (final midi in [
        const MidiProgram(program: 12),
        const MidiProgram(msb: 0, program: 12),
        const MidiProgram(msb: 0, lsb: 4, program: 0),
        const MidiProgram(msb: 0, lsb: 0, program: 125),
        const MidiProgram(msb: 1, lsb: 4, program: 0),
        const MidiProgram(msb: 6, lsb: 0, program: 5),
        const MidiProgram(msb: 6, lsb: 1, program: 0),
        const MidiProgram(msb: 2, lsb: 0, program: 0),
      ]) {
        final patch = nord.toPatch(midi);
        expect(patch, isA<GenericProgram>(), reason: '$midi');
        expect(nord.toMidi(patch), midi, reason: '$midi');
      }
    });

    test('rejects values outside the ranges', () {
      expect(() => nord.toMidi(const NordProgram(16, 1, 1)), throwsRangeError);
      expect(() => nord.toMidi(const NordSong(1, 6)), throwsRangeError);
      expect(() => nord.toMidi(const NordLiveMemory(6)), throwsRangeError);
    });
  });

  group('generic', () {
    test('program 1–128 is sent as 0–127, bank select optional', () {
      final cases = {
        const GenericProgram(program: 1): const MidiProgram(program: 0),
        const GenericProgram(program: 128): const MidiProgram(program: 127),
        const GenericProgram(msb: 5, program: 13): const MidiProgram(
          msb: 5,
          program: 12,
        ),
        const GenericProgram(lsb: 127, program: 2): const MidiProgram(
          lsb: 127,
          program: 1,
        ),
        const GenericProgram(msb: 0, lsb: 2, program: 13): const MidiProgram(
          msb: 0,
          lsb: 2,
          program: 12,
        ),
      };
      for (final MapEntry(key: patch, value: midi) in cases.entries) {
        expect(generic.toMidi(patch), midi, reason: '$patch');
        expect(generic.toPatch(midi), patch, reason: '$midi');
      }
      expect(generic.initialPatch, const GenericProgram(program: 1));
    });

    test('shows Nord values as raw values', () {
      expect(
        generic.toPatch(const MidiProgram(msb: 0, lsb: 2, program: 12)),
        const GenericProgram(msb: 0, lsb: 2, program: 13),
      );
    });

    test('Nord patches are still sent by the generic profile', () {
      expect(
        generic.toMidi(const NordProgram(10, 3, 3)),
        const MidiProgram(msb: 0, lsb: 2, program: 12),
      );
    });

    test('rejects values outside the ranges', () {
      expect(
        () => generic.toMidi(const GenericProgram(program: 0)),
        throwsRangeError,
      );
      expect(
        () => generic.toMidi(const GenericProgram(program: 129)),
        throwsRangeError,
      );
      expect(
        () => generic.toMidi(const GenericProgram(msb: 128, program: 1)),
        throwsRangeError,
      );
      expect(
        () => generic.toMidi(const GenericProgram(lsb: -1, program: 1)),
        throwsRangeError,
      );
    });
  });

  group('Motif XF (#591)', () {
    test('voices and performances as in the MOTIF XF Data List', () {
      for (final (patch, expected) in [
        (
          const MotifVoice(0, 0),
          const MidiProgram(msb: 63, lsb: 0, program: 0),
        ),
        (
          const MotifVoice(7, 127),
          const MidiProgram(msb: 63, lsb: 7, program: 127),
        ),
        (
          const MotifVoice(8, 0),
          const MidiProgram(msb: 63, lsb: 8, program: 0),
        ),
        (
          const MotifVoice(11, 127),
          const MidiProgram(msb: 63, lsb: 11, program: 127),
        ),
        (
          const MotifVoice(12, 5),
          const MidiProgram(msb: 0, lsb: 0, program: 5),
        ),
        (
          const MotifVoice(13, 63),
          const MidiProgram(msb: 63, lsb: 32, program: 63),
        ),
        (
          const MotifVoice(14, 31),
          const MidiProgram(msb: 63, lsb: 40, program: 31),
        ),
        (
          const MotifVoice(15, 0),
          const MidiProgram(msb: 127, lsb: 0, program: 0),
        ),
        (
          const MotifPerformance(0, 0),
          const MidiProgram(msb: 63, lsb: 64, program: 0),
        ),
        (
          const MotifPerformance(1, 36),
          const MidiProgram(msb: 63, lsb: 65, program: 36),
        ),
        (
          const MotifPerformance(3, 127),
          const MidiProgram(msb: 63, lsb: 67, program: 127),
        ),
      ]) {
        expect(motif.toMidi(patch), expected, reason: '$patch');
        expect(motif.toPatch(expected), patch, reason: '$expected');
      }
    });

    test('labels as on the display: bank, group A–H, number 01–16', () {
      expect(const MotifVoice(8, 0).label, 'USR1 A01');
      expect(const MotifVoice(0, 127).label, 'PRE1 H16');
      expect(const MotifVoice(13, 16).label, 'PDR B01');
      expect(const MotifVoice(15, 0).label, 'GMDR A01');
      expect(const MotifPerformance(1, 36).label, 'USR2 C05');
      expect(MotifXf.programName(15), 'A16');
      expect(MotifXf.programName(16), 'B01');
      expect(MotifXf.voiceBanks[13].groups, 4);
      expect(MotifXf.voiceBanks[15].groups, 1);
    });

    test('values outside the Motif banks are shown as generic', () {
      for (final p in [
        const MidiProgram(program: 3),
        const MidiProgram(msb: 63, lsb: 12, program: 0),
        const MidiProgram(msb: 63, lsb: 32, program: 64),
        const MidiProgram(msb: 63, lsb: 40, program: 32),
        const MidiProgram(msb: 127, lsb: 0, program: 1),
        const MidiProgram(msb: 0, lsb: 2, program: 12),
      ]) {
        expect(motif.toPatch(p), isA<GenericProgram>(), reason: '$p');
      }
    });

    test('rejects values outside the banks', () {
      expect(() => motif.toMidi(const MotifVoice(16, 0)), throwsRangeError);
      expect(() => motif.toMidi(const MotifVoice(13, 64)), throwsRangeError);
      expect(() => motif.toMidi(const MotifVoice(15, 1)), throwsRangeError);
      expect(
        () => motif.toMidi(const MotifPerformance(4, 0)),
        throwsRangeError,
      );
      expect(
        () => motif.toMidi(const MotifPerformance(0, 128)),
        throwsRangeError,
      );
    });

    test('sends the mode change before bank select and program change', () {
      const voiceMode = [0xF0, 0x43, 0x10, 0x7F, 0x12, 0x0A, 0, 1, 0, 0xF7];
      const performanceMode = [
        0xF0, 0x43, 0x10, 0x7F, 0x12, 0x0A, 0, 1, 1, 0xF7, //
      ];
      expect(motif.bytes(const MidiProgram(msb: 63, lsb: 65, program: 36), 3), [
        ...performanceMode,
        0xB2,
        0,
        63,
        0xB2,
        32,
        65,
        0xC2,
        36,
      ]);
      expect(motif.bytes(const MidiProgram(msb: 63, lsb: 8, program: 0), 1), [
        ...voiceMode,
        0xB0,
        0,
        63,
        0xB0,
        32,
        8,
        0xC0,
        0,
      ]);
      expect(motif.bytes(const MidiProgram(msb: 0, lsb: 0, program: 0), 1), [
        ...voiceMode,
        0xB0,
        0,
        0,
        0xB0,
        32,
        0,
        0xC0,
        0,
      ]);
      // A value that is no Motif voice or performance: no mode change.
      expect(
        motif.bytes(const MidiProgram(program: 3), 1),
        const MidiProgram(program: 3).bytes(1),
      );
      expect(MotifXf.modeChange(MotifMode.master).last, 0xF7);
      expect(MotifXf.modeChange(MotifMode.master)[8], 4);
    });

    test('the other profiles send only bank select and program change', () {
      const p = MidiProgram(msb: 63, lsb: 64, program: 0);
      expect(nord.bytes(p, 2), p.bytes(2));
      expect(generic.bytes(p, 2), p.bytes(2));
    });
  });

  test('the profile of the settings', () {
    expect(MidiProfile.of(MidiProfileKind.nordStage3), nord);
    expect(MidiProfile.of(MidiProfileKind.generic), generic);
    expect(MidiProfile.of(MidiProfileKind.motifXf), motif);
    expect(
      MidiProfile.of(MidiProfileKind.generic).kind,
      MidiProfileKind.generic,
    );
  });
}

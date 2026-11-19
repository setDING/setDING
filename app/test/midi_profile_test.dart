import 'package:flutter_test/flutter_test.dart';
import 'package:setding/midi/midi_message.dart';
import 'package:setding/midi/midi_profile.dart';

/// Device profiles of MIDI program changes (ADR-0039).
void main() {
  const nord = NordStage3Profile();
  const generic = GenericProfile();

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

  test('the profile of the settings', () {
    expect(MidiProfile.of(MidiProfileKind.nordStage3), nord);
    expect(MidiProfile.of(MidiProfileKind.generic), generic);
    expect(
      MidiProfile.of(MidiProfileKind.generic).kind,
      MidiProfileKind.generic,
    );
  });
}

import 'package:flutter/foundation.dart';

import 'midi_message.dart';

/// The device profiles of the MIDI settings (ADR-0039).
enum MidiProfileKind { nordStage3, generic, motifXf }

/// A stored [MidiProgram] in the terms of the musician, e.g. "K:33" or
/// "song 2, part 3" (ADR-0039). A [MidiProfile] translates between the two.
@immutable
sealed class MidiPatch {
  const MidiPatch();
}

/// A Nord Stage 3 program: [bank] 0–15 (A–P), [page] 1–5, [button] 1–5.
final class NordProgram extends MidiPatch {
  const NordProgram(this.bank, this.page, this.button);

  final int bank;
  final int page;
  final int button;

  /// As on the Nord's display, e.g. `K:33`.
  String get label => NordStage3.programName(bank, page, button);

  @override
  bool operator ==(Object other) =>
      other is NordProgram &&
      other.bank == bank &&
      other.page == page &&
      other.button == button;

  @override
  int get hashCode => Object.hash(NordProgram, bank, page, button);

  @override
  String toString() => 'NordProgram($label)';
}

/// A Nord Stage 3 live memory 1–5.
final class NordLiveMemory extends MidiPatch {
  const NordLiveMemory(this.number);

  final int number;

  @override
  bool operator ==(Object other) =>
      other is NordLiveMemory && other.number == number;

  @override
  int get hashCode => Object.hash(NordLiveMemory, number);

  @override
  String toString() => 'NordLiveMemory($number)';
}

/// Part [part] (1–5) of the Nord Stage 3 song [song] (1–[NordStage3.maxSong]).
final class NordSong extends MidiPatch {
  const NordSong(this.song, [this.part = 1]);

  final int song;
  final int part;

  @override
  bool operator ==(Object other) =>
      other is NordSong && other.song == song && other.part == part;

  @override
  int get hashCode => Object.hash(NordSong, song, part);

  @override
  String toString() => 'NordSong($song, $part)';
}

/// A Yamaha Motif XF voice: [index] (0 to the bank's size − 1) of
/// [MotifXf.voiceBanks] [bank], shown as on the display, e.g. `USR1 A01`.
final class MotifVoice extends MidiPatch {
  const MotifVoice(this.bank, this.index);

  final int bank;
  final int index;

  String get label =>
      '${MotifXf.voiceBanks[bank].name} ${MotifXf.programName(index)}';

  @override
  bool operator ==(Object other) =>
      other is MotifVoice && other.bank == bank && other.index == index;

  @override
  int get hashCode => Object.hash(MotifVoice, bank, index);

  @override
  String toString() => 'MotifVoice($label)';
}

/// A Yamaha Motif XF performance: [index] (0–127) of
/// [MotifXf.performanceBanks] [bank] (user 1–4), e.g. `USR2 C05`.
final class MotifPerformance extends MidiPatch {
  const MotifPerformance(this.bank, this.index);

  final int bank;
  final int index;

  String get label =>
      '${MotifXf.performanceBanks[bank].name} ${MotifXf.programName(index)}';

  @override
  bool operator ==(Object other) =>
      other is MotifPerformance && other.bank == bank && other.index == index;

  @override
  int get hashCode => Object.hash(MotifPerformance, bank, index);

  @override
  String toString() => 'MotifPerformance($label)';
}

/// Any keyboard: bank select [msb] and [lsb] (each optional, 0–127) and
/// [program] 1–128 as most keyboards count them (sent as 0–127).
final class GenericProgram extends MidiPatch {
  const GenericProgram({this.msb, this.lsb, required this.program});

  final int? msb;
  final int? lsb;

  /// 1–128.
  final int program;

  @override
  bool operator ==(Object other) =>
      other is GenericProgram &&
      other.msb == msb &&
      other.lsb == lsb &&
      other.program == program;

  @override
  int get hashCode => Object.hash(GenericProgram, msb, lsb, program);

  @override
  String toString() =>
      'GenericProgram(msb: $msb, lsb: $lsb, program: $program)';
}

/// Translates between the raw values that are stored and sent
/// ([MidiProgram]) and what the musician sees ([MidiPatch]) for one kind of
/// keyboard (ADR-0039). A stored value is always readable: what a profile
/// does not know is shown as a [GenericProgram].
sealed class MidiProfile {
  const MidiProfile();

  /// The profile of the device settings.
  factory MidiProfile.of(MidiProfileKind kind) => switch (kind) {
    MidiProfileKind.nordStage3 => const NordStage3Profile(),
    MidiProfileKind.generic => const GenericProfile(),
    MidiProfileKind.motifXf => const MotifXfProfile(),
  };

  MidiProfileKind get kind;

  /// [program] in the terms of this profile. The kind of a Nord value
  /// follows its bank select MSB (program, song or live memory).
  MidiPatch toPatch(MidiProgram program);

  /// The raw values of [patch]. Throws a [RangeError] for values outside
  /// the ranges of the patch.
  MidiProgram toMidi(MidiPatch patch) => switch (patch) {
    NordProgram(:final bank, :final page, :final button) => NordStage3.program(
      bank,
      page,
      button,
    ),
    NordLiveMemory(:final number) => NordStage3.live(number),
    NordSong(:final song, :final part) => NordStage3.song(song, part),
    MotifVoice(:final bank, :final index) => MotifXf.voice(bank, index),
    MotifPerformance(:final bank, :final index) => MotifXf.performance(
      bank,
      index,
    ),
    GenericProgram(:final msb, :final lsb, :final program) => _generic(
      msb,
      lsb,
      program,
    ),
  };

  /// What a new program starts with in the editor.
  MidiPatch get initialPatch;

  /// The bytes that send [program] on [channel] (1–16): bank select and
  /// program change ([MidiProgram.bytes]), which a profile may precede with
  /// what its keyboard needs, e.g. the Motif XF's mode change (#591). The
  /// stored values stay the raw bank select and program change.
  Uint8List bytes(MidiProgram program, int channel) => program.bytes(channel);

  static MidiProgram _generic(int? msb, int? lsb, int program) {
    if (msb != null) RangeError.checkValueInInterval(msb, 0, 127, 'msb');
    if (lsb != null) RangeError.checkValueInInterval(lsb, 0, 127, 'lsb');
    RangeError.checkValueInInterval(program, 1, 128, 'program');
    return MidiProgram(msb: msb, lsb: lsb, program: program - 1);
  }
}

/// The Nord Stage 3 (ADR-0039): programs A–P / page / button and live
/// memories 1–5 and songs with parts 1–5.
final class NordStage3Profile extends MidiProfile {
  const NordStage3Profile();

  @override
  MidiProfileKind get kind => MidiProfileKind.nordStage3;

  @override
  MidiPatch get initialPatch => const NordProgram(0, 1, 1);

  @override
  MidiPatch toPatch(MidiProgram program) =>
      _nord(program) ?? const GenericProfile().toPatch(program);

  /// The inverse of [NordStage3.program], [NordStage3.song] and
  /// [NordStage3.live]; null for values the Nord does not send.
  static MidiPatch? _nord(MidiProgram p) {
    final (msb, lsb) = (p.msb, p.lsb);
    if (msb == null || lsb == null) return null;
    final index = lsb * NordStage3.programsPerBlock + p.program;
    if (p.program >= NordStage3.programsPerBlock) return null;
    switch (msb) {
      case 0 when index < NordStage3.banks.length * NordStage3.programsPerBank:
        final inBank = index % NordStage3.programsPerBank;
        return NordProgram(
          index ~/ NordStage3.programsPerBank,
          inBank ~/ NordStage3.buttons + 1,
          inBank % NordStage3.buttons + 1,
        );
      case 1 when index < NordStage3.maxSong * NordStage3.partsPerSong:
        return NordSong(
          index ~/ NordStage3.partsPerSong + 1,
          index % NordStage3.partsPerSong + 1,
        );
      case 6 when lsb == 0 && p.program < NordStage3.liveMemories:
        return NordLiveMemory(p.program + 1);
    }
    return null;
  }

  @override
  bool operator ==(Object other) => other is NordStage3Profile;

  @override
  int get hashCode => (NordStage3Profile).hashCode;
}

/// Any keyboard: bank select MSB and LSB, program 1–128 (ADR-0039).
final class GenericProfile extends MidiProfile {
  const GenericProfile();

  @override
  MidiProfileKind get kind => MidiProfileKind.generic;

  @override
  MidiPatch get initialPatch => const GenericProgram(program: 1);

  @override
  MidiPatch toPatch(MidiProgram program) => GenericProgram(
    msb: program.msb,
    lsb: program.lsb,
    program: program.program + 1,
  );

  @override
  bool operator ==(Object other) => other is GenericProfile;

  @override
  int get hashCode => (GenericProfile).hashCode;
}

/// The Yamaha Motif XF (ADR-0039, #591): voices and performances, sent with
/// the mode change to voice or performance mode first, as a program change
/// only works in the Motif's current mode.
final class MotifXfProfile extends MidiProfile {
  const MotifXfProfile();

  @override
  MidiProfileKind get kind => MidiProfileKind.motifXf;

  @override
  MidiPatch get initialPatch => const MotifPerformance(0, 0);

  @override
  MidiPatch toPatch(MidiProgram program) {
    // Performances first: their banks do not overlap the voice banks.
    if (MotifXf.bankOf(MotifXf.performanceBanks, program) case final b?) {
      return MotifPerformance(b, program.program);
    }
    if (MotifXf.bankOf(MotifXf.voiceBanks, program) case final b?) {
      return MotifVoice(b, program.program);
    }
    return const GenericProfile().toPatch(program);
  }

  @override
  Uint8List bytes(MidiProgram program, int channel) {
    final mode = switch (toPatch(program)) {
      MotifVoice() => MotifMode.voice,
      MotifPerformance() => MotifMode.performance,
      _ => null,
    };
    final change = program.bytes(channel);
    if (mode == null) return change;
    return Uint8List.fromList([...MotifXf.modeChange(mode), ...change]);
  }

  @override
  bool operator ==(Object other) => other is MotifXfProfile;

  @override
  int get hashCode => (MotifXfProfile).hashCode;
}

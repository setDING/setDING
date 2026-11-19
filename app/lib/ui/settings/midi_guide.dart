import 'dart:typed_data';

import '../../l10n/generated/app_localizations.dart';
import '../../midi/midi_message.dart';
import '../../midi/midi_profile.dart';
import '../songs/midi_program_field.dart';

/// What the tester saw on the keyboard after a step of the guided test.
enum MidiGuideAnswer {
  asExpected,
  different,
  nothing;

  String label(AppLocalizations l10n) => switch (this) {
    asExpected => l10n.midiGuideAnswerAsExpected,
    different => l10n.midiGuideAnswerDifferent,
    nothing => l10n.midiGuideAnswerNothing,
  };
}

/// One step of a guided test: what is sent and what should happen, or
/// (a receive step, #613) what to choose on the keyboard and which program
/// it should send then.
class MidiGuideStep {
  const MidiGuideStep({
    required this.title,
    required this.expected,
    required Uint8List Function(int channel) this.bytes,
  }) : receive = null;

  /// The tester chooses [title] on the keyboard; it should send [receive].
  const MidiGuideStep.receive({
    required this.title,
    required this.expected,
    required MidiProgram this.receive,
  }) : bytes = null;

  final String Function(AppLocalizations l10n) title;
  final String Function(AppLocalizations l10n) expected;

  /// What a send step sends; null for a receive step.
  final Uint8List Function(int channel)? bytes;

  /// The program a receive step expects from the keyboard; null for a send
  /// step.
  final MidiProgram? receive;

  bool get receives => receive != null;

  List<MidiGuideAnswer> get answers => MidiGuideAnswer.values;
}

/// The guided tests of the MIDI test screen (#613): per keyboard, sending
/// to it and receiving what is chosen on it (#608).
enum MidiGuide {
  nordSend,
  nordReceive,
  motifSend,
  motifReceive;

  /// The device profile whose terms the steps use.
  MidiProfile get profile => switch (this) {
    nordSend || nordReceive => const NordStage3Profile(),
    motifSend || motifReceive => const MotifXfProfile(),
  };

  bool get receives => this == nordReceive || this == motifReceive;

  String label(AppLocalizations l10n) => switch (this) {
    nordSend => l10n.midiGuideNordSend,
    nordReceive => l10n.midiGuideNordReceive,
    motifSend => l10n.midiGuideMotifSend,
    motifReceive => l10n.midiGuideMotifReceive,
  };

  /// What to do before the steps.
  String hint(AppLocalizations l10n) => switch (this) {
    nordSend => l10n.midiGuideHint,
    nordReceive => l10n.midiGuideNordReceiveHint,
    motifSend => l10n.midiGuideMotifSendHint,
    motifReceive => l10n.midiGuideMotifReceiveHint,
  };

  List<MidiGuideStep> steps() => switch (this) {
    nordSend => nordStage3Guide(),
    nordReceive => nordStage3ReceiveGuide(),
    motifSend => motifXfGuide(),
    motifReceive => motifXfReceiveGuide(),
  };
}

/// The raw values of [program] as the MIDI test shows them, e.g.
/// "CC 0 = 0, CC 32 = 2, PC 12".
String midiValues(MidiProgram program) => [
  if (program.msb case final msb?) 'CC 0 = $msb',
  if (program.lsb case final lsb?) 'CC 32 = $lsb',
  'PC ${program.program}',
].join(', ');

/// A receive step for [program], named in the terms of [profile].
MidiGuideStep _receive(MidiProfile profile, MidiProgram program) =>
    MidiGuideStep.receive(
      title: (l10n) =>
          l10n.midiGuideChoose(midiPatchLabel(l10n, profile.toPatch(program))),
      expected: (l10n) => l10n.midiGuideReceiveExpected(midiValues(program)),
      receive: program,
    );

/// What the Nord Stage 3 sends when a program, live memory or song is
/// chosen on it (#608): programs across the blocks of 125, a live memory
/// and a song part.
List<MidiGuideStep> nordStage3ReceiveGuide() {
  const nord = NordStage3Profile();
  return [
    for (final program in [
      NordStage3.program(0, 1, 1),
      NordStage3.program(10, 3, 3),
      NordStage3.program(15, 5, 5),
      NordStage3.live(2),
      NordStage3.song(2, 3),
      NordStage3.program(0, 1, 1),
    ])
      _receive(nord, program),
  ];
}

/// The guided test of a Motif XF (#591, #613): voices and performances
/// with the profile's mode change, across the kinds of banks.
List<MidiGuideStep> motifXfGuide() {
  const motif = MotifXfProfile();
  MidiGuideStep step(MidiProgram program) {
    return MidiGuideStep(
      title: (l10n) => midiPatchLabel(l10n, motif.toPatch(program)),
      expected: (l10n) => l10n.midiGuideMotifExpected(
        midiPatchShortLabel(l10n, motif.toPatch(program)),
      ),
      bytes: (c) => motif.bytes(program, c),
    );
  }

  return [
    for (final program in [
      MotifXf.performance(0, 0),
      // Into voice mode.
      MotifXf.voice(0, 0),
      // Last voice of the last preset bank.
      MotifXf.voice(7, 127),
      MotifXf.voice(11, 0),
      MotifXf.voice(12, 0),
      MotifXf.voice(13, 0),
      // Back into performance mode.
      MotifXf.performance(1, 17),
    ])
      step(program),
  ];
}

/// What the Motif XF sends when a voice or performance is chosen on it
/// (#608, #613): preset, user and GM voices, twice in one bank (is the bank
/// select sent again?), and performances.
List<MidiGuideStep> motifXfReceiveGuide() {
  const motif = MotifXfProfile();
  return [
    for (final program in [
      MotifXf.voice(0, 0),
      MotifXf.voice(2, 36),
      // Same bank, next number.
      MotifXf.voice(2, 37),
      MotifXf.voice(8, 0),
      MotifXf.voice(12, 0),
      MotifXf.performance(0, 0),
      MotifXf.performance(1, 17),
    ])
      _receive(motif, program),
  ];
}

/// The guided test of a Nord Stage 3 (#512): the live memories as the Nord
/// sends them (CC 0 = 6) and songs with parts. Nothing has to be set on the
/// keyboard: it starts and ends on program A:11, the song mode is switched
/// by CC 3.
List<MidiGuideStep> nordStage3Guide() {
  MidiGuideStep program(int bank, int page, int button) {
    final name = NordStage3.programName(bank, page, button);
    return MidiGuideStep(
      title: (l10n) => l10n.midiGuideProgram(name),
      expected: (l10n) => l10n.midiGuideProgramExpected(name),
      bytes: (c) => NordStage3.program(bank, page, button).bytes(c),
    );
  }

  MidiGuideStep live(int number) => MidiGuideStep(
    title: (l10n) => l10n.midiGuideLive(number),
    expected: (l10n) => l10n.midiGuideLiveExpected(number),
    bytes: (c) => NordStage3.live(number).bytes(c),
  );

  MidiGuideStep song(int song, int part) => MidiGuideStep(
    title: (l10n) => l10n.midiGuideSong(song, part),
    expected: (l10n) => l10n.midiGuideSongExpected(song, part),
    bytes: (c) => NordStage3.song(song, part).bytes(c),
  );

  return [
    program(0, 1, 1),
    live(1),
    live(3),
    live(5),
    // A program leaves the live memories again.
    program(0, 1, 1),
    MidiGuideStep(
      title: (l10n) => l10n.midiGuideSongModeOn,
      expected: (l10n) => l10n.midiGuideSongModeOnExpected,
      bytes: (c) => midiControlChange(c, 3, 127),
    ),
    song(2, 3),
    // Second block, last part.
    song(26, 5),
    MidiGuideStep(
      title: (l10n) => l10n.midiGuideSongModeOff,
      expected: (l10n) => l10n.midiGuideSongModeOffExpected,
      bytes: (c) => midiControlChange(c, 3, 0),
    ),
    program(0, 1, 1),
  ];
}

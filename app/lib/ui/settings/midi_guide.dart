import 'dart:typed_data';

import '../../l10n/generated/app_localizations.dart';
import '../../midi/midi_message.dart';

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

/// One step of the guided test: what is sent and what should happen.
class MidiGuideStep {
  const MidiGuideStep({
    required this.title,
    required this.expected,
    required this.bytes,
  });

  final String Function(AppLocalizations l10n) title;
  final String Function(AppLocalizations l10n) expected;
  final Uint8List Function(int channel) bytes;

  List<MidiGuideAnswer> get answers => MidiGuideAnswer.values;
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

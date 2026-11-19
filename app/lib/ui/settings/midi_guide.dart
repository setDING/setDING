import 'dart:typed_data';

import '../../l10n/generated/app_localizations.dart';
import '../../midi/midi_message.dart';

/// What the tester saw on the keyboard after a step of the guided test.
enum MidiGuideAnswer {
  asExpected,
  changed,
  nextSong,
  nextPart,
  severalSongs,
  different,
  nothing;

  String label(AppLocalizations l10n) => switch (this) {
    asExpected => l10n.midiGuideAnswerAsExpected,
    changed => l10n.midiGuideAnswerChanged,
    nextSong => l10n.midiGuideAnswerNextSong,
    nextPart => l10n.midiGuideAnswerNextPart,
    severalSongs => l10n.midiGuideAnswerSeveralSongs,
    different => l10n.midiGuideAnswerDifferent,
    nothing => l10n.midiGuideAnswerNothing,
  };
}

/// One step of the guided test: what is sent, what should happen and the
/// answers the tester can tap.
class MidiGuideStep {
  const MidiGuideStep({
    required this.title,
    required this.expected,
    required this.bytes,
    this.answers = _checked,
  });

  final String Function(AppLocalizations l10n) title;
  final String Function(AppLocalizations l10n) expected;
  final Uint8List Function(int channel) bytes;
  final List<MidiGuideAnswer> answers;

  static const _checked = [
    MidiGuideAnswer.asExpected,
    MidiGuideAnswer.different,
    MidiGuideAnswer.nothing,
  ];
}

/// The guided test of a Nord Stage 3 (#512): checks the program numbering
/// at the block borders, a live memory, the song mode and finds out how
/// songs and song parts are addressed. Nothing has to be set on the
/// keyboard: the song mode is switched by CC 3, the last step returns to
/// program A:11.
List<MidiGuideStep> nordStage3Guide() {
  MidiGuideStep program(int bank, int page, int button) {
    final name = NordStage3.programName(bank, page, button);
    return MidiGuideStep(
      title: (l10n) => l10n.midiGuideProgram(name),
      expected: (l10n) => l10n.midiGuideProgramExpected(name),
      bytes: (c) => NordStage3.program(bank, page, button).bytes(c),
    );
  }

  MidiGuideStep cc(
    int controller,
    int value,
    String Function(AppLocalizations) title,
    String Function(AppLocalizations) expected,
  ) => MidiGuideStep(
    title: title,
    expected: expected,
    bytes: (c) => midiControlChange(c, controller, value),
  );

  MidiGuideStep song(int number, {bool first = false}) => MidiGuideStep(
    title: (l10n) => l10n.midiGuideSong(number),
    expected: (l10n) =>
        first ? l10n.midiGuideSongFirstExpected : l10n.midiGuideSongExpected,
    bytes: (c) => NordStage3.song(number).bytes(c),
    answers: first
        ? const [MidiGuideAnswer.changed, MidiGuideAnswer.nothing]
        : const [
            MidiGuideAnswer.nextSong,
            MidiGuideAnswer.nextPart,
            MidiGuideAnswer.severalSongs,
            MidiGuideAnswer.different,
            MidiGuideAnswer.nothing,
          ],
  );

  return [
    program(0, 1, 1),
    // Last program of the first block, first of the second.
    program(4, 5, 5),
    program(5, 1, 1),
    program(10, 3, 3),
    program(15, 5, 5),
    MidiGuideStep(
      title: (l10n) => l10n.midiGuideLive(3),
      expected: (l10n) => l10n.midiGuideLiveExpected(3),
      bytes: (c) => NordStage3.live(3).bytes(c),
    ),
    cc(
      3,
      127,
      (l10n) => l10n.midiGuideSongModeOn,
      (l10n) => l10n.midiGuideSongModeOnExpected,
    ),
    song(1, first: true),
    song(2),
    song(6),
    song(126),
    cc(
      5,
      1,
      (l10n) => l10n.midiGuideSongPart(1),
      (l10n) => l10n.midiGuideSongPartExpected,
    ),
    cc(
      5,
      0,
      (l10n) => l10n.midiGuideSongPart(0),
      (l10n) => l10n.midiGuideSongPartExpected,
    ),
    cc(
      3,
      0,
      (l10n) => l10n.midiGuideSongModeOff,
      (l10n) => l10n.midiGuideSongModeOffExpected,
    ),
    cc(
      2,
      127,
      (l10n) => l10n.midiGuideLiveModeOn,
      (l10n) => l10n.midiGuideLiveModeOnExpected,
    ),
    cc(
      2,
      0,
      (l10n) => l10n.midiGuideLiveModeOff,
      (l10n) => l10n.midiGuideLiveModeOffExpected,
    ),
    program(0, 1, 1),
  ];
}

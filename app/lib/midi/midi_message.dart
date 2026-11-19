import 'dart:typed_data';

/// A program change with an optional bank select, as raw MIDI values
/// (ADR-0039). Stored like this, independent of the device profile.
class MidiProgram {
  const MidiProgram({this.msb, this.lsb, required this.program})
    : assert(msb == null || (msb >= 0 && msb <= 127)),
      assert(lsb == null || (lsb >= 0 && lsb <= 127)),
      assert(program >= 0 && program <= 127);

  /// Bank select MSB (CC 0); null sends none.
  final int? msb;

  /// Bank select LSB (CC 32); null sends none.
  final int? lsb;

  /// Program change value, 0–127.
  final int program;

  /// The messages on [channel] (1–16) in the order a keyboard needs them:
  /// bank select MSB, bank select LSB, then the program change.
  Uint8List bytes(int channel) {
    RangeError.checkValueInInterval(channel, 1, 16, 'channel');
    final c = channel - 1;
    return Uint8List.fromList([
      if (msb != null) ...[0xB0 | c, 0, msb!],
      if (lsb != null) ...[0xB0 | c, 32, lsb!],
      0xC0 | c,
      program,
    ]);
  }

  @override
  bool operator ==(Object other) =>
      other is MidiProgram &&
      other.msb == msb &&
      other.lsb == lsb &&
      other.program == program;

  @override
  int get hashCode => Object.hash(msb, lsb, program);

  @override
  String toString() => 'MidiProgram(msb: $msb, lsb: $lsb, program: $program)';
}

/// Addressing of the Nord Stage 3 (ADR-0039), checked on a keyboard in the
/// prototype (#512). 400 programs in 16 banks A–P of 25 (5 pages of 5
/// buttons; the display shows `K:33` for bank K, page 3, button 3). They are
/// counted through and sent in blocks of 125: CC 0 = 0, CC 32 = block (0–3),
/// program change = place in the block (0–124). The live memories 1–5 are
/// program changes 50–54 without bank select. Songs use CC 0 = 1; their
/// numbering is not known yet, [song] assumes the same blocks of 125.
abstract final class NordStage3 {
  static const banks = [
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', //
    'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P',
  ];
  static const pages = 5;
  static const buttons = 5;
  static const programsPerBank = pages * buttons;
  static const programsPerBlock = 125;
  static const liveMemories = 5;

  /// The highest song number [song] accepts.
  static const maxSong = 999;

  /// Program on [bank] (0–15 for A–P), [page] (1–5) and [button] (1–5).
  static MidiProgram program(int bank, int page, int button) {
    RangeError.checkValueInInterval(bank, 0, banks.length - 1, 'bank');
    RangeError.checkValueInInterval(page, 1, pages, 'page');
    RangeError.checkValueInInterval(button, 1, buttons, 'button');
    final index = bank * programsPerBank + (page - 1) * buttons + (button - 1);
    return _block(0, index);
  }

  /// The name the display shows, e.g. `K:33`.
  static String programName(int bank, int page, int button) =>
      '${banks[bank]}:$page$button';

  /// Song [number] (1–[maxSong]), assuming blocks of 125 like the programs.
  static MidiProgram song(int number) {
    RangeError.checkValueInInterval(number, 1, maxSong, 'number');
    return _block(1, number - 1);
  }

  /// Live memory [number] (1–5); independent of the bank, so no bank select.
  static MidiProgram live(int number) {
    RangeError.checkValueInInterval(number, 1, liveMemories, 'number');
    return MidiProgram(program: 50 + number - 1);
  }

  static MidiProgram _block(int msb, int index) => MidiProgram(
    msb: msb,
    lsb: index ~/ programsPerBlock,
    program: index % programsPerBlock,
  );
}

/// A control change [controller] = [value] on [channel] (1–16), e.g. the
/// mode switches of the Nord Stage 3 (CC 2 live mode, CC 3 song mode, CC 5
/// song part, listed on midi.guide). CC 3 = 127 / 0 switches the song mode
/// on and off; CC 2 and CC 5 showed no effect in the first test (#512).
Uint8List midiControlChange(int channel, int controller, int value) {
  RangeError.checkValueInInterval(channel, 1, 16, 'channel');
  RangeError.checkValueInInterval(controller, 0, 127, 'controller');
  RangeError.checkValueInInterval(value, 0, 127, 'value');
  return Uint8List.fromList([0xB0 | (channel - 1), controller, value]);
}

/// The bytes as hex pairs, e.g. `B0 00 00 C0 0C`.
String midiHex(List<int> bytes) => bytes
    .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
    .join(' ');

/// One received MIDI message, read for the log of the MIDI test.
sealed class MidiEvent {
  const MidiEvent(this.channel);

  /// 1–16.
  final int channel;

  /// Reads one complete channel message; null for anything else.
  static MidiEvent? parse(List<int> data) {
    if (data.isEmpty) return null;
    final status = data[0];
    final channel = (status & 0x0F) + 1;
    return switch (status & 0xF0) {
      0xB0 when data.length >= 3 => MidiControlChange(
        channel,
        data[1],
        data[2],
      ),
      0xC0 when data.length >= 2 => MidiProgramChange(channel, data[1]),
      _ => null,
    };
  }
}

class MidiControlChange extends MidiEvent {
  const MidiControlChange(super.channel, this.controller, this.value);
  final int controller;
  final int value;
}

class MidiProgramChange extends MidiEvent {
  const MidiProgramChange(super.channel, this.program);
  final int program;
}

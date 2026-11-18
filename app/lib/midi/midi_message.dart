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

/// Addressing of the Nord Stage 3 (ADR-0039). Programs and live memories as
/// in the Nord manual (CC 0 = 0, CC 32 = bank 0–7, program change 0–49 for
/// the programs of the bank, 50–54 for the live memories). Songs use
/// CC 0 = 1 according to users of the Nord User Forum; the prototype (#512)
/// checks this on a real keyboard.
abstract final class NordStage3 {
  static const banks = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'];
  static const programsPerBank = 50;
  static const liveMemories = 5;

  /// Program [number] (1–50) of [bank] (0–7 for A–H).
  static MidiProgram program(int bank, int number) {
    _check(bank, number);
    return MidiProgram(msb: 0, lsb: bank, program: number - 1);
  }

  /// Song [number] (1–50) of [bank] (0–7 for A–H).
  static MidiProgram song(int bank, int number) {
    _check(bank, number);
    return MidiProgram(msb: 1, lsb: bank, program: number - 1);
  }

  /// Live memory [number] (1–5); independent of the bank, so no bank select.
  static MidiProgram live(int number) {
    RangeError.checkValueInInterval(number, 1, liveMemories, 'number');
    return MidiProgram(program: programsPerBank + number - 1);
  }

  static void _check(int bank, int number) {
    RangeError.checkValueInInterval(bank, 0, banks.length - 1, 'bank');
    RangeError.checkValueInInterval(number, 1, programsPerBank, 'number');
  }
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

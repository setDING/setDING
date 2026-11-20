import 'package:flutter/foundation.dart';

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

  /// The stored form (ADR-0039): `{"msb"?, "lsb"?, "program"}`, without
  /// the keys of an unset bank select.
  Map<String, dynamic> toJson() => {
    'msb': ?msb,
    'lsb': ?lsb,
    'program': program,
  };

  /// Reads [toJson]'s form; null for anything else (no map, values out of
  /// range, no program), so a broken or unknown value sends nothing.
  static MidiProgram? fromJson(Object? json) {
    if (json is! Map) return null;
    int? value(Object? v) =>
        v is num && v == v.toInt() && v >= 0 && v <= 127 ? v.toInt() : null;
    final program = value(json['program']);
    final msb = value(json['msb']);
    final lsb = value(json['lsb']);
    if (program == null ||
        (json['msb'] != null && msb == null) ||
        (json['lsb'] != null && lsb == null)) {
      return null;
    }
    return MidiProgram(msb: msb, lsb: lsb, program: program);
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

/// The keyboard programs of a song per device profile (ADR-0042): profile
/// id (`MidiProfileKind.name`, e.g. `nordStage3`) → raw values. Empty =
/// none; the device's profile picks the one that is shown and sent.
@immutable
class MidiPrograms {
  const MidiPrograms([this.byProfile = const {}]);

  final Map<String, MidiProgram> byProfile;

  bool get isEmpty => byProfile.isEmpty;

  /// The program of [profile], null when it has none.
  MidiProgram? operator [](String profile) => byProfile[profile];

  /// With [program] for [profile]; null removes it.
  MidiPrograms withProgram(String profile, MidiProgram? program) =>
      MidiPrograms({
        for (final e in byProfile.entries)
          if (e.key != profile) e.key: e.value,
        profile: ?program,
      });

  /// The stored form: `{"<profile>": {"msb"?, "lsb"?, "program"}, …}`.
  Map<String, dynamic> toJson() => {
    for (final e in byProfile.entries) e.key: e.value.toJson(),
  };

  /// Reads [toJson]'s form; null for anything that is no map. Entries that
  /// cannot be read are left out, so a broken value sends nothing.
  static MidiPrograms? fromJson(Object? json) {
    if (json is! Map) return null;
    return MidiPrograms({
      for (final MapEntry(:key, :value) in json.entries)
        if (key is String && key != '') key: ?MidiProgram.fromJson(value),
    });
  }

  @override
  bool operator ==(Object other) =>
      other is MidiPrograms && mapEquals(other.byProfile, byProfile);

  @override
  int get hashCode => Object.hashAllUnordered(
    byProfile.entries.map((e) => Object.hash(e.key, e.value)),
  );

  @override
  String toString() => 'MidiPrograms($byProfile)';
}

/// Addressing of the Nord Stage 3 (ADR-0039), checked on a keyboard in the
/// prototype (#512). 400 programs in 16 banks A–P of 25 (5 pages of 5
/// buttons; the display shows `K:33` for bank K, page 3, button 3). They are
/// counted through and sent in blocks of 125: CC 0 = 0, CC 32 = block (0–3),
/// program change = place in the block (0–124). Songs use CC 0 = 1 and the
/// same blocks, with 5 parts per song: song 26 part 1 is CC 32 = 1, program
/// change 0. A program change 50–54 without bank select is program C:11–C:15,
/// not a live memory; the Nord itself sends CC 0 = 6 with program change 0–4
/// for its live memories, which [live] uses (confirmed on Nord OS 2.54,
/// #512). `NordStage3Profile` in `midi_profile.dart` translates back.
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
  static const partsPerSong = 5;

  /// The highest song [song] accepts: 4 blocks like the programs (the real
  /// limit of the Nord is not known).
  static const maxSong = 4 * programsPerBlock ~/ partsPerSong;

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

  /// Part [part] (1–5) of song [song] (1–[maxSong]).
  static MidiProgram song(int song, [int part = 1]) {
    RangeError.checkValueInInterval(song, 1, maxSong, 'song');
    RangeError.checkValueInInterval(part, 1, partsPerSong, 'part');
    return _block(1, (song - 1) * partsPerSong + (part - 1));
  }

  /// Live memory [number] (1–5), as the Nord sends it: CC 0 = 6.
  static MidiProgram live(int number) {
    RangeError.checkValueInInterval(number, 1, liveMemories, 'number');
    return MidiProgram(msb: 6, lsb: 0, program: number - 1);
  }

  static MidiProgram _block(int msb, int index) => MidiProgram(
    msb: msb,
    lsb: index ~/ programsPerBlock,
    program: index % programsPerBlock,
  );
}

/// The modes of a Yamaha Motif XF, numbered as its mode change parameter
/// (MOTIF XF Data List, MIDI parameter change table "Mode Change").
enum MotifMode { voice, performance, pattern, song, master }

/// A bank of the Yamaha Motif XF: [name] as on its display, its bank select
/// and the number of programs in it (MOTIF XF Data List, "Available Bank
/// Select/Program Change").
@immutable
class MotifBank {
  const MotifBank(this.name, this.msb, this.lsb, this.size);

  final String name;
  final int msb;
  final int lsb;

  /// Programs 0 to [size] − 1.
  final int size;

  /// The groups A–H the bank fills, 16 programs each.
  int get groups => (size + MotifXf.perGroup - 1) ~/ MotifXf.perGroup;

  @override
  String toString() => 'MotifBank($name)';
}

/// Addressing of the Yamaha Motif XF (ADR-0039, #591), from the MOTIF XF
/// Data List: voices and performances are chosen by bank select (CC 0 = 63
/// and CC 32 = bank, except the GM banks) and program change 0–127, which
/// the display shows as group A–H and number 1–16 (`USR1 A01` = program
/// change 0, `H16` = 127). A program change only works in the mode the
/// Motif is in; the mode can be changed only by the SysEx parameter change
/// [modeChange]. `MotifXfProfile` in `midi_profile.dart` translates back.
abstract final class MotifXf {
  static const groupNames = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'];
  static const perGroup = 16;

  /// The voice banks: preset 1–8, user 1–4, GM, preset and user drums,
  /// GM drum.
  static const voiceBanks = [
    MotifBank('PRE1', 63, 0, 128),
    MotifBank('PRE2', 63, 1, 128),
    MotifBank('PRE3', 63, 2, 128),
    MotifBank('PRE4', 63, 3, 128),
    MotifBank('PRE5', 63, 4, 128),
    MotifBank('PRE6', 63, 5, 128),
    MotifBank('PRE7', 63, 6, 128),
    MotifBank('PRE8', 63, 7, 128),
    MotifBank('USR1', 63, 8, 128),
    MotifBank('USR2', 63, 9, 128),
    MotifBank('USR3', 63, 10, 128),
    MotifBank('USR4', 63, 11, 128),
    MotifBank('GM', 0, 0, 128),
    MotifBank('PDR', 63, 32, 64),
    MotifBank('UDR', 63, 40, 32),
    MotifBank('GMDR', 127, 0, 1),
  ];

  /// The performance banks user 1–4.
  static const performanceBanks = [
    MotifBank('USR1', 63, 64, 128),
    MotifBank('USR2', 63, 65, 128),
    MotifBank('USR3', 63, 66, 128),
    MotifBank('USR4', 63, 67, 128),
  ];

  /// The SysEx device number setDING sends to; the Motif's "Device No."
  /// (Utility → Control → MIDI) must be "all" or 1 (#591).
  static const deviceNumber = 1;

  /// Voice [index] (0 to the bank's size − 1) of voice bank [bank].
  static MidiProgram voice(int bank, int index) =>
      _program(voiceBanks, bank, index);

  /// Performance [index] (0–127) of performance bank [bank] (0–3).
  static MidiProgram performance(int bank, int index) =>
      _program(performanceBanks, bank, index);

  static MidiProgram _program(List<MotifBank> banks, int bank, int index) {
    RangeError.checkValueInInterval(bank, 0, banks.length - 1, 'bank');
    final b = banks[bank];
    RangeError.checkValueInInterval(index, 0, b.size - 1, 'index');
    return MidiProgram(msb: b.msb, lsb: b.lsb, program: index);
  }

  /// Group and number as on the display, e.g. `A01` for 0, `H16` for 127.
  static String programName(int index) =>
      '${groupNames[index ~/ perGroup]}'
      '${(index % perGroup + 1).toString().padLeft(2, '0')}';

  /// The bank of [banks] that [program] selects; null for none.
  static int? bankOf(List<MotifBank> banks, MidiProgram program) {
    for (var i = 0; i < banks.length; i++) {
      final b = banks[i];
      if (b.msb == program.msb &&
          b.lsb == program.lsb &&
          program.program < b.size) {
        return i;
      }
    }
    return null;
  }

  /// The SysEx parameter change that switches the Motif to [mode]:
  /// `F0 43 1n 7F 12 0A 00 01 mm F7` (n = device number − 1).
  static Uint8List modeChange(MotifMode mode) => Uint8List.fromList([
    0xF0, 0x43, 0x10 | (deviceNumber - 1), 0x7F, 0x12, //
    0x0A, 0x00, 0x01, mode.index, 0xF7,
  ]);
}

/// A control change [controller] = [value] on [channel] (1–16), e.g. the
/// mode switches of the Nord Stage 3 (CC 2 live mode, CC 3 song mode, CC 5
/// song part, listed on midi.guide). On the Nord, CC 3 = 127 / 0 switches the
/// song mode and CC 2 = 127 / 0 the live mode on and off; CC 5 showed no
/// effect (#512).
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

/// Collects the keyboard program from what a keyboard sends when a sound
/// is chosen on it (#608): bank select MSB (CC 0) and LSB (CC 32), then a
/// program change, on [channel] (1–16). Messages may arrive one by one or
/// several in one packet; other channels, other messages, real-time bytes
/// and SysEx are skipped. The last bank select stays for later program
/// changes, as on the keyboard; before any, a program has none.
class MidiProgramReceiver {
  MidiProgramReceiver(this.channel);

  final int channel;

  int? _msb;
  int? _lsb;

  /// Reads [data]; returns the program when a program change on [channel]
  /// completed one (the last one when a packet holds several).
  MidiProgram? add(List<int> data) {
    MidiProgram? result;
    var i = 0;
    while (i < data.length) {
      final status = data[i];
      final length = switch (status & 0xF0) {
        0xC0 || 0xD0 => 2,
        0x80 || 0x90 || 0xA0 || 0xB0 || 0xE0 => 3,
        _ => 0,
      };
      // Data bytes without a status, real-time bytes and SysEx: skipped
      // byte by byte (SysEx data bytes are below 0x80).
      if (status < 0x80 || length == 0) {
        i++;
        continue;
      }
      if (i + length > data.length) break;
      final message = data.sublist(i, i + length);
      // A status byte where a data byte belongs: a broken message.
      if (message.skip(1).any((b) => b >= 0x80)) {
        i++;
        continue;
      }
      final event = MidiEvent.parse(message);
      i += length;
      if (event == null || event.channel != channel) continue;
      switch (event) {
        case MidiControlChange(controller: 0, :final value):
          _msb = value;
        case MidiControlChange(controller: 32, :final value):
          _lsb = value;
        case MidiProgramChange(:final program):
          result = MidiProgram(msb: _msb, lsb: _lsb, program: program);
        case MidiControlChange():
          break;
      }
    }
    return result;
  }
}

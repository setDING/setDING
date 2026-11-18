import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_midi_command/flutter_midi_command.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../util/log.dart';

/// A MIDI device as offered to the user.
class MidiPortInfo {
  const MidiPortInfo({
    required this.id,
    required this.name,
    required this.connected,
  });

  final String id;
  final String name;
  final bool connected;
}

/// MIDI to a keyboard (ADR-0039): USB devices, sending raw bytes, and the
/// messages the keyboard sends back.
abstract class MidiOutput {
  /// The MIDI devices available now; empty if MIDI is not available.
  Future<List<MidiPortInfo>> devices();

  Future<void> connect(String id);

  Future<void> disconnect(String id);

  /// Sends [bytes] to the connected device [id], or to every connected one.
  void send(Uint8List bytes, {String? id});

  /// Complete messages received from connected devices.
  Stream<Uint8List> get received;

  /// Fires when devices are plugged in or removed.
  Stream<void> get changes;
}

/// [MidiOutput] on `flutter_midi_command` (BSD-3-Clause): USB MIDI on
/// Android, Windows and Linux (ALSA), Web MIDI in the browser.
class FlutterMidiOutput implements MidiOutput {
  static const _log = Log('midi');

  // Created on first use: the plugin starts its platform side then.
  MidiCommand get _midi => MidiCommand();

  final _known = <String, MidiDevice>{};

  @override
  Future<List<MidiPortInfo>> devices() async {
    try {
      final list = await _midi.devices ?? const <MidiDevice>[];
      _known
        ..clear()
        ..addEntries(list.map((d) => MapEntry(d.id, d)));
      return [
        for (final d in list)
          MidiPortInfo(id: d.id, name: d.name, connected: d.connected),
      ];
    } catch (e) {
      _log.warning('MIDI devices not available', e);
      return const [];
    }
  }

  Future<MidiDevice> _device(String id) async {
    if (!_known.containsKey(id)) await devices();
    final device = _known[id];
    if (device == null) throw StateError('MIDI device $id is gone');
    return device;
  }

  @override
  Future<void> connect(String id) async =>
      _midi.connectToDevice(await _device(id));

  @override
  Future<void> disconnect(String id) async {
    // A device that is gone is disconnected already.
    final device = _known[id];
    if (device != null) _midi.disconnectDevice(device);
  }

  @override
  void send(Uint8List bytes, {String? id}) =>
      _midi.sendData(bytes, deviceId: id);

  @override
  Stream<Uint8List> get received =>
      (_midi.onMidiPacketReceived ?? const Stream<MidiPacket>.empty())
          .map((p) => p.data)
          .handleError((Object e) => _log.warning('MIDI input failed', e));

  @override
  Stream<void> get changes =>
      (_midi.onMidiSetupChanged ?? const Stream<MidiSetupChange>.empty())
          .map((_) {})
          // E.g. Linux without libasound: no devices, but no crash.
          .handleError((Object e) => _log.warning('MIDI not available', e));
}

final midiOutputProvider = Provider<MidiOutput>((ref) => FlutterMidiOutput());

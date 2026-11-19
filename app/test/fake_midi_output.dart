import 'dart:async';
import 'dart:typed_data';

import 'package:setding/midi/midi_output.dart';

/// MIDI in memory (ADR-0039): offers [ports], records what is sent and
/// replays messages of the keyboard with [receive].
class FakeMidiOutput implements MidiOutput {
  List<MidiPortInfo> ports = const [];
  final connected = <String>{};
  final sent = <List<int>>[];

  /// The device each message of [sent] went to.
  final sentTo = <String?>[];
  final connects = <String>[];
  final disconnected = <String>[];

  /// Connecting fails, e.g. the device is busy.
  bool failConnect = false;
  final _received = StreamController<Uint8List>.broadcast();
  final _changes = StreamController<void>.broadcast();

  void receive(List<int> data) => _received.add(Uint8List.fromList(data));

  /// Replaces the devices, as when one is plugged in or removed; a removed
  /// device is no longer connected.
  void plugIn(List<MidiPortInfo> ports) {
    this.ports = ports;
    connected.removeWhere((id) => !ports.any((p) => p.id == id));
    _changes.add(null);
  }

  @override
  Future<List<MidiPortInfo>> devices() async => [
    for (final p in ports)
      MidiPortInfo(id: p.id, name: p.name, connected: connected.contains(p.id)),
  ];

  @override
  Future<void> connect(String id) async {
    connects.add(id);
    if (failConnect) throw StateError('device busy');
    connected.add(id);
  }

  @override
  Future<void> disconnect(String id) async {
    connected.remove(id);
    disconnected.add(id);
  }

  @override
  void send(Uint8List bytes, {String? id}) {
    // Like the plugin: without a connected device nothing is sent.
    if (connected.isNotEmpty) {
      sent.add(bytes.toList());
      sentTo.add(id);
    }
  }

  @override
  Stream<Uint8List> get received => _received.stream;

  @override
  Stream<void> get changes => _changes.stream;
}

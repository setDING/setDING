import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/settings.dart';
import '../util/log.dart';
import 'midi_message.dart';
import 'midi_output.dart';
import 'midi_profile.dart';

/// The state of the MIDI connection to the keyboard (ADR-0039).
@immutable
class MidiStatus {
  const MidiStatus._(this.enabled, this.deviceId, this.deviceName);

  /// MIDI program changes are off on this device.
  static const off = MidiStatus._(false, null, null);

  /// On, but the remembered output is not connected (none chosen, not
  /// plugged in, or MIDI not available on this platform).
  static const notConnected = MidiStatus._(true, null, null);

  const MidiStatus.connected(String id, String name) : this._(true, id, name);

  /// MIDI program changes are on for this device.
  final bool enabled;

  /// Id of the connected output; null when not connected.
  final String? deviceId;

  /// Name of the connected output.
  final String? deviceName;

  bool get connected => deviceId != null;

  @override
  bool operator ==(Object other) =>
      other is MidiStatus &&
      other.enabled == enabled &&
      other.deviceId == deviceId &&
      other.deviceName == deviceName;

  @override
  int get hashCode => Object.hash(enabled, deviceId, deviceName);

  @override
  String toString() => switch (this) {
    MidiStatus(enabled: false) => 'MidiStatus.off',
    MidiStatus(connected: false) => 'MidiStatus.notConnected',
    _ => 'MidiStatus.connected($deviceName)',
  };
}

/// Keeps the MIDI output of the device settings connected while MIDI
/// program changes are on (ADR-0039): connects to the output remembered by
/// name from app start, and again without asking when it is plugged in
/// again. Errors are logged, never shown; where MIDI is not available it
/// simply stays [MidiStatus.notConnected].
class MidiConnection extends Notifier<MidiStatus> {
  static const _log = Log('midi');

  /// The connection of the current settings; replaced when they change.
  _Session? _session;

  @override
  MidiStatus build() {
    final (enabled, name) = ref.watch(
      settingsProvider.select((s) => (s.midiEnabled, s.midiOutputName)),
    );
    _session = null;
    if (!enabled) return MidiStatus.off;

    final session = _session = _Session(ref.watch(midiOutputProvider), name);
    StreamSubscription<void>? sub;
    try {
      sub = session.output.changes.listen(
        (_) => _refresh(session),
        onError: (Object e) => _log.warning('MIDI changes failed', e),
      );
    } catch (e) {
      _log.warning('MIDI not available', e);
    }
    ref.onDispose(() {
      session.active = false;
      sub?.cancel();
      // The settings changed: let go of the device that was connected.
      if (session.connectedId case final id?) {
        unawaited(
          session.output.disconnect(id).catchError((Object e) {
            _log.warning('MIDI disconnect failed', e);
          }),
        );
      }
    });
    unawaited(_refresh(session));
    return MidiStatus.notConnected;
  }

  /// Connects to the output of [session] if it is there, or notes that it
  /// is gone. Calls during a running refresh are merged into one more run.
  Future<void> _refresh(_Session session) async {
    if (session.busy) {
      session.again = true;
      return;
    }
    session.busy = true;
    try {
      do {
        session.again = false;
        await _connect(session);
      } while (session.again && session.active);
    } finally {
      session.busy = false;
    }
  }

  Future<void> _connect(_Session session) async {
    final _Session(:output, :name) = session;
    if (name.isEmpty) return;
    MidiStatus? next;
    try {
      final devices = await output.devices();
      if (!session.active) return;
      final device = devices.where((d) => d.name == name).firstOrNull;
      if (device == null) {
        if (session.connectedId != null) _log.info('MIDI output $name gone');
        session.connectedId = null;
        next = MidiStatus.notConnected;
      } else if (session.connectedId == device.id && device.connected) {
        return;
      } else {
        if (!device.connected) await output.connect(device.id);
        if (!session.active) {
          // The settings changed while connecting.
          if (!device.connected) await output.disconnect(device.id);
          return;
        }
        session.connectedId = device.id;
        _log.info('MIDI output $name connected');
        next = MidiStatus.connected(device.id, device.name);
      }
    } catch (e) {
      if (!session.active) return;
      _log.warning('MIDI output $name not connected', e);
      session.connectedId = null;
      next = MidiStatus.notConnected;
    }
    if (session.active) state = next;
  }

  /// Sends [program] (bank select, then program change) on the channel of
  /// the device settings to the connected output. Returns whether it was
  /// sent: nothing is sent while MIDI is off or not connected.
  bool send(MidiProgram program) {
    final id = state.deviceId;
    if (id == null) return false;
    try {
      ref
          .read(midiOutputProvider)
          .send(program.bytes(ref.read(settingsProvider).midiChannel), id: id);
      return true;
    } catch (e) {
      _log.warning('MIDI send failed', e);
      return false;
    }
  }

  /// Looks for the remembered output again, e.g. after the user plugged it
  /// in on a platform that does not report changes.
  Future<void> retry() async {
    if (_session case final session?) await _refresh(session);
  }
}

/// The output and the state of one connection.
class _Session {
  _Session(this.output, this.name);

  final MidiOutput output;
  final String name;

  /// False once the settings changed.
  bool active = true;
  bool busy = false;
  bool again = false;

  /// The device this session connected to.
  String? connectedId;
}

/// The MIDI connection to the keyboard (ADR-0039). Kept alive by the app
/// from its start; `ref.read(midiConnectionProvider.notifier).send(…)`
/// sends a program.
final midiConnectionProvider = NotifierProvider<MidiConnection, MidiStatus>(
  MidiConnection.new,
);

/// The device profile of the MIDI settings (ADR-0039), to show and edit
/// stored programs in the musician's terms.
final midiProfileProvider = Provider<MidiProfile>(
  (ref) => ref.watch(settingsProvider.select((s) => s.midiDeviceProfile)),
);

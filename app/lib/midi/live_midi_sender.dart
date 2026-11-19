import 'dart:async';

import '../util/log.dart';
import 'midi_message.dart';

/// Sends the keyboard program of the current song in live mode (ADR-0039).
///
/// Live mode tells it with [show] which set item is on stage; once an item
/// stayed current for [delay], the program of its song is read as stored at
/// that moment and sent. Songs swiped past quickly send nothing, breaks and
/// text items (no song) and songs without a program send nothing, and the
/// same program is sent again when the next song has it too. Pages within a
/// song do not reach it: only another set item does.
class LiveMidiSender {
  LiveMidiSender({
    required this.enabled,
    required this.program,
    required this.send,
    this.delay = const Duration(milliseconds: 300),
  });

  static const _log = Log('midi');

  /// Whether MIDI program changes are on for this device; while off,
  /// nothing is read or sent.
  final bool Function() enabled;

  /// The stored program of a song, null when it has none.
  final Future<MidiProgram?> Function(String songId) program;

  /// Sends a program to the keyboard; false when it was not sent.
  final bool Function(MidiProgram program) send;

  /// How long an item stays current before its program is sent.
  final Duration delay;

  Timer? _timer;
  int? _index;
  String? _songId;

  /// Counts the items shown, so a program read for an item that is no
  /// longer current is not sent.
  int _generation = 0;
  bool _disposed = false;

  /// Item [index] of the live sequence became current; [songId] is its
  /// song, null for a break or text item. Showing the current item again
  /// changes nothing.
  void show(int index, String? songId) {
    if (_disposed || index == _index) return;
    _index = index;
    _songId = songId;
    _generation++;
    _timer?.cancel();
    _timer = songId == null ? null : Timer(delay, _sendCurrent);
  }

  /// Sends the program of the current song now, e.g. after the keyboard
  /// was restarted. Returns whether something was sent.
  Future<bool> sendAgain() {
    _timer?.cancel();
    _timer = null;
    return _sendCurrent();
  }

  Future<bool> _sendCurrent() async {
    final songId = _songId;
    if (_disposed || songId == null || !enabled()) return false;
    final generation = _generation;
    try {
      final stored = await program(songId);
      if (_disposed || generation != _generation || stored == null) {
        return false;
      }
      return send(stored);
    } catch (e) {
      _log.warning('MIDI program of song $songId not sent', e);
      return false;
    }
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
  }
}

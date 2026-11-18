import 'dart:async';
import 'dart:typed_data';

import 'package:setding/audio/click_output.dart';

/// A [ClickOutput] without audio: a clock the test moves and a record of
/// what was played and stopped.
class FakeClickOutput implements ClickOutput {
  FakeClickOutput({this.available = true});

  bool available;

  /// While set, [ensureReady] waits for it (an audio device that hangs).
  Completer<bool>? ready;
  Duration time = Duration.zero;
  final loaded = <Uint8List>[];
  final unloaded = <Object>[];
  final plays = <({Object bar, Duration at, double volume, Duration? until})>[];
  final stops = <({Object handle, Duration at})>[];
  final volumes = <double>[];

  @override
  Future<bool> ensureReady() async => ready?.future ?? available;

  @override
  Duration now() => time;

  @override
  Future<Object> load(Uint8List wav) async {
    loaded.add(wav);
    return loaded.length - 1;
  }

  @override
  Object play(
    Object bar,
    Duration at, {
    required double volume,
    Duration? until,
  }) {
    plays.add((bar: bar, at: at, volume: volume, until: until));
    return 'handle-${plays.length - 1}';
  }

  @override
  void stopAt(Object handle, Duration at) =>
      stops.add((handle: handle, at: at));

  @override
  void setVolume(Object handle, double volume) => volumes.add(volume);

  @override
  Future<void> unload(Object bar) async => unloaded.add(bar);
}

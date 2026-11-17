import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../util/log.dart';

/// Turns the platform's "keep the screen on" switch on and off.
abstract interface class WakeLockPlatform {
  Future<void> setEnabled(bool enabled);

  /// Whether the screen is kept on right now.
  Future<bool> get enabled;
}

/// [WakeLockPlatform] of `wakelock_plus`: a window flag on Android, the idle
/// timer on iOS, `SetThreadExecutionState` on Windows, the desktop portal on
/// Linux and the Screen Wake Lock API in the browser.
class PluginWakeLockPlatform implements WakeLockPlatform {
  const PluginWakeLockPlatform();

  @override
  Future<void> setEnabled(bool enabled) => WakelockPlus.toggle(enable: enabled);

  @override
  Future<bool> get enabled => WakelockPlus.enabled;
}

/// Keeps the screen on while live mode is open (ADR-0007).
///
/// Every live view [acquire]s it and [release]s it when it closes; the
/// screen may turn off again only when no live view holds it any more, so
/// leaving live mode and opening it again right away never turns it off.
/// Changes are applied one after another, each to the number of holders at
/// that time, so a late release never undoes a newer acquire.
///
/// [failed] tells whether the screen is not kept on although a live view
/// holds it (e.g. Linux without a desktop portal, a browser without the
/// Screen Wake Lock API), so live mode can say so.
class StageWakeLock extends ChangeNotifier {
  StageWakeLock(this._platform);

  static const _log = Log('wakelock');

  final WakeLockPlatform _platform;
  int _holders = 0;
  Future<void> _applied = Future.value();
  bool _failed = false;

  /// Whether the screen is not kept on although a live view holds it.
  bool get failed => _failed;

  Future<void> acquire() {
    _holders++;
    return _apply();
  }

  Future<void> release() {
    if (_holders > 0) _holders--;
    return _apply();
  }

  /// Sets the wake lock again, e.g. when the app returns to the foreground:
  /// not every platform keeps it while the app is in the background.
  Future<void> reassert() => _apply();

  Future<void> _apply() => _applied = _applied.then((_) => _sync());

  Future<void> _sync() async {
    final on = _holders > 0;
    var ok = true;
    try {
      await _platform.setEnabled(on);
      if (on) ok = await _platform.enabled;
      if (!ok) _log.warning('The screen is not kept on');
    } catch (e) {
      // Turning it off may fail too; that leaves nothing to warn about.
      ok = !on;
      if (on) _log.warning('Cannot keep the screen on', e);
    }
    if (_disposed || _failed == !ok) return;
    _failed = !ok;
    notifyListeners();
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

final stageWakeLockProvider = Provider<StageWakeLock>((ref) {
  final lock = StageWakeLock(const PluginWakeLockPlatform());
  ref.onDispose(lock.dispose);
  return lock;
});

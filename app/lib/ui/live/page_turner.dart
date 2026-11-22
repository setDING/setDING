import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../platform/input_devices.dart';
import '../../settings/settings.dart' show sharedPreferencesProvider;

/// Keys that turn forward, exactly like the right tap zone (ADR-0007).
/// Bluetooth page turners register as keyboards and send these; some can be
/// switched to send Arrow Down / Arrow Up instead.
final pageTurnNextKeys = {
  LogicalKeyboardKey.arrowRight,
  LogicalKeyboardKey.arrowDown,
  LogicalKeyboardKey.pageDown,
  LogicalKeyboardKey.space,
};

/// Keys that turn back, exactly like the left tap zone (ADR-0007).
final pageTurnPreviousKeys = {
  LogicalKeyboardKey.arrowLeft,
  LogicalKeyboardKey.arrowUp,
  LogicalKeyboardKey.pageUp,
};

/// Whether [key] is one a page turner sends.
bool isPageTurnKey(LogicalKeyboardKey key) =>
    pageTurnNextKeys.contains(key) || pageTurnPreviousKeys.contains(key);

/// What the app knows about the page turner of this device (#911): a page
/// turner is a keyboard without a setting of its own, so this is only when
/// a page-turn key was last received.
@immutable
class PageTurnerState {
  const PageTurnerState({this.lastUsed, this.responded = false});

  /// The last page-turn key in live mode or in the overview's test; null
  /// when none was received on this device yet.
  final DateTime? lastUsed;

  /// A page-turn key reached the overview since the app started: the quick
  /// test before a gig.
  final bool responded;

  @override
  bool operator ==(Object other) =>
      other is PageTurnerState &&
      other.lastUsed == lastUsed &&
      other.responded == responded;

  @override
  int get hashCode => Object.hash(lastUsed, responded);
}

/// Remembers when a page-turn key was last received, on this device only
/// (a device setting in the shared preferences, like the automatic backup,
/// ADR-0054): another tablet has another pedal.
class PageTurnerNotifier extends Notifier<PageTurnerState> {
  static const lastUsedKey = 'pageTurnerLastUsed';

  /// The time; tests override it with [clock].
  DateTime Function() clock = DateTime.now;

  @override
  PageTurnerState build() {
    final stored = ref.read(sharedPreferencesProvider).getString(lastUsedKey);
    return PageTurnerState(
      lastUsed: stored == null ? null : DateTime.tryParse(stored),
    );
  }

  /// A page-turn key in live mode.
  void used() => _record(responded: state.responded);

  /// A page-turn key on the overview: the quick test (#911).
  void tested() => _record(responded: true);

  void _record({required bool responded}) {
    final now = clock();
    // One write a minute is enough for "last used".
    final last = state.lastUsed;
    if (last == null || now.difference(last).inMinutes >= 1) {
      ref
          .read(sharedPreferencesProvider)
          .setString(lastUsedKey, now.toIso8601String());
      state = PageTurnerState(lastUsed: now, responded: responded);
    } else if (responded != state.responded) {
      state = PageTurnerState(lastUsed: last, responded: responded);
    }
  }
}

final pageTurnerProvider =
    NotifierProvider<PageTurnerNotifier, PageTurnerState>(
      PageTurnerNotifier.new,
    );

/// The keyboards of the platform (ADR-0057); a fake in tests.
final inputDevicesProvider = Provider<InputDevices>(
  (ref) => ChannelInputDevices(),
);

/// The page turner paired on this device (ADR-0057), a device setting in the
/// shared preferences that is never synced; null when none is paired.
class PairedPageTurnerNotifier extends Notifier<InputDeviceInfo?> {
  static const nameKey = 'pageTurnerName',
      vendorKey = 'pageTurnerVendor',
      productKey = 'pageTurnerProduct';

  @override
  InputDeviceInfo? build() {
    final prefs = ref.read(sharedPreferencesProvider);
    final name = prefs.getString(nameKey);
    if (name == null) return null;
    return InputDeviceInfo(
      name: name,
      vendorId: prefs.getInt(vendorKey) ?? 0,
      productId: prefs.getInt(productKey) ?? 0,
    );
  }

  Future<void> pair(InputDeviceInfo device) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(nameKey, device.name);
    await prefs.setInt(vendorKey, device.vendorId);
    await prefs.setInt(productKey, device.productId);
    state = device;
  }

  Future<void> forget() async {
    final prefs = ref.read(sharedPreferencesProvider);
    for (final key in [nameKey, vendorKey, productKey]) {
      await prefs.remove(key);
    }
    state = null;
  }
}

final pairedPageTurnerProvider =
    NotifierProvider<PairedPageTurnerNotifier, InputDeviceInfo?>(
      PairedPageTurnerNotifier.new,
    );

/// The connected keyboards (ADR-0057), again after every connect or
/// disconnect; empty where the platform tells nothing.
final connectedKeyboardsProvider = StreamProvider<List<InputDeviceInfo>>((
  ref,
) async* {
  final devices = ref.watch(inputDevicesProvider);
  if (devices.support == InputDeviceSupport.none) {
    yield const [];
    return;
  }
  yield await devices.devices();
  await for (final _ in devices.changes) {
    yield await devices.devices();
  }
});

/// Whether the page turner is connected now, as far as the platform can
/// tell (ADR-0057).
enum PageTurnerConnection {
  /// Nothing known: no pairing, or the platform tells nothing.
  unknown,

  /// The paired page turner is connected.
  connected,

  /// The paired page turner is not connected.
  notConnected,

  /// iOS: a hardware keyboard is connected (maybe the page turner).
  keyboardConnected,

  /// iOS: no hardware keyboard is connected.
  noKeyboard,
}

/// The [PageTurnerConnection] of [support], the [paired] page turner and the
/// [connected] keyboards (null while they are loaded: unknown).
PageTurnerConnection pageTurnerConnection({
  required InputDeviceSupport support,
  required InputDeviceInfo? paired,
  required List<InputDeviceInfo>? connected,
}) {
  if (connected == null) return PageTurnerConnection.unknown;
  return switch (support) {
    InputDeviceSupport.none => PageTurnerConnection.unknown,
    InputDeviceSupport.keyboardOnly =>
      connected.isEmpty
          ? PageTurnerConnection.noKeyboard
          : PageTurnerConnection.keyboardConnected,
    InputDeviceSupport.devices =>
      paired == null
          ? PageTurnerConnection.unknown
          : connected.any((d) => d.matches(paired))
          ? PageTurnerConnection.connected
          : PageTurnerConnection.notConnected,
  };
}

/// [pageTurnerConnection] of this device.
final pageTurnerConnectionProvider = Provider<PageTurnerConnection>(
  (ref) => pageTurnerConnection(
    support: ref.watch(inputDevicesProvider).support,
    paired: ref.watch(pairedPageTurnerProvider),
    connected: ref.watch(connectedKeyboardsProvider).value,
  ),
);

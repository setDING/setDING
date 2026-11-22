import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

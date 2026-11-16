import 'dart:async';

import 'session_store.dart';

/// A synchronous key-value storage of the browser (`sessionStorage`,
/// `localStorage`).
abstract interface class KeyValueStorage {
  String? read(String key);

  void write(String key, String value);

  void remove(String key);
}

/// Messages between the open tabs of the web client (a `BroadcastChannel`;
/// a tab never receives its own messages).
abstract interface class TabChannel {
  void post(String message);

  Stream<String> get messages;
}

/// The session of the web client (ADR-0016, ADR-0018).
///
/// By default the session lasts as long as a tab of the web client is open:
/// it is kept in `sessionStorage`, and a new tab asks the open tabs for it.
/// With [keepSignedIn] (the "Stay signed in" checkbox, unchecked by default)
/// it is kept in `localStorage` and survives closing the browser. Signing out
/// in one tab signs out all tabs ([onSignedOutElsewhere]).
class BrowserSessionStore implements SessionStore {
  BrowserSessionStore({
    required this.tab,
    required this.persistent,
    TabChannel? channel,
    this.onSignedOutElsewhere,
    this.askTimeout = const Duration(milliseconds: 300),
  }) : _channel = channel {
    _subscription = channel?.messages.listen(_onMessage);
  }

  static const key = 'realchord.session';
  static const _request = 'session?';
  static const _reply = 'session:';
  static const _signedOut = 'signed-out';

  /// `sessionStorage`: the session of this tab.
  final KeyValueStorage tab;

  /// `localStorage`: the session with [keepSignedIn].
  final KeyValueStorage persistent;
  final TabChannel? _channel;
  StreamSubscription<String>? _subscription;

  /// Called when another tab signs out (the web client reloads).
  final void Function()? onSignedOutElsewhere;

  /// How long a new tab waits for an open tab to share its session.
  final Duration askTimeout;

  /// Whether the session survives closing the browser. Set before signing
  /// in; restored by [load].
  bool keepSignedIn = false;

  Completer<String>? _asking;
  String? _current;

  @override
  String? get current => _current;

  @override
  Future<void> load() async {
    if (tab.read(key) case final value?) {
      _current = value;
      keepSignedIn = false;
    } else if (persistent.read(key) case final value?) {
      _current = value;
      keepSignedIn = true;
    } else {
      _current = await _askOtherTabs();
      if (_current case final value?) tab.write(key, value);
    }
  }

  Future<String?> _askOtherTabs() async {
    final channel = _channel;
    if (channel == null) return null;
    final asking = _asking = Completer<String>();
    channel.post(_request);
    try {
      return await asking.future.timeout(askTimeout);
    } on TimeoutException {
      return null;
    } finally {
      _asking = null;
    }
  }

  void _onMessage(String message) {
    if (message == _request) {
      if (_current case final value?) _channel?.post('$_reply$value');
    } else if (message.startsWith(_reply)) {
      final asking = _asking;
      if (asking != null && !asking.isCompleted) {
        asking.complete(message.substring(_reply.length));
      }
    } else if (message == _signedOut && _current != null) {
      _current = null;
      tab.remove(key);
      onSignedOutElsewhere?.call();
    }
  }

  @override
  Future<void> write(String value) async {
    _current = value;
    if (keepSignedIn) {
      persistent.write(key, value);
      tab.remove(key);
    } else {
      tab.write(key, value);
      persistent.remove(key);
    }
  }

  @override
  Future<void> delete() async {
    final wasSignedIn = _current != null;
    _current = null;
    tab.remove(key);
    persistent.remove(key);
    if (wasSignedIn) _channel?.post(_signedOut);
  }

  /// Stops listening to the other tabs.
  Future<void> dispose() async => _subscription?.cancel();
}

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:setding/sync/browser_session_store.dart';

class _Storage implements KeyValueStorage {
  final values = <String, String>{};

  @override
  String? read(String key) => values[key];

  @override
  void write(String key, String value) => values[key] = value;

  @override
  void remove(String key) => values.remove(key);
}

/// Like a BroadcastChannel: every tab but the sender receives a message.
class _Channels {
  final _tabs = <_Channel>[];

  _Channel open() {
    final c = _Channel(this);
    _tabs.add(c);
    return c;
  }
}

class _Channel implements TabChannel {
  _Channel(this._all);

  final _Channels _all;
  // Lives as long as the test, like a tab's channel.
  // ignore: close_sinks
  final _messages = StreamController<String>.broadcast(sync: true);

  @override
  Stream<String> get messages => _messages.stream;

  @override
  void post(String message) {
    for (final tab in _all._tabs) {
      if (tab != this) scheduleMicrotask(() => tab._messages.add(message));
    }
  }
}

/// One browser tab: its own sessionStorage, the browser's localStorage.
BrowserSessionStore _tab(
  _Storage local, {
  _Channels? channels,
  void Function()? onSignedOut,
}) => BrowserSessionStore(
  tab: _Storage(),
  persistent: local,
  channel: channels?.open(),
  onSignedOutElsewhere: onSignedOut,
  askTimeout: const Duration(milliseconds: 50),
);

void main() {
  const key = BrowserSessionStore.key;

  test('keeps the session for the tab only by default', () async {
    final local = _Storage();
    final store = _tab(local);
    await store.load();
    expect(store.current, isNull);
    expect(store.keepSignedIn, isFalse);

    await store.write('token');
    expect(store.current, 'token');
    expect((store.tab as _Storage).values[key], 'token');
    expect(local.values, isEmpty);

    // Closing the browser ends the session.
    final later = _tab(local);
    await later.load();
    expect(later.current, isNull);
  });

  test('"Stay signed in" keeps the session in localStorage', () async {
    final local = _Storage();
    final store = _tab(local)..keepSignedIn = true;
    await store.write('token');
    expect(local.values[key], 'token');
    expect((store.tab as _Storage).values, isEmpty);

    final later = _tab(local);
    await later.load();
    expect(later.current, 'token');
    expect(later.keepSignedIn, isTrue);

    // A refreshed token goes where the session is.
    await later.write('token-2');
    expect(local.values[key], 'token-2');

    await later.delete();
    expect(later.current, isNull);
    expect(local.values, isEmpty);
  });

  test('a new tab gets the session of an open tab', () async {
    final channels = _Channels();
    final local = _Storage();
    final first = _tab(local, channels: channels);
    await first.load();
    await first.write('token');

    final second = _tab(local, channels: channels);
    await second.load();
    expect(second.current, 'token');
    expect(second.keepSignedIn, isFalse);
    expect((second.tab as _Storage).values[key], 'token');
  });

  test('without open tabs a new tab starts signed out', () async {
    final channels = _Channels();
    final local = _Storage();
    final first = _tab(local, channels: channels);
    await first.load(); // signed out: does not answer

    final second = _tab(local, channels: channels);
    await second.load();
    expect(second.current, isNull);
  });

  test('signing out in one tab signs out the others', () async {
    final channels = _Channels();
    final local = _Storage();
    var signedOutElsewhere = 0;
    final first = _tab(local, channels: channels);
    final second = _tab(
      local,
      channels: channels,
      onSignedOut: () => signedOutElsewhere++,
    );
    await first.write('token');
    await second.write('token');

    await first.delete();
    await pumpEventQueue();
    expect(second.current, isNull);
    expect((second.tab as _Storage).values, isEmpty);
    expect(signedOutElsewhere, 1);

    // Signing out again (already signed out) does not notify anyone.
    await first.delete();
    await pumpEventQueue();
    expect(signedOutElsewhere, 1);
  });
}

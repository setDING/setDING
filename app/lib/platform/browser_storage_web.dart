import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../sync/browser_session_store.dart';

/// `sessionStorage` or `localStorage` of the page.
class BrowserKeyValueStorage implements KeyValueStorage {
  BrowserKeyValueStorage(this._storage);

  BrowserKeyValueStorage.session() : this(web.window.sessionStorage);

  BrowserKeyValueStorage.local() : this(web.window.localStorage);

  final web.Storage _storage;

  @override
  String? read(String key) => _storage.getItem(key);

  @override
  void write(String key, String value) => _storage.setItem(key, value);

  @override
  void remove(String key) => _storage.removeItem(key);
}

/// A `BroadcastChannel` between the tabs of the web client.
class BroadcastTabChannel implements TabChannel {
  BroadcastTabChannel(String name) : _channel = web.BroadcastChannel(name);

  final web.BroadcastChannel _channel;

  @override
  void post(String message) => _channel.postMessage(message.toJS);

  @override
  Stream<String> get messages => web.EventStreamProviders.messageEvent
      .forTarget(_channel)
      .map((event) => event.data)
      .where((data) => data.isA<JSString>())
      .map((data) => (data as JSString).toDart);
}

/// Reloads the page (another tab signed out).
void reloadPage() => web.window.location.reload();

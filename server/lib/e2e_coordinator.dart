// Coordinator of the end-to-end tests (make e2e, issue #692,
// docs/development/e2e-tests.md): one proxy per client in front of the
// local PocketBase, plus the endpoints the clients use to coordinate their
// steps.
//
// Every client talks to the backend only through its own proxy, so the test
// can put one client offline ([E2eCoordinator.setOnline]): new requests
// fail like a lost network and open responses (the realtime connection) are
// cut. The web client is also served through its proxy, so the
// coordination endpoints are on the page's own origin.
//
// Endpoints under /__e2e/ (on every proxy, also while offline):
//
//   POST /__e2e/signal/<name>          marks the step <name> as reached
//   GET  /__e2e/wait/<name>?timeout=s  200 once <name> is reached, 408 after
//                                      the timeout (default 1 s), 410 when a
//                                      client gave up (body: its reason)
//   POST /__e2e/abort                  a client failed (body: the reason)
//   POST /__e2e/offline/<client>       puts <client> offline
//   POST /__e2e/online/<client>        puts <client> online again
import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// The shared state of the clients' proxies.
class E2eCoordinator {
  E2eCoordinator(this.backend);

  /// The PocketBase the proxies forward to.
  final Uri backend;

  final _signals = <String>{};
  final _waiters = <String, List<Completer<void>>>{};
  final _proxies = <String, E2eProxy>{};
  String? _abort;

  /// The reason a client gave up, if one did.
  String? get abortReason => _abort;

  /// The proxy of each client.
  Map<String, E2eProxy> get proxies => Map.unmodifiable(_proxies);

  /// Starts a proxy for the client [name] on a free local port.
  Future<E2eProxy> addClient(String name) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final proxy = E2eProxy._(this, name, server);
    _proxies[name] = proxy;
    return proxy;
  }

  /// Marks the step [name] as reached.
  void signal(String name) {
    _signals.add(name);
    for (final waiter in _waiters.remove(name) ?? const <Completer<void>>[]) {
      if (!waiter.isCompleted) waiter.complete();
    }
  }

  /// Completes once [name] is reached; throws [TimeoutException] after
  /// [timeout] and [E2eAborted] when a client gave up.
  Future<void> wait(String name, Duration timeout) async {
    if (_abort != null) throw E2eAborted(_abort!);
    if (_signals.contains(name)) return;
    final waiter = Completer<void>();
    (_waiters[name] ??= []).add(waiter);
    try {
      await waiter.future.timeout(timeout);
    } finally {
      _waiters[name]?.remove(waiter);
    }
    if (_abort != null && !_signals.contains(name)) throw E2eAborted(_abort!);
  }

  /// A client gave up: every waiting and later [wait] fails with [reason].
  void abort(String reason) {
    _abort ??= reason.isEmpty ? 'a client failed' : reason;
    for (final waiters in _waiters.values) {
      for (final waiter in waiters) {
        if (!waiter.isCompleted) waiter.complete();
      }
    }
    _waiters.clear();
  }

  /// Puts the client [name] online or offline.
  void setOnline(String name, {required bool online}) {
    final proxy = _proxies[name];
    if (proxy == null) throw ArgumentError.value(name, 'name', 'no client');
    proxy._setOnline(online);
  }

  Future<void> close() async {
    for (final proxy in _proxies.values) {
      await proxy._close();
    }
  }

  Future<void> _handleControl(HttpRequest request, List<String> path) async {
    final response = request.response;
    // The web client calls the endpoints with fetch from its own origin;
    // the Linux client with package:http.
    response.headers.set('cache-control', 'no-store');
    Future<void> reply(int status, [String body = '']) async {
      response.statusCode = status;
      response.write(body);
      await response.close();
    }

    final body = await utf8.decodeStream(request);
    final command = path.isEmpty ? '' : path.first;
    final argument = path.length > 1 ? Uri.decodeComponent(path[1]) : '';
    switch ((request.method, command)) {
      case ('POST', 'signal') when argument.isNotEmpty:
        signal(argument);
        return reply(HttpStatus.ok);
      case ('GET', 'wait') when argument.isNotEmpty:
        final seconds =
            double.tryParse(request.uri.queryParameters['timeout'] ?? '') ?? 1;
        try {
          await wait(
            argument,
            Duration(milliseconds: (seconds * 1000).round()),
          );
          return await reply(HttpStatus.ok);
        } on TimeoutException {
          return reply(HttpStatus.requestTimeout);
        } on E2eAborted catch (e) {
          return reply(HttpStatus.gone, e.reason);
        }
      case ('POST', 'abort'):
        abort(body);
        return reply(HttpStatus.ok);
      case ('POST', 'offline' || 'online') when _proxies.containsKey(argument):
        setOnline(argument, online: command == 'online');
        return reply(HttpStatus.ok);
      default:
        return reply(HttpStatus.notFound, 'unknown e2e command');
    }
  }
}

/// A client gave up; the others stop waiting for it.
class E2eAborted implements Exception {
  E2eAborted(this.reason);

  final String reason;

  @override
  String toString() => 'E2eAborted: $reason';
}

/// The proxy of one client in front of the backend.
class E2eProxy {
  E2eProxy._(this._coordinator, this.name, this._server) {
    _server.listen(_handle);
  }

  final E2eCoordinator _coordinator;

  /// The client's name, e.g. `a`.
  final String name;

  final HttpServer _server;
  final _client = HttpClient()..autoUncompress = false;
  final _open = <HttpClientRequest>{};
  final _streams = <void Function()>{};
  var _online = true;

  /// The URL the client uses as its server.
  Uri get url => Uri.parse('http://127.0.0.1:${_server.port}');

  bool get online => _online;

  void _setOnline(bool online) {
    _online = online;
    if (online) return;
    // Like a lost network: the open responses (realtime) end.
    for (final request in _open.toList()) {
      request.abort(const SocketException('e2e: offline'));
    }
    for (final cut in _streams.toList()) {
      cut();
    }
  }

  Future<void> _handle(HttpRequest request) async {
    final segments = request.uri.pathSegments;
    if (segments.isNotEmpty && segments.first == '__e2e') {
      try {
        await _coordinator._handleControl(request, segments.sublist(1));
      } catch (_) {
        // The client went away while waiting.
      }
      return;
    }
    if (!_online) {
      // The connection fails as if there were no network.
      final socket = await request.response.detachSocket(writeHeaders: false);
      socket.destroy();
      return;
    }
    await _forward(request);
  }

  static const _hopByHop = {
    'connection',
    'keep-alive',
    'transfer-encoding',
    'upgrade',
    'host',
  };

  Future<void> _forward(HttpRequest request) async {
    final target = _coordinator.backend.replace(
      path: request.uri.path,
      query: request.uri.hasQuery ? request.uri.query : null,
    );
    final response = request.response;
    HttpClientRequest? upstream;
    try {
      upstream = await _client.openUrl(request.method, target);
      _open.add(upstream);
      upstream.followRedirects = false;
      request.headers.forEach((header, values) {
        if (_hopByHop.contains(header)) return;
        for (final value in values) {
          upstream!.headers.add(header, value, preserveHeaderCase: true);
        }
      });
      await upstream.addStream(request);
      final answer = await upstream.close();
      response.statusCode = answer.statusCode;
      response.reasonPhrase = answer.reasonPhrase;
      response.bufferOutput = false; // realtime events go out at once
      answer.headers.forEach((header, values) {
        if (_hopByHop.contains(header)) return;
        for (final value in values) {
          response.headers.add(header, value, preserveHeaderCase: true);
        }
      });
      if (answer.headers.contentLength >= 0) {
        response.contentLength = answer.headers.contentLength;
      }
      // Passed on chunk by chunk, so going offline can end it.
      final done = Completer<void>();
      late final StreamSubscription<List<int>> data;
      void end() {
        if (done.isCompleted) return;
        unawaited(data.cancel());
        done.complete();
      }

      data = answer.listen(
        response.add,
        onDone: end,
        onError: (Object _) => end(),
        cancelOnError: true,
      );
      _streams.add(end);
      try {
        await done.future;
      } finally {
        _streams.remove(end);
      }
      await response.close();
    } catch (_) {
      // Offline, or one side went away: the client sees a broken
      // connection.
      try {
        final socket = await response.detachSocket(writeHeaders: false);
        socket.destroy();
      } catch (_) {
        try {
          await response.close();
        } catch (_) {}
      }
    } finally {
      _open.remove(upstream);
    }
  }

  Future<void> _close() async {
    _setOnline(false);
    await _server.close(force: true);
    _client.close(force: true);
  }
}

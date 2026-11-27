import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'projection_state.dart';
import 'projection_token.dart';

/// The local web server of the lyrics projection (ADR-0068 §1–4).
///
/// Serves one page and one Server-Sent Events stream of the current
/// [ProjectionState] under `/p/<token>`, to private network addresses
/// only. Everything else gets 404. Read-only: nothing a browser sends
/// changes anything in the app.
class ProjectionServer {
  ProjectionServer({
    required this.page,
    this.heartbeat = const Duration(seconds: 5),
    this.maxClients = 32,
  });

  /// Whether this platform can host the projection (native apps, not web).
  static const supported = true;

  /// The port tried first; another free port is taken when it is in use.
  static const defaultPort = 8231;

  /// The HTML of the projected page (an app asset, ADR-0068 §3).
  final String page;

  /// How often an idle stream gets a comment so browsers and proxies keep
  /// it open and a dropped client is noticed.
  final Duration heartbeat;

  /// Streams beyond this many are refused with 503.
  final int maxClients;

  HttpServer? _server;
  String? _token;
  Timer? _heartbeat;
  ProjectionState _state = const ProjectionState.blank();
  final _clients = <_Client>{};

  /// Whether the server is listening.
  bool get running => _server != null;

  /// The port it listens on; null while stopped.
  int? get port => _server?.port;

  /// The token of this start: the one passed to [start], or a new one.
  String? get token => _token;

  /// The number of connected streams.
  int get clients => _clients.length;

  /// The state currently shown.
  ProjectionState get state => _state;

  /// Starts listening on all interfaces at [port], or at a free port when
  /// it is taken, with [token] (the device's, #1183) or a new one. Does
  /// nothing when already running.
  Future<void> start({int port = defaultPort, String? token}) async {
    if (_server != null) return;
    final server = await _bind(port);
    _token = isProjectionToken(token) ? token : newProjectionToken();
    _server = server;
    server.listen(_handle, onError: (_) {});
    _heartbeat = Timer.periodic(heartbeat, (_) => _sendAll(': ping\n\n'));
  }

  /// Stops listening and closes every stream.
  Future<void> stop() async {
    final server = _server;
    if (server == null) return;
    _server = null;
    _token = null;
    _heartbeat?.cancel();
    _heartbeat = null;
    for (final client in _clients.toList()) {
      client.close();
    }
    _clients.clear();
    await server.close(force: true);
  }

  /// Shows [state] in every connected browser. Never waits for a client.
  void update(ProjectionState state) {
    _state = state;
    _sendAll(_event(state));
  }

  /// `http://<address>:<port>/p/<token>` for every private address of the
  /// device, IPv4 first; empty while stopped.
  Future<List<Uri>> urls() async {
    final port = this.port, token = _token;
    if (port == null || token == null) return const [];
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.any,
    );
    final addresses =
        [
          for (final i in interfaces)
            for (final a in i.addresses)
              if (!a.isLoopback && isPrivateAddress(a)) a,
        ]..sort(
          (a, b) => a.type == b.type
              ? 0
              : (a.type == InternetAddressType.IPv4 ? -1 : 1),
        );
    return [
      for (final a in addresses)
        Uri(
          scheme: 'http',
          host: a.type == InternetAddressType.IPv6
              ? a.address.split('%').first
              : a.address,
          port: port,
          path: '/p/$token',
        ),
    ];
  }

  static Future<HttpServer> _bind(int port) async {
    Future<HttpServer> bind(int p) async {
      try {
        return await HttpServer.bind(InternetAddress.anyIPv6, p);
      } on SocketException {
        // IPv6 disabled on the device: IPv4 only.
        return HttpServer.bind(InternetAddress.anyIPv4, p);
      }
    }

    try {
      return await bind(port);
    } on SocketException {
      if (port == 0) rethrow;
      return bind(0);
    }
  }

  void _handle(HttpRequest request) {
    final response = request.response;
    final token = _token;
    final remote = request.connectionInfo?.remoteAddress;
    final segments = request.uri.pathSegments;
    final allowed =
        token != null &&
        remote != null &&
        isPrivateAddress(remote) &&
        request.method == 'GET' &&
        segments.length >= 2 &&
        segments.length <= 3 &&
        segments[0] == 'p' &&
        _sameToken(segments[1], token);
    final route = allowed ? (segments.length == 2 ? '' : segments[2]) : null;
    _headers(response);
    switch (route) {
      case '' || 'lower-third':
        response.headers
          ..contentType = ContentType.html
          ..set(
            'Content-Security-Policy',
            "default-src 'self'; style-src 'self' 'unsafe-inline'; "
                "script-src 'self' 'unsafe-inline'; frame-ancestors 'none'",
          );
        response
          ..write(page)
          ..close().ignore();
      case 'events':
        _openStream(response);
      default:
        response
          ..statusCode = HttpStatus.notFound
          ..close().ignore();
    }
  }

  void _openStream(HttpResponse response) {
    if (_clients.length >= maxClients) {
      response
        ..statusCode = HttpStatus.serviceUnavailable
        ..close().ignore();
      return;
    }
    response
      ..bufferOutput = false
      ..headers.contentType = ContentType(
        'text',
        'event-stream',
        charset: 'utf-8',
      );
    final client = _Client(response);
    _clients.add(client);
    client.done.then((_) => _clients.remove(client));
    client.send('retry: 2000\n\n${_event(_state)}');
  }

  void _sendAll(String data) {
    for (final client in _clients.toList()) {
      client.send(data);
    }
  }

  static String _event(ProjectionState state) =>
      'event: state\ndata: ${jsonEncode(state.toJson())}\n\n';

  static void _headers(HttpResponse response) {
    response.headers
      ..set(HttpHeaders.cacheControlHeader, 'no-store')
      ..set('X-Content-Type-Options', 'nosniff')
      ..set('Referrer-Policy', 'no-referrer');
  }

  /// Compares in constant time, so the token cannot be guessed by timing.
  static bool _sameToken(String given, String token) {
    if (given.length != token.length) return false;
    var diff = 0;
    for (var i = 0; i < token.length; i++) {
      diff |= given.codeUnitAt(i) ^ token.codeUnitAt(i);
    }
    return diff == 0;
  }
}

/// Whether [address] is loopback or in a private range (ADR-0068 §1):
/// IPv4 10/8, 172.16/12, 192.168/16, link-local 169.254/16, IPv6 unique
/// local fc00::/7 and link-local fe80::/10, and IPv4 mapped into IPv6.
bool isPrivateAddress(InternetAddress address) {
  if (address.isLoopback) return true;
  final raw = address.rawAddress;
  if (address.type == InternetAddressType.IPv4) return _privateV4(raw);
  if (address.type != InternetAddressType.IPv6 || raw.length != 16) {
    return false;
  }
  final mapped =
      raw.sublist(0, 10).every((b) => b == 0) &&
      raw[10] == 0xff &&
      raw[11] == 0xff;
  if (mapped) {
    final v4 = raw.sublist(12);
    return v4[0] == 127 || _privateV4(v4);
  }
  return (raw[0] & 0xfe) == 0xfc || (raw[0] == 0xfe && (raw[1] & 0xc0) == 0x80);
}

bool _privateV4(List<int> b) =>
    b.length == 4 &&
    (b[0] == 10 ||
        (b[0] == 172 && b[1] >= 16 && b[1] <= 31) ||
        (b[0] == 192 && b[1] == 168) ||
        (b[0] == 169 && b[1] == 254));

/// One open event stream. Writes go through a stream controller, so a slow
/// browser never blocks the app; a failed or closed stream ends [done].
class _Client {
  _Client(this._response) {
    done = _response
        .addStream(_out.stream)
        .then((_) => _response.close())
        .catchError((_) {})
        .whenComplete(() => _closed = true);
    // The browser went away: end the stream instead of buffering for it.
    _response.done.catchError((_) {}).whenComplete(close);
  }

  final HttpResponse _response;
  final _out = StreamController<List<int>>();
  late final Future<void> done;
  var _closed = false;

  void send(String data) {
    if (!_closed && !_out.isClosed) _out.add(utf8.encode(data));
  }

  void close() {
    if (!_out.isClosed) _out.close();
  }
}

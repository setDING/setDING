import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:chordpro/chordpro.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setding/projection/projection_server_io.dart';
import 'package:setding/projection/projection_server_web.dart' as web;
import 'package:setding/projection/projection_state.dart';

/// The local web server of the lyrics projection (ADR-0068 §1–4, #1167).
void main() {
  late ProjectionServer server;
  late HttpClient http;

  setUp(() async {
    server = ProjectionServer(
      page: '<!doctype html><title>Projection</title>',
      heartbeat: const Duration(milliseconds: 100),
      maxClients: 3,
    );
    await server.start(port: 0);
    http = HttpClient();
  });

  tearDown(() async {
    http.close(force: true);
    await server.stop();
  });

  Uri url(String path) => Uri.parse('http://127.0.0.1:${server.port}$path');

  Future<HttpClientResponse> get(String path, {String method = 'GET'}) async {
    final request = await http.openUrl(method, url(path));
    return request.close();
  }

  Future<int> status(String path, {String method = 'GET'}) async {
    final response = await get(path, method: method);
    await response.drain<void>();
    return response.statusCode;
  }

  /// The `state` events of a stream, decoded, and the raw text received.
  Future<({StreamQueue events, HttpClientResponse response})> stream() async {
    final response = await get('/p/${server.token}/events');
    final queue = StreamQueue(response);
    return (events: queue, response: response);
  }

  group('access', () {
    test('serves the page with the token, also as the lower third', () async {
      for (final path in [
        '/p/${server.token}',
        '/p/${server.token}/lower-third',
      ]) {
        final response = await get(path);
        expect(response.statusCode, HttpStatus.ok, reason: path);
        expect(response.headers.contentType?.mimeType, 'text/html');
        expect(response.headers.value('cache-control'), 'no-store');
        expect(response.headers.value('x-content-type-options'), 'nosniff');
        expect(
          response.headers.value('content-security-policy'),
          contains("default-src 'self'"),
        );
        expect(
          await response.transform(utf8.decoder).join(),
          contains('<title>Projection</title>'),
        );
      }
    });

    test('everything without the right token is 404', () async {
      final token = server.token!;
      final wrong = token.replaceRange(0, 1, token[0] == 'A' ? 'B' : 'A');
      for (final path in [
        '/',
        '/p',
        '/p/',
        '/p/$wrong',
        '/p/$wrong/events',
        '/p/${token}x',
        '/p/$token/other',
        '/p/$token/events/more',
        '/api/collections/songs/records',
        '/$token',
      ]) {
        expect(await status(path), HttpStatus.notFound, reason: path);
      }
    });

    test('other methods are 404', () async {
      for (final method in ['POST', 'PUT', 'DELETE', 'HEAD']) {
        expect(
          await status('/p/${server.token}', method: method),
          HttpStatus.notFound,
          reason: method,
        );
      }
    });

    test('a new start has a new token; the old link stops working', () async {
      final old = server.token!;
      expect(old, hasLength(22));
      await server.stop();
      expect(server.running, isFalse);
      expect(server.token, isNull);
      await server.start(port: 0);
      expect(server.token, isNot(old));
      expect(await status('/p/$old'), HttpStatus.notFound);
      expect(await status('/p/${server.token}'), HttpStatus.ok);
    });

    test('takes another port when the default one is in use', () async {
      final taken = await ServerSocket.bind(InternetAddress.anyIPv6, 0);
      addTearDown(taken.close);
      final other = ProjectionServer(page: '');
      addTearDown(other.stop);
      await other.start(port: taken.port);
      expect(other.running, isTrue);
      expect(other.port, isNot(taken.port));
    });

    test('urls name private addresses with port and token', () async {
      final urls = await server.urls();
      for (final u in urls) {
        expect(u.scheme, 'http');
        expect(u.port, server.port);
        expect(u.path, '/p/${server.token}');
        expect(isPrivateAddress(InternetAddress(u.host)), isTrue);
      }
      await server.stop();
      expect(await server.urls(), isEmpty);
    });
  });

  test('the web client has no projection', () async {
    final stub = web.ProjectionServer(page: '');
    expect(web.ProjectionServer.supported, isFalse);
    expect(ProjectionServer.supported, isTrue);
    await expectLater(stub.start(), throwsUnsupportedError);
    expect(stub.running, isFalse);
    expect(await stub.urls(), isEmpty);
  });

  group('isPrivateAddress', () {
    bool private(String a) => isPrivateAddress(InternetAddress(a));

    test('private, link-local and loopback addresses', () {
      for (final a in [
        '10.0.0.1',
        '10.255.255.255',
        '172.16.0.1',
        '172.31.255.1',
        '192.168.1.23',
        '169.254.10.1',
        '127.0.0.1',
        '::1',
        'fd12:3456::1',
        'fc00::1',
        'fe80::1',
        '::ffff:192.168.1.5',
        '::ffff:127.0.0.1',
      ]) {
        expect(private(a), isTrue, reason: a);
      }
    });

    test('public addresses are refused', () {
      for (final a in [
        '8.8.8.8',
        '172.15.0.1',
        '172.32.0.1',
        '192.169.0.1',
        '100.64.0.1',
        '11.0.0.1',
        '2001:4860:4860::8888',
        'fec0::1',
        '::ffff:8.8.8.8',
        '0.0.0.0',
      ]) {
        expect(private(a), isFalse, reason: a);
      }
    });
  });

  group('state stream', () {
    final slide = lyricSlides([
      LyricSection(
        section: Section(kind: SectionKind.verse),
        lines: const ['Amazing grace', 'how sweet the sound'],
        label: 'Verse 1',
      ),
      LyricSection(
        section: Section(kind: SectionKind.chorus),
        lines: const ['Chorus'],
      ),
    ]);

    test('sends the current state at once, then every update', () async {
      final (:events, :response) = await stream();
      expect(response.headers.contentType?.mimeType, 'text/event-stream');
      expect(response.headers.value('cache-control'), 'no-store');
      expect(await events.nextState(), containsPair('blank', true));
      server.update(
        ProjectionState.slide(
          slide[0],
          title: 'Amazing Grace',
          copyright: 'Public domain',
          next: slide[1],
        ),
      );
      expect(await events.nextState(), {
        'v': 1,
        'blank': false,
        'title': 'Amazing Grace',
        'copyright': 'Public domain',
        'label': 'Verse 1',
        'lines': ['Amazing grace', 'how sweet the sound'],
        'next': ['Chorus'],
        'style': {'theme': 'dark', 'font': 'sans', 'align': 'center'},
      });
      server.update(const ProjectionState.marker('Prayer'));
      expect(await events.nextState(), containsPair('marker', 'Prayer'));
      await events.cancel();
    });

    test(
      'several browsers follow; a reconnect gets the current state',
      () async {
        final a = await stream(), b = await stream();
        await a.events.nextState();
        await b.events.nextState();
        expect(server.clients, 2);
        server.update(ProjectionState.slide(slide[1]));
        expect((await a.events.nextState())['lines'], ['Chorus']);
        expect((await b.events.nextState())['lines'], ['Chorus']);
        await a.events.cancel();
        final c = await stream();
        expect((await c.events.nextState())['lines'], ['Chorus']);
        await b.events.cancel();
        await c.events.cancel();
      },
    );

    test('an idle stream gets heartbeats', () async {
      final (:events, response: _) = await stream();
      await events.nextState();
      expect(await events.nextRaw(), contains(': ping'));
      await events.cancel();
    });

    test('a closed browser is dropped', () async {
      final (:events, response: _) = await stream();
      await events.nextState();
      expect(server.clients, 1);
      await events.cancel();
      http.close(force: true);
      for (var i = 0; i < 50 && server.clients > 0; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        server.update(const ProjectionState.blank());
      }
      expect(server.clients, 0);
    });

    test('streams beyond the limit are refused', () async {
      final open = [for (var i = 0; i < 3; i++) await stream()];
      for (final s in open) {
        await s.events.nextState();
      }
      expect(await status('/p/${server.token}/events'), 503);
      for (final s in open) {
        await s.events.cancel();
      }
    });

    test('stop ends every stream', () async {
      final (:events, response: _) = await stream();
      await events.nextState();
      await server.stop();
      expect(server.clients, 0);
      expect(await events.rest(), isTrue);
    });
  });
}

/// Reads Server-Sent Events from a response, one event block at a time.
class StreamQueue {
  StreamQueue(Stream<List<int>> body) {
    _sub = body
        .transform(utf8.decoder)
        .listen(
          (chunk) {
            _buffer.write(chunk);
            _drain();
          },
          onDone: () {
            _done = true;
            _drain();
          },
          onError: (_) {
            _done = true;
            _drain();
          },
        );
  }

  late final StreamSubscription<String> _sub;
  final _buffer = StringBuffer();
  final _blocks = <String>[];
  final _waiting = <Completer<String?>>[];
  var _done = false;

  void _drain() {
    var text = _buffer.toString();
    var end = text.indexOf('\n\n');
    while (end >= 0) {
      final block = text.substring(0, end);
      text = text.substring(end + 2);
      if (!block.startsWith('retry:')) _blocks.add(block);
      end = text.indexOf('\n\n');
    }
    _buffer
      ..clear()
      ..write(text);
    while (_waiting.isNotEmpty && (_blocks.isNotEmpty || _done)) {
      _waiting
          .removeAt(0)
          .complete(_blocks.isEmpty ? null : _blocks.removeAt(0));
    }
  }

  /// The next block as received (an event or a comment).
  Future<String> nextRaw() async {
    if (_blocks.isNotEmpty) return _blocks.removeAt(0);
    final c = Completer<String?>();
    _waiting.add(c);
    _drain();
    final block = await c.future.timeout(const Duration(seconds: 5));
    if (block == null) throw StateError('stream ended');
    return block;
  }

  /// The data of the next `state` event, heartbeats skipped.
  Future<Map<String, Object?>> nextState() async {
    while (true) {
      final block = await nextRaw();
      if (!block.startsWith('event: state\n')) continue;
      final data = block.split('\n').firstWhere((l) => l.startsWith('data: '));
      return jsonDecode(data.substring(6)) as Map<String, Object?>;
    }
  }

  /// Waits until the server ends the stream; true when it did.
  Future<bool> rest() async {
    for (var i = 0; i < 100 && !_done; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    return _done;
  }

  Future<void> cancel() => _sub.cancel();
}

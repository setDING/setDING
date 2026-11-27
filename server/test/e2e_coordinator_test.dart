// The proxies and coordination endpoints of the end-to-end tests
// (lib/e2e_coordinator.dart, issue #692), against a small fake backend.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:setding_server/e2e_coordinator.dart';
import 'package:test/test.dart';

void main() {
  late HttpServer backend;
  late E2eCoordinator coordinator;
  late E2eProxy proxy;
  late StreamController<String> events;

  setUp(() async {
    events = StreamController<String>();
    backend = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    backend.listen((request) async {
      final response = request.response;
      switch (request.uri.path) {
        case '/echo':
          final body = await utf8.decodeStream(request);
          response.headers.set('x-echo', request.headers.value('x-test') ?? '');
          response.write(
            jsonEncode({
              'method': request.method,
              'query': request.uri.query,
              'body': body,
            }),
          );
          await response.close();
        case '/events':
          // Like PocketBase's realtime connection: an open response.
          response.headers.contentType = ContentType('text', 'event-stream');
          response.bufferOutput = false;
          // Like PocketBase's PB_CONNECT event; dart:io sends the headers
          // with the first data.
          response.write('data: connect\n\n');
          await response.addStream(events.stream.map(utf8.encode));
          await response.close();
        default:
          response.statusCode = 404;
          await response.close();
      }
    });
    coordinator = E2eCoordinator(Uri.parse('http://127.0.0.1:${backend.port}'));
    proxy = await coordinator.addClient('a');
  });

  tearDown(() async {
    await coordinator.close();
    await backend.close(force: true);
    // Not awaited: without a listener, close() never completes.
    unawaited(events.close());
  });

  Uri at(String path) => proxy.url.replace(path: path);

  test('forwards requests with method, query, headers and body', () async {
    final r = await http.post(
      at('/echo').replace(query: 'a=1&b=2'),
      headers: {'x-test': 'hello'},
      body: 'payload',
    );
    expect(r.statusCode, 200);
    expect(r.headers['x-echo'], 'hello');
    expect(jsonDecode(r.body), {
      'method': 'POST',
      'query': 'a=1&b=2',
      'body': 'payload',
    });
    expect((await http.get(at('/missing'))).statusCode, 404);
  });

  test('passes events of an open response on at once', () async {
    final client = http.Client();
    addTearDown(client.close);
    final response = await client
        .send(http.Request('GET', at('/events')))
        .timeout(const Duration(seconds: 5));
    final chunks = StreamIterator(response.stream.transform(utf8.decoder));
    addTearDown(chunks.cancel);
    Future<String> next() async {
      expect(
        await chunks.moveNext().timeout(const Duration(seconds: 5)),
        isTrue,
      );
      return chunks.current;
    }

    expect(await next(), 'data: connect\n\n');
    events.add('data: one\n\n');
    expect(await next(), 'data: one\n\n');
  });

  test('offline: requests fail and open responses end; online again', () async {
    final client = http.Client();
    addTearDown(client.close);
    final stream = await client
        .send(http.Request('GET', at('/events')))
        .timeout(const Duration(seconds: 5));
    final ended = stream.stream.drain<void>().then(
      (_) => true,
      onError: (_) {
        return true;
      },
    );

    coordinator.setOnline('a', online: false);
    expect(proxy.online, isFalse);
    expect(await ended.timeout(const Duration(seconds: 5)), isTrue);
    await expectLater(
      http.get(at('/echo')),
      throwsA(isA<http.ClientException>()),
    );
    // The coordination endpoints keep working.
    expect((await http.post(at('/__e2e/signal/x'))).statusCode, 200);

    coordinator.setOnline('a', online: true);
    expect((await http.get(at('/echo'))).statusCode, 200);
  });

  test('offline and online through the endpoints', () async {
    expect((await http.post(at('/__e2e/offline/a'))).statusCode, 200);
    expect(proxy.online, isFalse);
    expect((await http.post(at('/__e2e/online/a'))).statusCode, 200);
    expect(proxy.online, isTrue);
    expect((await http.post(at('/__e2e/offline/zz'))).statusCode, 404);
  });

  test('wait answers once the step is signalled, 408 before', () async {
    expect(
      (await http.get(at('/__e2e/wait/ready').replace(query: 'timeout=0.1')))
          .statusCode,
      408,
    );
    final waiting = http.get(
      at('/__e2e/wait/ready').replace(query: 'timeout=5'),
    );
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect((await http.post(at('/__e2e/signal/ready'))).statusCode, 200);
    expect((await waiting).statusCode, 200);
    // A step stays reached.
    expect((await http.get(at('/__e2e/wait/ready'))).statusCode, 200);
  });

  test('abort ends every wait with the reason', () async {
    final waiting = http.get(
      at('/__e2e/wait/never').replace(query: 'timeout=5'),
    );
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await http.post(at('/__e2e/abort'), body: 'client b failed');
    final r = await waiting;
    expect(r.statusCode, 410);
    expect(r.body, 'client b failed');
    expect(coordinator.abortReason, 'client b failed');
    expect((await http.get(at('/__e2e/wait/other'))).statusCode, 410);
  });

  test('unknown commands are refused', () async {
    expect((await http.get(at('/__e2e/nothing'))).statusCode, 404);
  });
}

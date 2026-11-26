// The website server (tool/site/Caddyfile, ADR-0030) with the pinned Caddy
// (tool/fetch-tool.sh, issue #644): the real configuration, only the port and
// the site directory replaced.
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

final _root = Directory.current.parent.path;

Future<String> _caddyBinary() async {
  final fromEnv = Platform.environment['CADDY_BIN'];
  if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
  final fetch = await Process.run('$_root/tool/fetch-tool.sh', ['caddy']);
  if (fetch.exitCode != 0) {
    throw StateError('fetching Caddy failed: ${fetch.stderr}');
  }
  return (fetch.stdout as String).trim();
}

Future<int> _freePort() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  return port;
}

void main() {
  late Process caddy;
  late Directory dir;
  late int port;
  final client = HttpClient();

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('setding-site-');
    final site = Directory('${dir.path}/site')..createSync();
    File('${site.path}/index.html').writeAsStringSync('<h1>setDING</h1>');
    File('${site.path}/404.html').writeAsStringSync('<h1>Not found</h1>');
    Directory('${site.path}/_astro').createSync();
    File(
      '${site.path}/_astro/app.abc123.js',
    ).writeAsStringSync('console.log("${'x' * 2000}");');

    port = await _freePort();
    final original = File('$_root/tool/site/Caddyfile').readAsStringSync();
    expect(original, contains('http://:8081 {'));
    expect(original, contains('root * /var/www/setding-site'));
    final config = original
        .replaceFirst('auto_https off', 'auto_https off\n\tadmin off')
        .replaceFirst('http://:8081 {', 'http://:$port {')
        .replaceFirst('root * /var/www/setding-site', 'root * ${site.path}');
    final caddyfile = File('${dir.path}/Caddyfile')..writeAsStringSync(config);

    caddy = await Process.start(
      await _caddyBinary(),
      ['run', '--adapter', 'caddyfile', '--config', caddyfile.path],
      environment: {'XDG_DATA_HOME': dir.path, 'XDG_CONFIG_HOME': dir.path},
    );
    final log = StringBuffer();
    caddy.stdout.transform(utf8.decoder).listen(log.write);
    caddy.stderr.transform(utf8.decoder).listen(log.write);
    final deadline = DateTime.now().add(const Duration(seconds: 20));
    while (true) {
      try {
        final s = await Socket.connect(InternetAddress.loopbackIPv4, port);
        s.destroy();
        break;
      } on SocketException {
        if (DateTime.now().isAfter(deadline)) {
          caddy.kill();
          throw StateError('Caddy did not start:\n$log');
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
  });

  tearDownAll(() async {
    client.close(force: true);
    caddy.kill();
    await caddy.exitCode;
    await dir.delete(recursive: true);
  });

  Future<HttpClientResponse> get(
    String path, {
    String host = 'setding.app',
    String? acceptEncoding,
  }) async {
    final request = await client.get('127.0.0.1', port, path);
    request.followRedirects = false;
    // As through the tunnel: the Host header carries no port.
    request.headers
      ..host = host
      ..port = 80;
    request.headers.set(
      HttpHeaders.acceptEncodingHeader,
      acceptEncoding ?? 'identity',
    );
    return request.close();
  }

  test('serves the site; pages are revalidated on every visit', () async {
    final r = await get('/');
    expect(r.statusCode, 200);
    expect(await utf8.decodeStream(r), '<h1>setDING</h1>');
    expect(r.headers.value('cache-control'), 'no-cache');
  });

  test('hashed assets under /_astro/ are cached for a year', () async {
    final r = await get('/_astro/app.abc123.js');
    await r.drain<void>();
    expect(r.statusCode, 200);
    expect(
      r.headers.value('cache-control'),
      'public, max-age=31536000, immutable',
    );
  });

  test('compresses responses', () async {
    final r = await get('/_astro/app.abc123.js', acceptEncoding: 'gzip');
    await r.drain<void>();
    expect(r.headers.value('content-encoding'), 'gzip');
  });

  test('www redirects permanently to the bare domain over HTTPS', () async {
    final r = await get('/docs/?x=1', host: 'www.setding.app');
    await r.drain<void>();
    expect(r.statusCode, 308);
    expect(r.headers.value('location'), 'https://setding.app/docs/?x=1');
  });

  test('unknown pages show the 404 page with status 404', () async {
    final r = await get('/no-such-page');
    expect(r.statusCode, 404);
    expect(await utf8.decodeStream(r), '<h1>Not found</h1>');
  });
}

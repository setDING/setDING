import 'dart:io';

import 'package:setding_server/pocketbase_harness.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

/// Hosting of the web client (ADR-0018): PocketBase serves the Flutter web
/// build from its public directory.
void main() {
  late PocketBase pb;
  late Directory public;
  const marker = '<!-- setding web client -->';

  setUpAll(() async {
    public = await Directory.systemTemp.createTemp('setding-public-');
    File('${public.path}/index.html').writeAsStringSync(
      '<!doctype html><html><head><base href="/"></head>'
      '<body>$marker</body></html>',
    );
    File('${public.path}/main.dart.js').writeAsStringSync('// app');
    pb = await PocketBase.start(
      publicDir: public.path,
      environment: {
        'SETDING_WEB_URL': 'https://web.test/',
        'SETDING_PUBLIC_DIR': public.path,
      },
    );
  });
  tearDownAll(() async {
    await pb.stop();
    await public.delete(recursive: true);
  });

  Future<String> token(BandFixture f) async {
    final r = await f.admin.send(
      'POST',
      '/api/setding/invites',
      body: {'organization': f.orgId},
    );
    r.expectStatus(200);
    return r.json['token'] as String;
  }

  void expectIsolated(Response r) {
    expect(r.raw.headers['cross-origin-opener-policy'], 'same-origin');
    expect(r.raw.headers['cross-origin-embedder-policy'], 'credentialless');
    // Revalidated on every load, so a deploy is visible at once (#121).
    expect(r.raw.headers['cache-control'], 'no-cache');
  }

  test('serves the web build with cross-origin isolation', () async {
    final page = await pb.guest.send('GET', '/');
    page.expectStatus(200);
    expect(page.raw.body, contains(marker));
    expectIsolated(page);

    final script = await pb.guest.send('GET', '/main.dart.js');
    script.expectStatus(200);
    expectIsolated(script);

    // Unchanged files are revalidated cheaply.
    final modified = script.raw.headers['last-modified'];
    expect(modified, isNotNull);
    final again = await pb.guest.send(
      'GET',
      '/main.dart.js',
      headers: {'if-modified-since': modified!},
    );
    again.expectStatus(304);

    // The API is unchanged.
    final health = await pb.guest.send('GET', '/api/health');
    health.expectStatus(200);
    expect(health.raw.headers['cross-origin-embedder-policy'], isNull);
    expect(health.raw.headers['cache-control'], isNot('no-cache'));
  });

  test('the landing page offers the web client', () async {
    final f = await BandFixture.create(pb);
    final t = await token(f);
    final r = await pb.guest.send('GET', '/invite/$t');
    r.expectStatus(200);
    expect(r.raw.body, contains('setding://invite/$t'));
    expect(r.raw.body, contains('Open in the browser'));
    expect(r.raw.body, contains('href="https://web.test/invite/$t"'));
  });

  test('on the web hostname an invitation opens the web client', () async {
    final f = await BandFixture.create(pb);
    final t = await token(f);
    final r = await pb.guest.send(
      'GET',
      '/invite/$t',
      headers: {'host': 'web.test'},
    );
    r.expectStatus(200);
    expect(r.raw.body, contains(marker));
    expect(r.raw.body, isNot(contains('setding://')));
    expectIsolated(r);
  });

  // ADR-0065 (#1113): screens have path URLs, so a reload or a shared link
  // on the web hostname loads the web client (PocketBase's index fallback),
  // not a 404.
  test('app paths on the web hostname serve the web client', () async {
    for (final path in ['/sets/abc', '/songs/abc/edit', '/settings/live']) {
      final r = await pb.guest.send('GET', path, headers: {'host': 'web.test'});
      r.expectStatus(200);
      expect(r.raw.body, contains(marker), reason: path);
      expectIsolated(r);
    }
  });
}

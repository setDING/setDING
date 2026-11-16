import 'dart:io';

import 'package:realchord_server/pocketbase_harness.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

/// Hosting of the web client (ADR-0018): PocketBase serves the Flutter web
/// build from its public directory.
void main() {
  late PocketBase pb;
  late Directory public;
  const marker = '<!-- realchord web client -->';

  setUpAll(() async {
    public = await Directory.systemTemp.createTemp('realchord-public-');
    File('${public.path}/index.html').writeAsStringSync(
      '<!doctype html><html><head><base href="/"></head>'
      '<body>$marker</body></html>',
    );
    File('${public.path}/main.dart.js').writeAsStringSync('// app');
    pb = await PocketBase.start(
      publicDir: public.path,
      environment: {
        'REALCHORD_WEB_URL': 'https://web.test/',
        'REALCHORD_PUBLIC_DIR': public.path,
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
      '/api/realchord/invites',
      body: {'organization': f.orgId},
    );
    r.expectStatus(200);
    return r.json['token'] as String;
  }

  void expectIsolated(Response r) {
    expect(r.raw.headers['cross-origin-opener-policy'], 'same-origin');
    expect(r.raw.headers['cross-origin-embedder-policy'], 'credentialless');
  }

  test('serves the web build with cross-origin isolation', () async {
    final page = await pb.guest.send('GET', '/');
    page.expectStatus(200);
    expect(page.raw.body, contains(marker));
    expectIsolated(page);

    final script = await pb.guest.send('GET', '/main.dart.js');
    script.expectStatus(200);
    expectIsolated(script);

    // The API is unchanged.
    final health = await pb.guest.send('GET', '/api/health');
    health.expectStatus(200);
    expect(health.raw.headers['cross-origin-embedder-policy'], isNull);
  });

  test('the landing page offers the web client', () async {
    final f = await BandFixture.create(pb);
    final t = await token(f);
    final r = await pb.guest.send('GET', '/invite/$t');
    r.expectStatus(200);
    expect(r.raw.body, contains('realchord://invite/$t'));
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
    expect(r.raw.body, isNot(contains('realchord://')));
    expectIsolated(r);
  });
}

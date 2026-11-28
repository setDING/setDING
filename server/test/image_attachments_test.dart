// Image attachments for `{image}` are synced like PDFs (ADR-0009, ADR-0012,
// issue #1227): the allowed and refused types (PocketBase detects the type
// from the content), the limits of ADR-0070, roles without upload rights,
// and how an SVG is served (protected, a download, sandboxed).
import 'dart:convert';

import 'package:setding_server/pocketbase_harness.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

const _mb = 1024 * 1024;

/// A 1×1 PNG.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

/// The start of a JPEG (SOI, JFIF APP0), enough for the type detection.
final _jpeg = [
  0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01, //
  0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0xFF, 0xD9,
];

/// A 1×1 GIF.
final _gif = base64Decode(
  'R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7',
);

/// A 1×1 WebP (lossless).
final _webp = base64Decode('UklGRhoAAABXRUJQVlA4TA0AAAAvAAAAEAcQERGIiP4HAA==');

final _pdf = utf8.encode(
  '%PDF-1.4\n1 0 obj << /Type /Catalog >> endobj\ntrailer << /Root 1 0 R >>\n%%EOF\n',
);

/// An SVG with a script, as an attacker would upload it.
final _svg = utf8.encode(
  '<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10">'
  '<script>alert(document.domain)</script>'
  '<rect width="10" height="10" fill="red"/></svg>',
);

/// An SVG with an XML declaration.
final _svgWithDeclaration = utf8.encode(
  '<?xml version="1.0" encoding="UTF-8"?>\n'
  '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10">'
  '<circle cx="5" cy="5" r="4"/></svg>',
);

/// An SVG with a doctype with an internal subset, as Adobe Illustrator
/// writes it; the app detects it the same way (#1244).
final _svgIllustrator = utf8.encode(
  '<?xml version="1.0" encoding="utf-8"?>\n'
  '<!-- Generator: Adobe Illustrator -->\n'
  '<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "svg11.dtd" [\n'
  '\t<!ENTITY ns_svg "http://www.w3.org/2000/svg">\n]>\n'
  '<svg xmlns="&ns_svg;"/>',
);

/// SVGs the server refuses, so the app refuses them too
/// (`attachmentTypeOf`, #1244): a change here changes the app.
final _refusedSvgs = <String, List<int>>{
  'bom.svg': [
    0xEF, 0xBB, 0xBF, //
    ...utf8.encode('<svg xmlns="http://www.w3.org/2000/svg"/>'),
  ],
  'upper.svg': utf8.encode('<SVG xmlns="http://www.w3.org/2000/svg"/>'),
  'no-namespace.svg': utf8.encode('<svg width="1"/>'),
  'comment-space.svg': utf8.encode(
    '<!-- hi -->\n<svg xmlns="http://www.w3.org/2000/svg"/>',
  ),
  'doctype.svg': utf8.encode(
    '<!DOCTYPE svg>\n<svg xmlns="http://www.w3.org/2000/svg"/>',
  ),
  'no-version.svg': utf8.encode(
    '<?xml encoding="utf-8"?>\n<svg xmlns="http://www.w3.org/2000/svg"/>',
  ),
};

void main() {
  late PocketBase pb;

  setUpAll(() async => pb = await PocketBase.start());
  tearDownAll(() => pb.stop());

  Future<Response> upload(
    Client client,
    String org,
    String song, {
    required List<int> bytes,
    required String filename,
    required String contentType,
  }) => client.postMultipart(
    'attachments',
    {
      'id': uuid(),
      'organization': org,
      'song': song,
      'name': filename,
      'size_bytes': '${bytes.length}',
    },
    fileField: 'file',
    bytes: bytes,
    filename: filename,
    contentType: contentType,
  );

  Future<int> attachmentCount(String song) async =>
      (await pb.superuser.list('attachments', filter: 'song = "$song"')).length;

  group('allowed types', () {
    final images = <String, (List<int>, String)>{
      'logo.png': (_png, 'image/png'),
      'photo.jpg': (_jpeg, 'image/jpeg'),
      'anim.gif': (_gif, 'image/gif'),
      'small.webp': (_webp, 'image/webp'),
      'plain.svg': (_svg, 'image/svg+xml'),
      'declared.svg': (_svgWithDeclaration, 'image/svg+xml'),
      'illustrator.svg': (_svgIllustrator, 'image/svg+xml'),
    };
    for (final MapEntry(key: name, value: (bytes, type)) in images.entries) {
      test('$name is accepted and its size counted', () async {
        final f = await BandFixture.create(pb);
        final song = await f.createSong(f.admin);
        final r = await upload(
          f.admin,
          f.orgId,
          song['id'],
          bytes: bytes,
          filename: name,
          contentType: type,
        );
        r.expectStatus(200);
        expect(r.json['size_bytes'], bytes.length);
        final storage = await f.admin.send(
          'GET',
          '/api/setding/organizations/${f.orgId}/storage',
        );
        expect(storage.json['used_bytes'], bytes.length);
      });
    }

    test('the type comes from the content, not from the name', () async {
      final f = await BandFixture.create(pb);
      final song = await f.createSong(f.admin);
      // A PNG named .svg is still a PNG, an allowed type.
      (await upload(
        f.admin,
        f.orgId,
        song['id'],
        bytes: _png,
        filename: 'logo.svg',
        contentType: 'image/svg+xml',
      )).expectStatus(200);
    });
  });

  group('refused types', () {
    final refused = <String, (List<int>, String)>{
      'notes.txt': (utf8.encode('just text'), 'text/plain'),
      'page.html': (
        utf8.encode('<!doctype html><html><script>alert(1)</script></html>'),
        'text/html',
      ),
      // Text that claims to be an image by name and declared type.
      'fake.png': (utf8.encode('not an image at all'), 'image/png'),
      'fake.svg': (
        utf8.encode('<html><body><script>alert(1)</script></body></html>'),
        'image/svg+xml',
      ),
      'icon.bmp': ([0x42, 0x4D, ...List<int>.filled(60, 0)], 'image/bmp'),
      for (final MapEntry(key: name, value: bytes) in _refusedSvgs.entries)
        name: (bytes, 'image/svg+xml'),
    };
    for (final MapEntry(key: name, value: (bytes, type)) in refused.entries) {
      test('$name is refused', () async {
        final f = await BandFixture.create(pb);
        final song = await f.createSong(f.admin);
        final r = await upload(
          f.admin,
          f.orgId,
          song['id'],
          bytes: bytes,
          filename: name,
          contentType: type,
        );
        expect(r.status, 400, reason: '$r');
        expect(r.field('data.file.code'), 'validation_invalid_mime_type');
        expect(await attachmentCount(song['id'] as String), 0);
      });
    }
  });

  test('images over 1 MB are refused (ADR-0070)', () async {
    final f = await BandFixture.create(pb);
    final song = await f.createSong(f.admin);
    final big = [..._png, ...List<int>.filled(_mb, 0)];
    final r = await upload(
      f.admin,
      f.orgId,
      song['id'],
      bytes: big,
      filename: 'big.png',
      contentType: 'image/png',
    );
    expect(r.status, 400);
    expect(r.field('data.file.code'), 'validation_file_size_limit');
  });

  test('roles without upload rights are refused for images', () async {
    final f = await BandFixture.create(pb);
    final planner = await f.addPlanner();
    final song = await f.createSong(f.admin);
    for (final user in [f.member, planner, f.outsider]) {
      final r = await upload(
        user,
        f.orgId,
        song['id'],
        bytes: _png,
        filename: 'logo.png',
        contentType: 'image/png',
      );
      expect(r.status, anyOf(400, 403, 404), reason: '$r');
    }
    expect(await attachmentCount(song['id'] as String), 0);

    // A band leader uploads for their own songs, like PDFs.
    final leader = await f.addLeader();
    final own = await f.createSong(leader);
    (await upload(
      leader,
      f.orgId,
      own['id'],
      bytes: _png,
      filename: 'logo.png',
      contentType: 'image/png',
    )).expectStatus(200);
  });

  test('images count toward the storage limit', () async {
    final limited = await PocketBase.start(
      environment: {'SETDING_ORG_STORAGE_LIMIT_MB': '1'},
    );
    addTearDown(limited.stop);
    final f = await BandFixture.create(limited);
    final song = await f.createSong(f.admin);
    final half = [..._pdf, ...List<int>.filled(600 * 1024, 32)];
    (await f.admin.postMultipart(
      'attachments',
      {
        'id': uuid(),
        'organization': f.orgId,
        'song': song['id'] as String,
        'name': 'Score',
      },
      fileField: 'file',
      bytes: half,
      filename: 'score.pdf',
      contentType: 'application/pdf',
    )).expectStatus(200);
    final image = [..._png, ...List<int>.filled(600 * 1024, 0)];
    final r = await upload(
      f.admin,
      f.orgId,
      song['id'],
      bytes: image,
      filename: 'big.png',
      contentType: 'image/png',
    );
    expect(r.status, 400, reason: '$r');
    expect(r.field('data.file.code'), 'storage_limit_reached');
  });

  group('serving an SVG', () {
    late BandFixture f;
    late String path;

    setUpAll(() async {
      f = await BandFixture.create(pb);
      final song = await f.createSong(f.admin);
      final r = await upload(
        f.admin,
        f.orgId,
        song['id'],
        bytes: _svg,
        filename: 'logo.svg',
        contentType: 'image/svg+xml',
      );
      r.expectStatus(200);
      path = '/api/files/attachments/${r.json['id']}/${r.json['file']}';
    });

    test('is protected: no file without a token of a member', () async {
      expect((await f.member.send('GET', path)).status, isNot(200));
      expect((await f.outsider.send('GET', path)).status, isNot(200));
      final outsider = await f.outsider.send('POST', '/api/files/token');
      final denied = await f.outsider.send(
        'GET',
        '$path?token=${outsider.json['token']}',
      );
      expect(denied.status, isNot(200));
    });

    test('is a download in a sandbox, never an inline document', () async {
      final token = await f.member.send('POST', '/api/files/token');
      for (final query in ['', '&download=1']) {
        final r = await f.member.send(
          'GET',
          '$path?token=${token.json['token']}$query',
        );
        r.expectStatus(200);
        expect(r.raw.bodyBytes, _svg);
        final headers = r.raw.headers;
        expect(headers['content-type'], startsWith('image/svg+xml'));
        expect(headers['content-disposition'], startsWith('attachment'));
        final csp = headers['content-security-policy'] ?? '';
        expect(csp, contains("default-src 'none'"));
        expect(csp, contains('sandbox'));
        expect(headers['x-content-type-options'], 'nosniff');
      }
    });
  });
}

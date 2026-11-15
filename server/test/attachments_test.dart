import 'dart:convert';

import 'package:test/test.dart';

import 'support/fixtures.dart';
import 'package:realchord_server/pocketbase_harness.dart';

final _pdf = utf8.encode(
  '%PDF-1.4\n1 0 obj << /Type /Catalog >> endobj\ntrailer << /Root 1 0 R >>\n%%EOF\n',
);

void main() {
  late PocketBase pb;

  setUpAll(() async => pb = await PocketBase.start());
  tearDownAll(() => pb.stop());

  Future<Response> upload(
    Client client,
    String band,
    String song, {
    List<int>? bytes,
    String contentType = 'application/pdf',
    String filename = 'score.pdf',
  }) => client.postMultipart(
    'attachments',
    {
      'id': uuid(),
      'band': band,
      'song': song,
      'name': 'Score',
      'pages': '1',
      'size_bytes': '${(bytes ?? _pdf).length}',
    },
    fileField: 'file',
    bytes: bytes ?? _pdf,
    filename: filename,
    contentType: contentType,
  );

  test('admins upload PDFs; members download them with a file token', () async {
    final f = await BandFixture.create(pb);
    final song = await f.createSong(f.admin);
    final created = await upload(f.admin, f.id, song['id']);
    created.expectStatus(200);
    final file = created.json['file'] as String;
    expect(file, endsWith('.pdf'));
    final path = '/api/files/attachments/${created.json['id']}/$file';

    // Protected file: no access without a token.
    expect((await f.member.send('GET', path)).status, isNot(200));

    final token = await f.member.send('POST', '/api/files/token');
    token.expectStatus(200);
    final download = await f.member.send(
      'GET',
      '$path?token=${token.json['token']}',
    );
    download.expectStatus(200);
    expect(download.raw.bodyBytes, _pdf);

    final outsiderToken = await f.outsider.send('POST', '/api/files/token');
    final denied = await f.outsider.send(
      'GET',
      '$path?token=${outsiderToken.json['token']}',
    );
    expect(denied.status, isNot(200));
  });

  test('only PDF files are accepted', () async {
    final f = await BandFixture.create(pb);
    final song = await f.createSong(f.admin);
    final r = await upload(
      f.admin,
      f.id,
      song['id'],
      bytes: utf8.encode('just text'),
      contentType: 'text/plain',
      filename: 'notes.txt',
    );
    expect(r.status, 400);
  });

  test('files larger than 20 MB are refused', () async {
    final f = await BandFixture.create(pb);
    final song = await f.createSong(f.admin);
    final big = [..._pdf, ...List<int>.filled(20 * 1024 * 1024, 32)];
    final r = await upload(f.admin, f.id, song['id'], bytes: big);
    expect(r.status, 400);
  });

  test('the song must belong to the same band', () async {
    final f = await BandFixture.create(pb);
    final other = await BandFixture.create(pb);
    final foreignSong = await other.createSong(other.admin);
    final r = await upload(f.admin, f.id, foreignSong['id']);
    expect(r.status, 400);
  });

  test('members upload only if the band allows song editing', () async {
    final strict = await BandFixture.create(pb);
    final s1 = await strict.createSong(strict.admin);
    expect((await upload(strict.member, strict.id, s1['id'])).status, 400);

    final relaxed = await BandFixture.create(pb, membersCanEditSongs: true);
    final s2 = await relaxed.createSong(relaxed.admin);
    (await upload(relaxed.member, relaxed.id, s2['id'])).expectStatus(200);
  });

  test('files are immutable; metadata can change', () async {
    final f = await BandFixture.create(pb);
    final song = await f.createSong(f.admin);
    final created = await upload(f.admin, f.id, song['id']);
    final id = created.json['id'] as String;

    final renamed = await f.admin.patch('attachments', id, {'name': 'Lead'});
    renamed.expectStatus(200);
    expect(renamed.json['file'], created.json['file']);

    final replaced = await f.admin.patchMultipart(
      'attachments',
      id,
      {},
      fileField: 'file',
      bytes: _pdf,
      filename: 'other.pdf',
      contentType: 'application/pdf',
    );
    expect(replaced.status, 400);
  });

  test('only admins delete attachments', () async {
    final f = await BandFixture.create(pb, membersCanEditSongs: true);
    final song = await f.createSong(f.admin);
    final created = await upload(f.admin, f.id, song['id']);
    final id = created.json['id'] as String;
    expect(
      (await f.member.patch('attachments', id, {'deleted': true})).status,
      404,
    );
    (await f.admin.patch('attachments', id, {
      'deleted': true,
    })).expectStatus(200);
  });
}

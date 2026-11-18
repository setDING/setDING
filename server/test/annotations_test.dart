import 'dart:convert';

import 'package:test/test.dart';

import 'support/fixtures.dart';

import 'package:setding_server/pocketbase_harness.dart';

final _pdf = utf8.encode(
  '%PDF-1.4\n1 0 obj << /Type /Catalog >> endobj\ntrailer << /Root 1 0 R >>\n%%EOF\n',
);

/// Personal freehand annotations (ADR-0032).
void main() {
  late PocketBase pb;

  setUpAll(() async => pb = await PocketBase.start());
  tearDownAll(() => pb.stop());

  Map<String, dynamic> stroke(String color) => {
    'tool': 'pen',
    'color': color,
    'pts': 'AAAA',
  };

  Map<String, dynamic> record(
    User user,
    String song, {
    String? attachment,
    Map<String, dynamic>? data,
  }) => {
    'id': uuid(),
    'user': user.id,
    'song': song,
    'attachment': ?attachment,
    'data': data ?? {'s1': stroke('red')},
  };

  Future<String> upload(BandFixture f, String song) async {
    final r = await f.admin.postMultipart(
      'attachments',
      {
        'id': uuid(),
        'organization': f.orgId,
        'song': song,
        'name': 'Score',
        'pages': '1',
        'size_bytes': '${_pdf.length}',
      },
      fileField: 'file',
      bytes: _pdf,
      filename: 'score.pdf',
      contentType: 'application/pdf',
    );
    r.expectStatus(200);
    return r.json['id'] as String;
  }

  test('annotations are private to their user', () async {
    final f = await BandFixture.create(pb);
    final song = (await f.createSong(f.admin))['id'] as String;
    final mine = await f.member.post('annotations', record(f.member, song));
    mine.expectStatus(200);
    expect(mine.json['revision'], greaterThan(0));
    expect(mine.json['updated_by'], f.member.id);

    expect(await f.member.list('annotations'), hasLength(1));
    // Not even organization admins see them.
    expect(await f.admin.list('annotations'), isEmpty);
    expect((await f.admin.view('annotations', mine.json['id'])).status, 404);
    // Not for someone else, not for songs outside the organizations.
    expect(
      (await f.admin.post('annotations', record(f.member, song))).status,
      400,
    );
    expect(
      (await f.outsider.post('annotations', record(f.outsider, song))).status,
      400,
    );
    // One record per user, song and target; never hard-deleted; the user,
    // the song and the attachment stay.
    expect(
      (await f.member.post('annotations', record(f.member, song))).status,
      400,
    );
    final other = (await f.createSong(f.admin, title: 'Other'))['id'];
    final id = mine.json['id'] as String;
    expect(
      (await f.member.patch('annotations', id, {'song': other})).status,
      404,
    );
    expect((await f.member.delete('annotations', id)).status, isNot(204));
  });

  test('an update merges the sent strokes by stroke ID', () async {
    final f = await BandFixture.create(pb);
    final song = (await f.createSong(f.admin))['id'] as String;
    final created = await f.member.post(
      'annotations',
      record(f.member, song, data: {'a': stroke('red'), 'b': stroke('blue')}),
    );
    created.expectStatus(200);
    final id = created.json['id'] as String;

    // Two devices: one adds a stroke, the other erases and recolours.
    (await f.member.patch('annotations', id, {
      'data': {'c': stroke('green')},
    })).expectStatus(200);
    final now = DateTime.now().millisecondsSinceEpoch;
    final second = await f.member.patch('annotations', id, {
      'data': {
        'a': {'deleted': true, 't': now},
        'b': stroke('black'),
      },
    });
    second.expectStatus(200);

    final data = second.json['data'] as Map<String, dynamic>;
    expect(data.keys, unorderedEquals(['a', 'b', 'c']));
    expect(data['a'], {'deleted': true, 't': now});
    expect((data['b'] as Map)['color'], 'black');
    expect((data['c'] as Map)['color'], 'green');
  });

  test('old tombstones are pruned on the next write', () async {
    final f = await BandFixture.create(pb);
    final song = (await f.createSong(f.admin))['id'] as String;
    final old = DateTime.now()
        .subtract(const Duration(days: 91))
        .millisecondsSinceEpoch;
    final recent = DateTime.now()
        .subtract(const Duration(days: 10))
        .millisecondsSinceEpoch;
    final created = await f.member.post(
      'annotations',
      record(
        f.member,
        song,
        data: {
          'old': {'deleted': true, 't': old},
          'recent': {'deleted': true, 't': recent},
        },
      ),
    );
    created.expectStatus(200);
    final updated = await f.member.patch('annotations', created.json['id'], {
      'data': {'new': stroke('red')},
    });
    updated.expectStatus(200);
    expect(
      (updated.json['data'] as Map).keys,
      unorderedEquals(['recent', 'new']),
    );
  });

  test('annotations of a PDF attachment of the song', () async {
    final f = await BandFixture.create(pb);
    final song = (await f.createSong(f.admin))['id'] as String;
    final other = (await f.createSong(f.admin, title: 'Other'))['id'] as String;
    final attachment = await upload(f, song);

    // The text and the PDF are separate records.
    (await f.member.post(
      'annotations',
      record(f.member, song),
    )).expectStatus(200);
    (await f.member.post(
      'annotations',
      record(f.member, song, attachment: attachment),
    )).expectStatus(200);
    // The attachment must belong to the song.
    expect(
      (await f.member.post(
        'annotations',
        record(f.member, other, attachment: attachment),
      )).status,
      400,
    );
    expect(await f.member.list('annotations'), hasLength(2));
  });

  test('deleting and restoring an attachment', () async {
    final f = await BandFixture.create(pb);
    final song = (await f.createSong(f.admin))['id'] as String;
    final attachment = await upload(f, song);
    final onPdf = await f.member.post(
      'annotations',
      record(f.member, song, attachment: attachment),
    );
    onPdf.expectStatus(200);
    final onText = await f.member.post('annotations', record(f.member, song));
    onText.expectStatus(200);

    final deleted = await f.admin.patch('attachments', attachment, {
      'deleted': true,
    });
    deleted.expectStatus(200);
    Future<Map<String, bool>> states() async => {
      for (final r in await f.member.list('annotations'))
        r['id'] as String: r['deleted'] as bool,
    };
    expect(await states(), {onPdf.json['id']: true, onText.json['id']: false});

    (await f.admin.patch('attachments', attachment, {
      'deleted': false,
    })).expectStatus(200);
    expect(await states(), {onPdf.json['id']: false, onText.json['id']: false});
  });

  test('deleting and restoring a song', () async {
    final f = await BandFixture.create(pb);
    final song = await f.createSong(f.admin);
    final mine = await f.member.post(
      'annotations',
      record(f.member, song['id'] as String),
    );
    mine.expectStatus(200);

    final deleted = await f.admin.patch('songs', song['id'], {
      'deleted': true,
      'revision': song['revision'],
    });
    deleted.expectStatus(200);
    final removed = (await f.member.list('annotations')).single;
    expect(removed['deleted'], isTrue);
    expect(removed['revision'], greaterThan(mine.json['revision'] as int));

    (await f.admin.patch('songs', song['id'], {
      'deleted': false,
      'revision': deleted.json['revision'],
    })).expectStatus(200);
    expect((await f.member.list('annotations')).single['deleted'], isFalse);
  });
}

// A change of a mistake report, contact, band arrangement, freehand
// annotations or personal settings the server refuses for good never
// blocks the outbox and is reported once, like the changes of songs, sets
// and adjustments (#1264). Before, a 400 (validation error) of an
// arrangement or the settings stopped every later sync at the same outbox
// entry, the other kinds dropped a refusal in silence, and reports,
// contacts and annotations dropped a server error (5xx) instead of sending
// it again. Shared records (reports already on the server, contacts,
// arrangements) are undone to the server's version; what the person wrote
// and the server never took (a new report, annotations, settings) stays on
// this device.

import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setding/data/annotation_repository.dart';
import 'package:setding/data/arrangement_repository.dart';
import 'package:setding/data/attachment_storage_io.dart';
import 'package:setding/data/band_copy.dart';
import 'package:setding/data/contact_repository.dart';
import 'package:setding/data/database.dart';
import 'package:setding/data/outbox.dart';
import 'package:setding/data/set_repository.dart';
import 'package:setding/data/song_repository.dart';
import 'package:setding/data/song_review.dart';
import 'package:setding/settings/user_settings_store.dart';
import 'package:setding/sync/band_service.dart';
import 'package:setding/sync/sync_backend.dart';
import 'package:setding/sync/sync_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_backend.dart';

const _ann = AuthUser(id: 'ann', email: 'ann@example.test', name: 'Ann');

/// The lasting refusals: no permission, and a validation error.
const _forbidden = BackendException(BackendErrorKind.notAllowed, null, 403);
const _invalid = BackendException(BackendErrorKind.server, {
  'data': {
    'data': {'code': 'validation_invalid'},
  },
}, 400);

/// An error that may go away by itself: sent again in the next sync.
const _unavailable = BackendException(BackendErrorKind.server, null, 503);

const _stroke = AnnotationStroke(
  id: 'x',
  tool: AnnotationTool.pen,
  width: 0.004,
  points: [0.1, 0.1, 0.2, 0.2],
);

void main() {
  late AppDatabase db;
  late Directory dir;
  late FakeSyncBackend server;
  late SyncEngine engine;
  late SongRepository songs;
  late SetRepository sets;
  late SongReviewRepository review;
  late ContactRepository contacts;
  late ArrangementRepository arrangements;
  late AnnotationRepository annotations;
  late UserSettingsStore settings;

  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(NativeDatabase.memory());
    dir = Directory.systemTemp.createTempSync('setding_refused_other');
    final storage = FileAttachmentStorage(dir);
    SharedPreferences.setMockInitialValues({'instrument': 'bass'});
    settings = await UserSettingsStore.open(
      db,
      await SharedPreferences.getInstance(),
    );
    server = FakeSyncBackend(user: _ann);
    server.addBand('b1', 'Rock', admin: _ann, organizationId: 'o1');
    final bands = BandService(db, server);
    await bands.refresh();
    engine = SyncEngine(
      db,
      server,
      bands,
      copies: BandCopyService(db, storage, userId: 'ann'),
      settings: settings,
    );
    songs = SongRepository(db, storage, libraryId: 'o1', userId: 'ann');
    sets = SetRepository(db, storage, bandId: 'b1');
    review = SongReviewRepository(db, storage, userId: 'ann', backend: server);
    contacts = ContactRepository(db);
    arrangements = ArrangementRepository(db);
    annotations = AnnotationRepository(db, userId: 'ann');
  });
  tearDown(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });

  Future<List<OutboxEntry>> outbox() => db.select(db.syncOutbox).get();
  Future<SongReportRow?> reportRow(String id) => (db.select(
    db.songReports,
  )..where((r) => r.id.equals(id))).getSingleOrNull();
  Future<ContactEntry?> contact(String id) =>
      (db.select(db.contacts)..where((c) => c.id.equals(id))).getSingleOrNull();
  Future<List<AnnotationRow>> strokes() => db.select(db.annotations).get();

  /// Asserts that [report] lists exactly [change], and that the next sync
  /// neither sends nor reports it again.
  Future<void> reportedOnce(SyncReport report, RefusedChange change) async {
    expect(report.error, isNull, reason: 'the sync goes on');
    expect(report.undoneChanges, [change]);
    expect(await outbox(), isEmpty, reason: 'not sent again');
    expect(
      await db.select(db.changeLog).get(),
      isEmpty,
      reason: 'not a change of someone else',
    );
    final pushes = server.pushCount;
    final again = await engine.sync();
    expect(again.error, isNull);
    expect(again.undoneChanges, isEmpty, reason: 'told once');
    expect(server.pushCount, pushes);
  }

  Future<String> syncedSong() async {
    final id = await songs.createSong(source: '{title: Song}\n[C]x');
    await engine.sync();
    expect(server.songs[id], isNotNull);
    return id;
  }

  group('a refused band arrangement (#1264)', () {
    test('a 400 no longer stops every later sync', () async {
      final id = await syncedSong();
      await arrangements.save('b1', id, transpose: 2);
      server.arrangementPushError = _invalid;

      final report = await engine.sync();
      expect(report.error, isNull, reason: 'before: BackendErrorKind.server');
      expect(await outbox(), isEmpty, reason: 'before: stuck in the outbox');
    });

    for (final (label, refusal) in [('403', _forbidden), ('400', _invalid)]) {
      test('a refused change is undone and reported once ($label)', () async {
        final id = await syncedSong();
        await arrangements.save('b1', id, transpose: 2);
        await engine.sync();
        await arrangements.save('b1', id, transpose: 5, tempo: 90);
        server.arrangementPushError = refusal;

        final report = await engine.sync();
        final a = (await arrangements.get('b1', id))!;
        expect(a.transpose, 2, reason: "the server's version");
        expect(a.tempo, isNull);
        await reportedOnce(report, (
          kind: RefusedRecord.arrangement,
          id: arrangementRecordId('b1', id),
          name: 'Song',
          songTitle: 'Song',
        ));
      });
    }

    test('a new arrangement the server refuses is removed', () async {
      final id = await syncedSong();
      await arrangements.save('b1', id, transpose: 2);
      server.arrangementPushError = _forbidden;

      final report = await engine.sync();
      expect(await arrangements.get('b1', id), isNull);
      await reportedOnce(report, (
        kind: RefusedRecord.arrangement,
        id: arrangementRecordId('b1', id),
        name: 'Song',
        songTitle: 'Song',
      ));
    });

    test('a server error is sent again in the next sync', () async {
      final id = await syncedSong();
      await arrangements.save('b1', id, transpose: 2);
      server.arrangementPushError = _unavailable;
      final report = await engine.sync();
      expect(report.undoneChanges, isEmpty);
      expect(await outbox(), hasLength(1));

      server.arrangementPushError = null;
      await engine.sync();
      expect(server.arrangements.values.single.transpose, 2);
      expect(await outbox(), isEmpty);
    });
  });

  group('refused personal settings (#1264)', () {
    test('a 400 no longer stops every later sync', () async {
      await engine.sync();
      await settings.change('ann', {'instrument': 'drums'});
      server.settingsPushError = _invalid;

      final report = await engine.sync();
      expect(report.error, isNull, reason: 'before: BackendErrorKind.server');
      expect(await outbox(), isEmpty, reason: 'before: stuck in the outbox');
    });

    for (final (label, refusal) in [('403', _forbidden), ('400', _invalid)]) {
      test('stay on this device and are reported once ($label)', () async {
        await engine.sync();
        await settings.change('ann', {'instrument': 'drums'});
        server.settingsPushError = refusal;

        final report = await engine.sync();
        expect(settings.data('ann')['instrument'], 'drums');
        expect(server.userSettings['ann']!.data['instrument'], 'bass');
        expect(
          settings.get('ann')!.dirty,
          isEmpty,
          reason: 'not sent again with the next change',
        );
        await reportedOnce(report, (
          kind: RefusedRecord.keptSettings,
          id: 'ann',
          name: '',
          songTitle: null,
        ));

        // A later change is synced as usual.
        server.settingsPushError = null;
        await settings.change('ann', {'theme': 'dark'});
        await engine.sync();
        expect(server.userSettings['ann']!.data['theme'], 'dark');
        expect(server.userSettings['ann']!.data['instrument'], 'bass');
      });
    }

    test('a server error is sent again in the next sync', () async {
      await engine.sync();
      await settings.change('ann', {'instrument': 'drums'});
      server.settingsPushError = _unavailable;
      final report = await engine.sync();
      expect(report.undoneChanges, isEmpty);
      expect(await outbox(), hasLength(1));

      server.settingsPushError = null;
      await engine.sync();
      expect(server.userSettings['ann']!.data['instrument'], 'drums');
      expect(await outbox(), isEmpty);
    });
  });

  group('refused annotations (#1264)', () {
    for (final (label, refusal) in [('403', _forbidden), ('400', _invalid)]) {
      test('stay on this device and are reported once ($label)', () async {
        final id = await syncedSong();
        await annotations.apply(id, put: [_stroke]);
        server.annotationPushError = refusal;

        final report = await engine.sync();
        final kept = await strokes();
        expect(kept.single.id, 'x', reason: 'the drawing stays');
        expect(kept.single.pending, 0, reason: 'not sent again');
        expect(server.annotations, isEmpty);
        await reportedOnce(report, (
          kind: RefusedRecord.keptAnnotations,
          id: annotationRecordId('ann', id, ''),
          name: 'Song',
          songTitle: 'Song',
        ));
      });
    }

    test('an erased stroke the server refused stays erased here', () async {
      final id = await syncedSong();
      await annotations.apply(id, put: [_stroke]);
      await engine.sync();
      await annotations.apply(id, remove: ['x']);
      server.annotationPushError = _forbidden;

      final report = await engine.sync();
      expect(await strokes(), isEmpty);
      expect(report.undoneChanges.single.kind, RefusedRecord.keptAnnotations);
      expect(await outbox(), isEmpty);
    });

    test('a server error is sent again in the next sync', () async {
      final id = await syncedSong();
      await annotations.apply(id, put: [_stroke]);
      server.annotationPushError = _unavailable;
      final report = await engine.sync();
      expect(report.undoneChanges, isEmpty);
      expect((await strokes()).single.pending, greaterThan(0));
      expect(await outbox(), hasLength(1), reason: 'before: dropped');

      server.annotationPushError = null;
      await engine.sync();
      expect(server.annotations.values.single.data.keys, ['x']);
      expect(await outbox(), isEmpty);
    });
  });

  group('a refused contact (#1264)', () {
    Future<String> syncedContact() async {
      final id = await contacts.createContact('o1', firstName: 'Eve');
      await engine.sync();
      expect(server.contacts[id], isNotNull);
      return id;
    }

    for (final (label, refusal) in [('403', _forbidden), ('400', _invalid)]) {
      test('a refused change is undone and reported once ($label)', () async {
        final id = await syncedContact();
        await contacts.updateContact(id, firstName: 'Eva', lastName: 'Muster');
        server.contactPushError = refusal;

        final report = await engine.sync();
        expect((await contact(id))!.firstName, 'Eve');
        expect((await contact(id))!.lastName, '');
        await reportedOnce(report, (
          kind: RefusedRecord.contact,
          id: id,
          name: 'Eva Muster',
          songTitle: null,
        ));
      });
    }

    test('a new contact the server refuses is removed', () async {
      final id = await contacts.createContact('o1', firstName: 'Eve');
      final setId = await sets.createSet(name: 'Gig');
      server.contactPushError = _invalid;

      final report = await engine.sync();
      expect(await contact(id), isNull);
      expect(server.sets[setId], isNotNull, reason: 'pushed after it');
      await reportedOnce(report, (
        kind: RefusedRecord.contact,
        id: id,
        name: 'Eve',
        songTitle: null,
      ));
    });

    test('a server error is sent again in the next sync', () async {
      final id = await syncedContact();
      await contacts.updateContact(id, firstName: 'Eva');
      server.contactPushError = _unavailable;
      final report = await engine.sync();
      expect(report.undoneChanges, isEmpty);
      expect((await contact(id))!.firstName, 'Eva', reason: 'before: undone');
      expect(await outbox(), hasLength(1));

      server.contactPushError = null;
      await engine.sync();
      expect(server.contacts[id]!.firstName, 'Eva');
      expect(await outbox(), isEmpty);
    });
  });

  group('a refused mistake report (#1264)', () {
    Future<String> syncedReport(String songId) async {
      final id = await review.report(
        songId,
        category: SongReportCategory.chords,
        comment: 'Wrong chord',
      );
      await engine.sync();
      expect(server.reports[id], isNotNull);
      return id;
    }

    for (final (label, refusal) in [('403', _forbidden), ('400', _invalid)]) {
      test('a refused change is undone and reported once ($label)', () async {
        final id = await syncedSong();
        final r = await syncedReport(id);
        await review.updateReport(r, comment: 'Mine');
        server.reportPushError = refusal;

        final report = await engine.sync();
        expect((await reportRow(r))!.comment, 'Wrong chord');
        await reportedOnce(report, (
          kind: RefusedRecord.report,
          id: r,
          name: 'Song',
          songTitle: 'Song',
        ));
      });
    }

    test('a report the server no longer shows is removed (404)', () async {
      final id = await syncedSong();
      final r = await syncedReport(id);
      await review.updateReport(r, comment: 'Mine');
      server.reports.remove(r); // out of reach: 404 on the update

      final report = await engine.sync();
      expect(await reportRow(r), isNull);
      await reportedOnce(report, (
        kind: RefusedRecord.report,
        id: r,
        name: 'Song',
        songTitle: 'Song',
      ));
    });

    for (final (label, refusal) in [('403', _forbidden), ('400', _invalid)]) {
      test(
        'a refused new report stays on this device, told once ($label)',
        () async {
          final id = await syncedSong();
          final r = await review.report(
            id,
            category: SongReportCategory.chords,
            comment: 'Wrong chord',
          );
          server.reportPushError = refusal;

          final report = await engine.sync();
          expect(report.error, isNull);
          expect((await reportRow(r))!.comment, 'Wrong chord', reason: 'kept');
          expect(server.reports[r], isNull);
          expect(report.undoneChanges, [
            (
              kind: RefusedRecord.keptReport,
              id: r,
              name: 'Song',
              songTitle: 'Song',
            ),
          ]);
          // Sent again with every sync, as a report not on the server, but
          // told once.
          final again = await engine.sync();
          expect(again.error, isNull);
          expect(again.undoneChanges, isEmpty);

          server.reportPushError = null;
          await engine.sync();
          expect(server.reports[r]!.comment, 'Wrong chord');
        },
      );
    }

    test('a server error is sent again in the next sync', () async {
      final id = await syncedSong();
      final r = await syncedReport(id);
      await review.updateReport(r, comment: 'Mine');
      server.reportPushError = _unavailable;
      final report = await engine.sync();
      expect(report.undoneChanges, isEmpty);
      expect((await reportRow(r))!.comment, 'Mine', reason: 'before: undone');
      expect(await outbox(), hasLength(1), reason: 'before: dropped');

      server.reportPushError = null;
      await engine.sync();
      expect(server.reports[r]!.comment, 'Mine');
      expect(await outbox(), isEmpty);
    });
  });
}

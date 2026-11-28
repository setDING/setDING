import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/data/database.dart';
import 'package:setding/data/set_repository.dart';
import 'package:setding/l10n/generated/app_localizations.dart';
import 'package:setding/sync/sync_engine.dart'
    show RefusedChange, RefusedRecord;
import 'package:setding/ui/songs/refused_uploads.dart';
import 'package:setding/sync/sync_backend.dart';
import 'package:setding/ui/songs/song_screen.dart';

import 'sync_ui_test.dart' show syncNow;
import 'test_app.dart';

const _ann = AuthUser(id: 'ann', email: 'ann@example.test', name: 'Ann');

/// An attachment the server refused stays on this device, marked, and the
/// person is told once (#1225).
void main() {
  final pdf = Uint8List.fromList('%PDF-1.4 test'.codeUnits);

  testWidgets('a refused upload is told once', (tester) async {
    final app = await TestApp.create(
      prefs: {'language': 'en', 'currentBandId': 'b1'},
      user: _ann,
    );
    app.backend.addBand('b1', 'Rock', admin: _ann, organizationId: 'o1');
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    await syncNow(tester);
    await tester.pumpAndSettle();
    final songs = TestApp.songsIn(app, 'o1', userId: 'ann');
    final id = await songs.createSong(source: '{title: Song}');
    await tester.runAsync(
      () => songs.addAttachment(id, name: 'Score', bytes: pdf),
    );
    app.backend.attachmentUploadError = const BackendException(
      BackendErrorKind.notAllowed,
    );
    await syncNow(tester);
    await tester.pump();
    expect(
      find.text(
        'The server did not accept “Score” of “Song” (no permission to '
        'upload). The attachment stays on this device only.',
      ),
      findsOneWidget,
    );

    // Not again at the next sync.
    await tester.pump(const Duration(seconds: 11));
    await tester.pumpAndSettle();
    await syncNow(tester);
    await tester.pump();
    expect(find.byKey(const Key('attachment-upload-refused')), findsNothing);
    expect(app.backend.attachmentUploads, 1);
    await app.dispose(tester);
  });

  // A refused rename or deletion stayed local silently (#1229): it is
  // undone and the person is told once.
  testWidgets('a refused rename is undone and told once', (tester) async {
    final app = await TestApp.create(
      prefs: {'language': 'en', 'currentBandId': 'b1'},
      user: _ann,
    );
    app.backend.addBand('b1', 'Rock', admin: _ann, organizationId: 'o1');
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    await syncNow(tester);
    await tester.pumpAndSettle();
    final songs = TestApp.songsIn(app, 'o1', userId: 'ann');
    final id = await songs.createSong(source: '{title: Song}');
    final a = (await tester.runAsync(
      () => songs.addAttachment(id, name: 'Score', bytes: pdf),
    ))!;
    await syncNow(tester);
    await tester.pump(const Duration(seconds: 11));
    await tester.pumpAndSettle();
    expect(app.backend.attachments[a], isNotNull);

    await tester.runAsync(() => songs.renameAttachment(a, 'Horns'));
    app.backend.attachmentUpdateError = const BackendException(
      BackendErrorKind.notAllowed,
    );
    await syncNow(tester);
    await tester.pump();
    expect(
      find.text(
        'The server did not accept the change to “Horns” of “Song”. It was '
        'undone on this device.',
      ),
      findsOneWidget,
    );

    // Not again at the next sync.
    await tester.pump(const Duration(seconds: 11));
    await tester.pumpAndSettle();
    await syncNow(tester);
    await tester.pump();
    expect(find.byKey(const Key('attachment-change-undone')), findsNothing);
    await app.dispose(tester);
  });

  // A refused change of a set stayed local silently, and a 400 stopped
  // every later sync (#1260): it is undone and the person is told once.
  testWidgets('a refused set change is undone and told once', (tester) async {
    final app = await TestApp.create(
      prefs: {'language': 'en', 'currentBandId': 'b1'},
      user: _ann,
    );
    app.backend.addBand('b1', 'Rock', admin: _ann, organizationId: 'o1');
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    final sets = SetRepository(app.db, app.storage, bandId: 'b1');
    final id = (await tester.runAsync(() => sets.createSet(name: 'Gig')))!;
    await syncNow(tester);
    await tester.pump(const Duration(seconds: 11));
    await tester.pumpAndSettle();
    expect(app.backend.sets[id], isNotNull);

    await tester.runAsync(() => sets.updateSet(id, name: 'Mine'));
    app.backend.setPushError = const BackendException(
      BackendErrorKind.server,
      null,
      400,
    );
    await syncNow(tester);
    await tester.pump();
    expect(
      find.text(
        'The server did not accept the change to the set “Mine”. It was '
        'undone on this device.',
      ),
      findsOneWidget,
    );

    // Not again at the next sync.
    await tester.pump(const Duration(seconds: 11));
    await tester.pumpAndSettle();
    await syncNow(tester);
    await tester.pump();
    expect(find.byKey(const Key('attachment-change-undone')), findsNothing);
    await app.dispose(tester);
  });

  test('several undone changes of different kinds are told together', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    RefusedChange change(RefusedRecord kind) =>
        (kind: kind, id: kind.name, name: 'X', songTitle: 'Song');
    expect(
      undoneChangesText(l10n, [
        change(RefusedRecord.attachment),
        change(RefusedRecord.attachment),
      ]),
      l10n.attachmentChangesUndone(2),
    );
    expect(
      undoneChangesText(l10n, [
        change(RefusedRecord.song),
        change(RefusedRecord.adjustment),
      ]),
      'The server did not accept 2 changes. They were undone on this device.',
    );
    expect(
      undoneChangesText(l10n, [change(RefusedRecord.adjustment)]),
      'The server did not accept your personal adjustments to “X”. They '
      'were undone on this device.',
    );
  });

  testWidgets('the marker shows why; the menu retries and removes', (
    tester,
  ) async {
    final app = await TestApp.create(prefs: {'language': 'en'});
    final (song, refused, other) = (await tester.runAsync(() async {
      final id = await app.songs.createSong(source: '{title: X}\n[G]One');
      final refused = await app.songs.addAttachment(
        id,
        name: 'Horns',
        bytes: pdf,
      );
      final other = await app.songs.addAttachment(
        id,
        name: 'Piano',
        bytes: pdf,
      );
      await (app.db.update(
        app.db.attachments,
      )..where((a) => a.id.equals(refused))).write(
        const AttachmentsCompanion(
          uploadRefused: Value(UploadRefusal.tooLarge),
        ),
      );
      return (id, refused, other);
    }))!;
    await tester.pumpWidget(app.build(home: SongScreen(songId: song)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-attachments')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining(
        'Only on this device: the file is too large for the server',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('attachment-only-here')), findsOneWidget);

    // Only the refused one can be uploaded again.
    await tester.tap(find.byKey(ValueKey('attachment-menu-$other')));
    await tester.pumpAndSettle();
    expect(find.text('Upload again'), findsNothing);
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(ValueKey('attachment-menu-$refused')));
    await tester.pumpAndSettle();
    expect(find.text('Delete'), findsOneWidget);
    await tester.tap(find.text('Upload again'));
    await tester.pumpAndSettle();
    final row = (await tester.runAsync(
      () => (app.db.select(
        app.db.attachments,
      )..where((a) => a.id.equals(refused))).getSingle(),
    ))!;
    expect(row.uploadRefused, isNull);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('attachment-only-here')), findsNothing);
    await app.dispose(tester);
  });
}

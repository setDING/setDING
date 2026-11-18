import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setding/data/annotation_repository.dart';
import 'package:setding/data/attachment_storage_io.dart';
import 'package:setding/data/database.dart';
import 'package:setding/data/song_repository.dart';
import 'package:setding/ui/annotations/annotation_editor.dart';

/// The size limit of a song's annotations (ADR-0032): the client refuses
/// new strokes beyond what the server keeps.
void main() {
  late AppDatabase db;
  late AnnotationRepository repo;

  late String id;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = AnnotationRepository(db);
    final dir = await Directory.systemTemp.createTemp('annotation_size');
    addTearDown(() => dir.delete(recursive: true));
    id = await SongRepository(
      db,
      FileAttachmentStorage(dir),
    ).createSong(source: '{title: Big}');
  });
  tearDown(() => db.close());

  /// A stroke of roughly 270 kB.
  AnnotationStroke big(String id) => AnnotationStroke(
    id: id,
    tool: AnnotationTool.pen,
    width: 0.004,
    points: [for (var i = 0; i < 50000; i++) (i % 9973) / 10000],
  );

  test(
    'the size grows with the strokes; beyond the limit is refused',
    () async {
      expect(await repo.watchSize(id).first, 0);
      await repo.apply(id, put: [big('a'), big('b'), big('c')]);
      final three = await repo.watchSize(id).first;
      expect(three, greaterThan(annotationWarnShare * annotationMaxBytes));
      expect(three, lessThan(annotationMaxBytes));

      // A fourth would not fit: nothing of the change is stored.
      await expectLater(
        repo.apply(id, put: [big('d'), big('e')]),
        throwsA(isA<AnnotationsFullException>()),
      );
      expect((await repo.watch(id).first).map((s) => s.id), ['a', 'b', 'c']);

      // Another target has its own limit; erasing always works.
      await repo.apply(id, target: 'pdf', put: [big('d')]);
      await repo.apply(id, remove: ['a']);
      // Room again for one, also in a change that erases another.
      await repo.apply(id, put: [big('e')], remove: ['b']);
      expect(await repo.watchSize(id).first, lessThan(annotationMaxBytes));
    },
  );

  test('the editor drops a refused change and says it is full', () async {
    final editor = AnnotationEditor(repo)..active = true;
    addTearDown(editor.dispose);
    await editor.commit(id, '', after: [big('a'), big('b'), big('c')]);
    await editor.commit(id, '', after: [big('d')]);
    expect(editor.full, isTrue);
    expect(await repo.watch(id).first, hasLength(3));

    // Undo takes back the last stored change, not the refused one.
    await editor.undo();
    expect(await repo.watch(id).first, isEmpty);
    expect(editor.full, isFalse);
    expect(editor.canUndo, isFalse);
  });
}

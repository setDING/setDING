import 'dart:typed_data';

import 'package:setding/data/attachment_storage.dart';
import 'package:setding/data/database.dart';

/// Stores a PDF of [size] bytes as an attachment of [songId] directly, as
/// one from before the 1 MB limit (ADR-0070).
Future<void> addOldPdf(
  AppDatabase db,
  AttachmentStorage storage,
  String songId, {
  required String name,
  int size = 2 * 1024 * 1024,
}) async {
  final bytes = Uint8List(size)..setAll(0, '%PDF-1.4'.codeUnits);
  final file = '$name.pdf';
  await storage.write(file, bytes);
  await db
      .into(db.attachments)
      .insert(
        AttachmentsCompanion.insert(
          id: 'old-$name',
          songId: songId,
          name: name,
          fileName: file,
          sizeBytes: size,
          updatedAt: DateTime.now(),
        ),
      );
}

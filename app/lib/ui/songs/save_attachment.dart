import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

import '../../data/attachment_storage.dart';
import '../../data/backup.dart' show BackupFileMissingException;
import '../../data/database.dart';
import '../../data/import_export.dart' show safeFileName;
import '../../data/storage_providers.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../platform/web_client.dart';
import '../../sync/sync_controller.dart';
import '../widgets/export_file.dart';

/// The name an attachment is saved under: its name with the extension of
/// its stored file ("Horns" → "Horns.pdf", "Horns.pdf" stays).
String attachmentSaveName(AttachmentEntry a) {
  final ext = p.extension(a.fileName);
  var base = a.name.trim();
  if (p.extension(base).toLowerCase() == ext.toLowerCase()) {
    base = p.basenameWithoutExtension(base);
  }
  return '${safeFileName(base)}$ext';
}

/// The media type of an attachment file.
String attachmentMimeType(String fileName) =>
    switch (p.extension(fileName).toLowerCase()) {
      '.pdf' => 'application/pdf',
      '.png' => 'image/png',
      '.jpg' || '.jpeg' => 'image/jpeg',
      '.gif' => 'image/gif',
      '.webp' => 'image/webp',
      '.svg' => 'image/svg+xml',
      _ => 'application/octet-stream',
    };

/// Saves attachment [a] of song [songTitle] as a file through the
/// platform's save dialog (a download on web, #1025). The web client loads
/// the file first (ADR-0018); a file that is not on the device is reported.
Future<bool> saveAttachment(
  BuildContext context,
  WidgetRef ref,
  AttachmentEntry a, {
  required String songTitle,
}) {
  final web = ref.read(webClientProvider);
  final storage = ref.read(attachmentStorageProvider);
  final fetcher = ref.read(attachmentFetcherProvider);
  return exportFile(
    context,
    ref,
    fileName: attachmentSaveName(a),
    mimeType: attachmentMimeType(a.fileName),
    openable: true,
    doneMessage: AppLocalizations.of(context).fileSaved,
    build: () async {
      final StoredFile? file = web
          ? await fetcher.fetch(a.id)
          : storage.file(a.fileName);
      if (file == null || !await file.exists()) {
        throw BackupFileMissingException(songTitle, a.name);
      }
      return file.readAsBytes();
    },
  );
}

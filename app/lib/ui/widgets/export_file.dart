import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/backup.dart' show BackupFileMissingException;
import '../../l10n/generated/app_localizations.dart';
import '../../platform/open_file.dart';
import 'dialogs.dart';
import 'file_actions.dart';

/// Saves a file; tests replace it.
typedef SaveFile = Future<bool> Function(
  String fileName,
  Uint8List bytes, {
  String mimeType,
});

/// How an export is saved: the platform's save dialog (a download on web).
final saveFileProvider = Provider<SaveFile>((ref) => saveFile);

/// Opens a file in the system's default app; tests replace it.
typedef OpenFile = Future<bool> Function(
  String fileName,
  Uint8List bytes, {
  required String mimeType,
});

/// How an exported PDF is opened (#721, ADR-0048).
final openFileProvider = Provider<OpenFile>((ref) => openFileInDefaultApp);

/// Exports a file: builds its content with [build], saves it as [fileName]
/// through [saveFileProvider] and says "Exported". With [openable], the
/// message offers "Open" (#721, ADR-0048); [doneMessage] replaces
/// "Exported". A failure is shown as a message. Returns whether the file
/// was saved.
Future<bool> exportFile(
  BuildContext context,
  WidgetRef ref, {
  required String fileName,
  required String mimeType,
  required Future<Uint8List> Function() build,
  bool openable = false,
  String? doneMessage,
}) async {
  final l10n = AppLocalizations.of(context);
  final done = doneMessage ?? l10n.exported;
  final save = ref.read(saveFileProvider);
  final open = ref.read(openFileProvider);
  try {
    final bytes = await build();
    final saved = await save(fileName, bytes, mimeType: mimeType);
    if (!saved || !context.mounted) return saved;
    if (!openable) {
      showMessage(context, done);
      return true;
    }
    // Taken now: the message may outlive the screen that exported.
    final messenger = ScaffoldMessenger.of(context);
    showMessageWithAction(
      context,
      done,
      actionLabel: l10n.exportedOpen,
      onAction: () async {
        final opened = await open(fileName, bytes, mimeType: mimeType);
        if (!opened) {
          showMessageOn(messenger, l10n.openFileFailed);
        }
      },
    );
    return true;
  } on BackupFileMissingException catch (e) {
    if (context.mounted) {
      showMessage(context, l10n.backupFileMissing(e.name, e.songTitle));
    }
  } catch (e) {
    if (context.mounted) showMessage(context, l10n.errorGeneric('$e'));
  }
  return false;
}

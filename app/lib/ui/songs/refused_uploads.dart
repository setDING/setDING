import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/database.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../sync/sync_controller.dart';
import '../../sync/sync_engine.dart'
    show RefusedChange, RefusedRecord, RefusedUpload;
import '../theme.dart';
import '../widgets/dialogs.dart';

/// Why the server refused an attachment upload (#1225), as the end of a
/// sentence.
String uploadRefusalText(AppLocalizations l10n, UploadRefusal reason) =>
    switch (reason) {
      UploadRefusal.notAllowed => l10n.uploadRefusalNotAllowed,
      UploadRefusal.tooLarge => l10n.uploadRefusalTooLarge,
      UploadRefusal.refused => l10n.uploadRefusalOther,
      UploadRefusal.storageFull => l10n.uploadRefusalStorageFull,
    };

/// The marker of an attachment the server refused (#1225): it is only on
/// this device, with the reason. Retry and remove are in its menu.
class RefusedUploadMarker extends StatelessWidget {
  const RefusedUploadMarker(this.reason, {super.key});

  final UploadRefusal reason;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final color = StatusColors.of(context).warning;
    // The icon is part of the text, so a narrow panel wraps it as one.
    return Text.rich(
      key: const Key('attachment-only-here'),
      TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(end: 4),
              child: Icon(Icons.cloud_off_outlined, size: 16, color: color),
            ),
          ),
          TextSpan(
            text: l10n.attachmentOnlyHere(uploadRefusalText(l10n, reason)),
          ),
        ],
      ),
      style: TextStyle(color: color),
    );
  }
}

/// The message about the changes the server refused and the sync undone
/// (#1229, #1260).
String undoneChangesText(AppLocalizations l10n, List<RefusedChange> undone) =>
    switch (undone) {
      [final c] => switch (c.kind) {
        RefusedRecord.attachment => l10n.attachmentChangeUndone(
          c.name,
          c.songTitle ?? '',
        ),
        RefusedRecord.song => l10n.songChangeUndone(c.name),
        RefusedRecord.set => l10n.setChangeUndone(c.name),
        RefusedRecord.adjustment => l10n.adjustmentChangeUndone(c.name),
      },
      _ when undone.every((c) => c.kind == RefusedRecord.attachment) =>
        l10n.attachmentChangesUndone(undone.length),
      _ => l10n.syncChangesUndone(undone.length),
    };

/// After a sync: tells the person once which attachments the server
/// refused (#1225) and which changes it refused and were undone: of
/// attachments (#1229), songs, sets and personal adjustments (#1260). The
/// sync does not send them again by itself, so each refusal is told once.
/// Call from the home screen's `build`.
void listenForRefusedUploads(BuildContext context, WidgetRef ref) {
  ref.listen(syncControllerProvider.select((s) => s.lastReport), (_, report) {
    final refused = report?.refusedUploads ?? const <RefusedUpload>[];
    final undone = report?.undoneChanges ?? const <RefusedChange>[];
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (refused.isNotEmpty) {
      showMessageOn(
        messenger,
        switch (refused) {
          [final r] => l10n.attachmentUploadRefused(
            r.name,
            r.songTitle,
            uploadRefusalText(l10n, r.reason),
          ),
          _ => l10n.attachmentUploadsRefused(refused.length),
        },
        key: const Key('attachment-upload-refused'),
        duration: const Duration(seconds: 10),
      );
    }
    if (undone.isNotEmpty) {
      showMessageOn(
        messenger,
        undoneChangesText(l10n, undone),
        key: const Key('attachment-change-undone'),
        duration: const Duration(seconds: 10),
        // After the message about refused uploads of the same sync.
        queue: refused.isNotEmpty,
      );
    }
  });
}

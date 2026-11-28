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
/// (#1229, #1260, #1264), and the ones it refused that stay on this device:
/// new songs kept in the local library (#1263), new mistake reports,
/// annotations and personal settings (#1264).
String undoneChangesText(AppLocalizations l10n, List<RefusedChange> undone) {
  final kept = [
    for (final c in undone)
      if (c.kind.kept) c,
  ];
  final others = [
    for (final c in undone)
      if (!c.kind.kept) c,
  ];
  return [
    if (kept.isNotEmpty) _keptText(l10n, kept),
    if (others.isNotEmpty) _undoneText(l10n, others),
  ].join(' ');
}

String _keptText(AppLocalizations l10n, List<RefusedChange> kept) =>
    switch (kept) {
      [final c] => switch (c.kind) {
        RefusedRecord.keptReport => l10n.reportKeptOnDevice(c.name),
        RefusedRecord.keptAnnotations => l10n.annotationsKeptOnDevice(c.name),
        RefusedRecord.keptSettings => l10n.settingsKeptOnDevice,
        _ => l10n.songKeptOnDevice(c.name),
      },
      _ when kept.every((c) => c.kind == RefusedRecord.keptSong) =>
        l10n.songsKeptOnDevice(kept.length),
      _ => l10n.syncChangesKeptOnDevice(kept.length),
    };

String _undoneText(AppLocalizations l10n, List<RefusedChange> undone) =>
    switch (undone) {
      [final c] => switch (c.kind) {
        RefusedRecord.attachment => l10n.attachmentChangeUndone(
          c.name,
          c.songTitle ?? '',
        ),
        RefusedRecord.set => l10n.setChangeUndone(c.name),
        RefusedRecord.adjustment => l10n.adjustmentChangeUndone(c.name),
        RefusedRecord.report => l10n.reportChangeUndone(c.name),
        RefusedRecord.contact => l10n.contactChangeUndone(c.name),
        RefusedRecord.arrangement => l10n.arrangementChangeUndone(c.name),
        _ => l10n.songChangeUndone(c.name),
      },
      _ when undone.every((c) => c.kind == RefusedRecord.attachment) =>
        l10n.attachmentChangesUndone(undone.length),
      _ => l10n.syncChangesUndone(undone.length),
    };

/// After a sync: tells the person once which attachments the server
/// refused (#1225) and which changes it refused and were undone: of
/// attachments (#1229), songs, sets and personal adjustments (#1260),
/// mistake reports, contacts and band arrangements (#1264), and which
/// new songs it refused and were kept on this device (#1263), as are new
/// mistake reports, annotations and personal settings (#1264). The
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

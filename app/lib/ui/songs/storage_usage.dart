import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/attachment_storage.dart';
import '../../data/band_providers.dart';
import '../../data/org_storage_providers.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../sync/sync_backend.dart' show OrgStorage;
import '../routes.dart';
import '../theme.dart';
import '../widgets/dialogs.dart';

/// A size limit for display: whole megabytes without decimals ("1 MB",
/// "25 MB"), anything else as [formatBytes].
String formatLimit(int bytes) {
  const mb = 1024 * 1024;
  return bytes % mb == 0 ? '${bytes ~/ mb} MB' : formatBytes(bytes);
}

/// Why a picked file cannot be attached (ADR-0070 §2, §7).
enum AttachmentCheck {
  /// It can be attached.
  ok,

  /// Over the maximum size of its type, also offline.
  tooLarge,

  /// A PDF that does not fit into the organization's storage any more (only
  /// known online, for those who see the storage).
  doesNotFit,
}

/// Checks a picked file [name] of [size] bytes before it is attached; with
/// [storage] and the PDFs of [added] bytes attached before it in the same
/// pick.
AttachmentCheck checkAttachment(
  String name,
  int size, {
  OrgStorage? storage,
  int added = 0,
}) {
  if (size > maxAttachmentBytesFor(name)) return AttachmentCheck.tooLarge;
  if (isPdfFile(name) && storage != null && !storage.fits(added + size)) {
    return AttachmentCheck.doesNotFit;
  }
  return AttachmentCheck.ok;
}

/// The storage of the organization [libraryId] (ADR-0070), for those who
/// may see it ([LibraryView.canSeeStorage]); null otherwise, offline and
/// for the local library.
OrgStorage? watchOrgStorage(WidgetRef ref, String libraryId) {
  if (!ref.watch(libraryProvider(libraryId)).canSeeStorage) return null;
  return ref.watch(orgStorageProvider(libraryId)).value;
}

/// [watchOrgStorage] as it is now, for event handlers: known when a
/// widget shows it (e.g. [AttachmentLimitHint]).
OrgStorage? readOrgStorage(WidgetRef ref, String libraryId) {
  if (!ref.read(libraryProvider(libraryId)).canSeeStorage) return null;
  return ref.read(orgStorageProvider(libraryId)).value;
}

/// The hint next to "Attach file" (ADR-0070 §2, §7): the maximum size of a
/// PDF and, for those who may see it, the storage still free, in the
/// warning colour from 90 %.
class AttachmentLimitHint extends ConsumerWidget {
  const AttachmentLimitHint({super.key, required this.libraryId});

  final String libraryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final storage = watchOrgStorage(ref, libraryId);
    final parts = [
      l10n.attachmentPdfLimit(formatLimit(maxPdfBytes)),
      if (storage?.limitBytes case final limit?)
        l10n.storageFree(formatBytes(storage!.freeBytes!), formatLimit(limit)),
    ];
    final warn = storage?.nearlyFull ?? false;
    return Text(
      [parts.join(' · '), if (warn) l10n.storageNearlyFull].join('\n'),
      key: const Key('attachment-limit-hint'),
      style: theme.textTheme.bodySmall?.copyWith(
        color: warn
            ? StatusColors.of(context).warning
            : theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// The storage usage of an organization on its screen (ADR-0070 §7):
/// "Storage: 12 MB of 25 MB", the trash included, with a warning from
/// 90 %. Opens the trash of the library, where deleted PDFs are purged.
/// Nothing for those who may not see it, and offline.
class StorageUsageTile extends ConsumerWidget {
  const StorageUsageTile({super.key, required this.organizationId});

  final String organizationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final storage = watchOrgStorage(ref, organizationId);
    if (storage == null) return const SizedBox.shrink();
    final warn = storage.nearlyFull;
    final color = warn ? StatusColors.of(context).warning : null;
    final used = formatBytes(storage.usedBytes);
    return ListTile(
      key: const Key('org-storage'),
      leading: Icon(
        warn ? Icons.warning_amber_outlined : Icons.storage_outlined,
        color: color,
      ),
      title: Text(switch (storage.limitBytes) {
        null => l10n.storageUsageUnlimited(used),
        final limit => l10n.storageUsage(used, formatLimit(limit)),
      }, style: TextStyle(color: color)),
      subtitle: Text(
        [if (warn) l10n.storageNearlyFull, l10n.storageTrashCounts].join(' '),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push<void>(AppPaths.songsTrash(organizationId)),
    );
  }
}

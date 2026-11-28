import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database.dart';
import 'storage_providers.dart';
import 'trash.dart';

final trashRepositoryProvider = Provider<TrashRepository>(
  (ref) => TrashRepository(
    ref.watch(databaseProvider),
    ref.watch(attachmentStorageProvider),
  ),
);

/// Deleted songs of a library that can still be restored (ADR-0043).
final trashedSongsProvider = StreamProvider.autoDispose
    .family<List<SongEntry>, String>(
      (ref, libraryId) =>
          ref.watch(trashRepositoryProvider).watchSongs(libraryId),
    );

/// Attachments of a library deleted on their own that can still be
/// restored or purged (ADR-0043, ADR-0070), with their song's title.
final trashedAttachmentsProvider = StreamProvider.autoDispose
    .family<List<(AttachmentEntry, String)>, String>(
      (ref, libraryId) =>
          ref.watch(trashRepositoryProvider).watchAttachments(libraryId),
    );

/// Deleted sets of a band that can still be restored (ADR-0043).
final trashedSetsProvider = StreamProvider.autoDispose
    .family<List<SetlistEntry>, String>(
      (ref, bandId) => ref.watch(trashRepositoryProvider).watchSets(bandId),
    );

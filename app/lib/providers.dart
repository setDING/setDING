import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/attachment_storage.dart';
import 'data/database.dart';
import 'data/import_export.dart';
import 'data/set_repository.dart';
import 'data/song_repository.dart';

final databaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('Overridden in main()'),
);

final attachmentStorageProvider = Provider<AttachmentStorage>(
  (ref) => throw UnimplementedError('Overridden in main()'),
);

final songRepositoryProvider = Provider<SongRepository>(
  (ref) => SongRepository(
    ref.watch(databaseProvider),
    ref.watch(attachmentStorageProvider),
  ),
);

final setRepositoryProvider = Provider<SetRepository>(
  (ref) => SetRepository(
    ref.watch(databaseProvider),
    ref.watch(attachmentStorageProvider),
  ),
);

final importExportProvider = Provider<ImportExportService>(
  (ref) => ImportExportService(
    ref.watch(songRepositoryProvider),
    ref.watch(setRepositoryProvider),
  ),
);

/// Songs filtered by search text and optional tag.
final songsProvider =
    StreamProvider.family<List<SongEntry>, ({String query, String? tag})>(
      (ref, filter) => ref
          .watch(songRepositoryProvider)
          .watchSongs(query: filter.query, tag: filter.tag),
    );

/// All tags used in the library.
final tagsProvider = StreamProvider<List<String>>(
  (ref) => ref.watch(songRepositoryProvider).watchTags(),
);

final songProvider = StreamProvider.family<SongEntry?, String>(
  (ref, id) => ref.watch(songRepositoryProvider).watchSong(id),
);

final attachmentsProvider =
    StreamProvider.family<List<AttachmentEntry>, String>(
      (ref, songId) =>
          ref.watch(songRepositoryProvider).watchAttachments(songId),
    );

final attachmentCountsProvider = StreamProvider<Map<String, int>>(
  (ref) => ref.watch(songRepositoryProvider).watchAttachmentCounts(),
);

final overlayProvider = StreamProvider.family<SongOverlay, String>(
  (ref, songId) => ref.watch(songRepositoryProvider).watchOverlay(songId),
);

final setsProvider = StreamProvider<List<SetSummary>>(
  (ref) => ref.watch(setRepositoryProvider).watchSets(),
);

final setProvider = StreamProvider.family<SetlistEntry?, String>(
  (ref, id) => ref.watch(setRepositoryProvider).watchSet(id),
);

final setItemsProvider = StreamProvider.family<List<SetItemView>, String>(
  (ref, setId) => ref.watch(setRepositoryProvider).watchItems(setId),
);

/// Re-evaluated whenever the set's items or the attachments change.
final offlineReadyProvider = FutureProvider.family<bool, String>((
  ref,
  setId,
) async {
  ref.watch(setItemsProvider(setId));
  ref.watch(attachmentCountsProvider);
  return ref.watch(setRepositoryProvider).isOfflineReady(setId);
});

final storageUsageProvider = FutureProvider<int>((ref) async {
  ref.watch(attachmentCountsProvider);
  return ref.watch(attachmentStorageProvider).usedBytes();
});

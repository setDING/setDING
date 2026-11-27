import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/settings.dart';
import '../sync/auth_providers.dart';
import 'band_providers.dart';
import 'database.dart';
import 'song_repository.dart';
import 'song_review.dart';
import 'storage_providers.dart';

/// Songs of one library. Operations on a single song (overlays, attachments,
/// edits) use the song's own library, whichever repository is used.
final librarySongRepositoryProvider = Provider.family<SongRepository, String>(
  (ref, libraryId) => SongRepository(
    ref.watch(databaseProvider),
    ref.watch(attachmentStorageProvider),
    libraryId: libraryId,
    userId: ref.watch(authProvider.select((u) => u?.id)),
  ),
);

/// Songs of the library chosen on the songs tab.
final songRepositoryProvider = Provider<SongRepository>(
  (ref) => ref.watch(
    librarySongRepositoryProvider(ref.watch(currentLibraryIdProvider)),
  ),
);

/// Review status and mistake reports of songs (ADR-0060).
final songReviewRepositoryProvider = Provider<SongReviewRepository>(
  (ref) => SongReviewRepository(
    ref.watch(databaseProvider),
    ref.watch(attachmentStorageProvider),
    userId: ref.watch(authProvider.select((u) => u?.id)),
    backend: ref.watch(syncBackendProvider),
  ),
);

/// The songs of [libraryId] with open mistake reports (ADR-0060).
final reportedSongIdsProvider = StreamProvider.autoDispose
    .family<Set<String>, String>(
      (ref, libraryId) =>
          ref.watch(songReviewRepositoryProvider).watchReportedSongs(libraryId),
    );

/// The mistake reports of a song that are not deleted, newest first
/// (ADR-0060).
final songReportsProvider = StreamProvider.autoDispose
    .family<List<SongReportRow>, String>(
      (ref, songId) =>
          ref.watch(songReviewRepositoryProvider).watchReports(songId),
    );

/// Songs of the current band's library, for its sets.
final bandSongRepositoryProvider = Provider<SongRepository>(
  (ref) => ref.watch(
    librarySongRepositoryProvider(ref.watch(bandLibraryIdProvider)),
  ),
);

/// Order of the song list (stored per device).
class SongSortNotifier extends Notifier<SongSort> {
  static const _key = 'songSort';

  @override
  SongSort build() {
    final stored = ref.watch(sharedPreferencesProvider).getString(_key);
    return SongSort.values.asNameMap()[stored] ?? SongSort.title;
  }

  Future<void> select(SongSort sort) async {
    state = sort;
    await ref.read(sharedPreferencesProvider).setString(_key, sort.name);
  }
}

final songSortProvider = NotifierProvider<SongSortNotifier, SongSort>(
  SongSortNotifier.new,
);

/// Songs filtered by search text and tags (any of them; all songs when
/// empty), in the chosen order.
///
/// A set compares by identity, so callers keep the same set instance
/// until the selection changes (or pass `const {}`).
final songsProvider = StreamProvider.autoDispose
    .family<List<SongListEntry>, ({String query, Set<String> tags})>(
      (ref, filter) => ref
          .watch(songRepositoryProvider)
          .watchSongList(
            query: filter.query,
            tags: filter.tags,
            sort: ref.watch(songSortProvider),
          ),
    );

/// Songs of the current band's library filtered by search text and tags,
/// in the chosen order, for adding them to a set (#884): the song picker
/// shows the band's library, not the one chosen on the songs tab.
///
/// A set compares by identity, as for [songsProvider].
final bandSongsProvider = StreamProvider.autoDispose
    .family<List<SongListEntry>, ({String query, Set<String> tags})>(
      (ref, filter) => ref
          .watch(bandSongRepositoryProvider)
          .watchSongList(
            query: filter.query,
            tags: filter.tags,
            sort: ref.watch(songSortProvider),
          ),
    );

/// Where the search text matched the songs of the current band's library,
/// for the song picker of a set (#884).
final bandSearchHitsProvider = StreamProvider.autoDispose
    .family<Map<String, SearchHit>, String>(
      (ref, query) => query.trim().isEmpty
          ? Stream.value(const {})
          : ref.watch(bandSongRepositoryProvider).watchSearchHits(query),
    );

/// All tags used in the current band's library, for the song picker
/// (#884).
final bandTagsProvider = StreamProvider.autoDispose<List<String>>(
  (ref) => ref.watch(bandSongRepositoryProvider).watchTags(),
);

/// The languages of the songs of the current band's library (ADR-0053),
/// for the song picker (#884).
final bandSongLanguagesProvider = StreamProvider.autoDispose<Set<String>>(
  (ref) => ref.watch(bandSongRepositoryProvider).watchLanguages(),
);

/// The songs of the current band's library created last, for the
/// overview (ADR-0045, #868).
final newestSongsProvider = StreamProvider.autoDispose<List<SongEntry>>(
  (ref) => ref.watch(bandSongRepositoryProvider).watchNewestSongs(),
);

/// All tags used in the library.
/// Where a search matched the songs of the library (by song); empty
/// without a search.
final searchHitsProvider = StreamProvider.autoDispose
    .family<Map<String, SearchHit>, String>(
      (ref, query) => query.trim().isEmpty
          ? Stream.value(const {})
          : ref.watch(songRepositoryProvider).watchSearchHits(query),
    );

final tagsProvider = StreamProvider<List<String>>(
  (ref) => ref.watch(songRepositoryProvider).watchTags(),
);

/// The languages of the songs of the current library (ADR-0053).
final songLanguagesProvider = StreamProvider<Set<String>>(
  (ref) => ref.watch(songRepositoryProvider).watchLanguages(),
);

/// How many songs of the current library share each group of language
/// versions (ADR-0053).
final workCountsProvider = StreamProvider<Map<String, int>>(
  (ref) => ref.watch(songRepositoryProvider).watchWorkCounts(),
);

final songProvider = StreamProvider.autoDispose.family<SongEntry?, String>(
  (ref, id) => ref.watch(songRepositoryProvider).watchSong(id),
);

final attachmentsProvider = StreamProvider.autoDispose
    .family<List<AttachmentEntry>, String>(
      (ref, songId) =>
          ref.watch(songRepositoryProvider).watchAttachments(songId),
    );

final attachmentCountsProvider = StreamProvider<Map<String, int>>(
  (ref) => ref.watch(songRepositoryProvider).watchAttachmentCounts(),
);

final overlayProvider = StreamProvider.autoDispose.family<SongOverlay, String>(
  (ref, songId) => ref.watch(songRepositoryProvider).watchOverlay(songId),
);

final storageUsageProvider = FutureProvider<int>((ref) async {
  ref.watch(attachmentCountsProvider);
  return ref.watch(attachmentStorageProvider).usedBytes();
});

// Moving to the areas' own provider files (#1203); re-exports the moved
// ones until every caller imports them directly.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/annotation_repository.dart';
import 'data/arrangement_repository.dart';
import 'data/auto_backup.dart';
import 'data/backup.dart';
import 'data/band_copy.dart';
import 'data/band_providers.dart';
import 'data/band_view.dart';
import 'data/database.dart';
import 'data/import_export.dart';
import 'data/lineup.dart';
import 'data/play_history.dart';
import 'data/set_archive.dart';
import 'data/set_repository.dart';
import 'data/song_archive.dart';
import 'data/song_repository.dart';
import 'data/song_review.dart';
import 'data/storage_providers.dart';
import 'data/trash.dart';
import 'platform/backup_folder.dart';
import 'platform/web_client.dart';
import 'settings/settings.dart';
import 'sync/auth_providers.dart';

export 'data/band_providers.dart';
export 'data/storage_providers.dart';
export 'platform/web_client.dart';

// Songs of the current library, sets of the current band ----------------------

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

final setRepositoryProvider = Provider<SetRepository>(
  (ref) => SetRepository(
    ref.watch(databaseProvider),
    ref.watch(attachmentStorageProvider),
    bandId: ref.watch(currentBandIdProvider),
    userId: ref.watch(authProvider.select((u) => u?.id)),
    bandMember: ref.watch(
      currentBandProvider.select((b) => b.isLocal || b.role != null),
    ),
  ),
);

/// Copies songs and sets into other libraries and bands (ADR-0017).
final bandCopyProvider = Provider<BandCopyService>(
  (ref) => BandCopyService(
    ref.watch(databaseProvider),
    ref.watch(attachmentStorageProvider),
    userId: ref.watch(authProvider.select((u) => u?.id)),
  ),
);

/// Backup archive of a library (ADR-0043).
final backupServiceProvider = Provider<BackupService>(
  (ref) => BackupService(
    ref.watch(databaseProvider),
    ref.watch(attachmentStorageProvider),
    userId: ref.watch(authProvider.select((u) => u?.id)),
    appVersion: ref.watch(clientVersionProvider) ?? '',
  ),
);

/// The folder of the automatic backup (ADR-0054).
final backupFolderProvider = Provider<BackupFolder>(
  (ref) => createBackupFolder(),
);

/// The setting and state of the automatic backup of the local library
/// (ADR-0054).
final autoBackupProvider =
    NotifierProvider<AutoBackupNotifier, AutoBackupState>(
      AutoBackupNotifier.new,
    );

class AutoBackupNotifier extends Notifier<AutoBackupState> {
  late AutoBackupController controller;

  @override
  AutoBackupState build() {
    controller = AutoBackupController(
      prefs: ref.watch(sharedPreferencesProvider),
      folder: ref.watch(backupFolderProvider),
      backups: () => ref.read(backupServiceProvider),
      onChanged: (s) {
        if (ref.mounted) state = s;
      },
    );
    if (controller.folder.supported) {
      unawaited(controller.loadSystemDeviceName());
      unawaited(controller.describeFolder());
    }
    return controller.state;
  }
}

final setArchiveServiceProvider = Provider<SetArchiveService>(
  (ref) => SetArchiveService(ref.watch(backupServiceProvider)),
);

final songArchiveServiceProvider = Provider<SongArchiveService>(
  (ref) => SongArchiveService(ref.watch(backupServiceProvider)),
);

final importExportProvider = Provider<ImportExportService>(
  (ref) => ImportExportService(
    ref.watch(songRepositoryProvider),
    ref.watch(setRepositoryProvider),
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

/// Personal freehand annotations (ADR-0032).
final annotationRepositoryProvider = Provider<AnnotationRepository>(
  (ref) => AnnotationRepository(
    ref.watch(databaseProvider),
    userId: ref.watch(authProvider.select((u) => u?.id)),
  ),
);

/// The strokes on a song's ChordPro text (`target` empty) or on one of its
/// PDF attachments.
final annotationsProvider = StreamProvider.autoDispose
    .family<List<AnnotationStroke>, ({String songId, String target})>(
      (ref, key) => ref
          .watch(annotationRepositoryProvider)
          .watch(key.songId, target: key.target),
    );

/// Estimated size in bytes of the strokes on a song's text or attachment,
/// against [annotationMaxBytes].
final annotationSizeProvider = StreamProvider.autoDispose
    .family<int, ({String songId, String target})>(
      (ref, key) => ref
          .watch(annotationRepositoryProvider)
          .watchSize(key.songId, target: key.target),
    );

/// Number of strokes on a song (text and attachments).
final annotationCountProvider = StreamProvider.autoDispose.family<int, String>(
  (ref, songId) => ref.watch(annotationRepositoryProvider).watchCount(songId),
);

/// Band arrangements (ADR-0025).
final arrangementRepositoryProvider = Provider<ArrangementRepository>(
  (ref) => ArrangementRepository(
    ref.watch(databaseProvider),
    userId: ref.watch(authProvider.select((u) => u?.id)),
  ),
);

/// The band whose arrangement the song screen shows for songs of
/// [libraryId]: the band chosen on the sets tab, if it plays from that
/// library (ADR-0025); null otherwise. It applies in sets and, for the
/// sequence only, to a single song played live (#552).
final arrangementBandProvider = Provider.family<BandView?, String>((
  ref,
  libraryId,
) {
  final band = ref.watch(currentBandProvider);
  return !band.isLocal && band.libraryId == libraryId ? band : null;
});

/// The bands of the user that play from [libraryId], to choose the band of
/// the arrangement panel from (#556).
final arrangementBandsProvider = Provider.family<List<BandView>, String>((
  ref,
  libraryId,
) {
  final bands = ref.watch(bandsProvider).value ?? const <BandView>[];
  return [
    for (final b in bands)
      if (!b.isLocal && b.libraryId == libraryId) b,
  ];
});

/// The arrangement of a band for a song, or null.
final arrangementProvider = StreamProvider.autoDispose
    .family<BandArrangement?, ({String band, String song})>(
      (ref, key) =>
          ref.watch(arrangementRepositoryProvider).watch(key.band, key.song),
    );

/// The arrangements of a band by song.
final bandArrangementsProvider = StreamProvider.autoDispose
    .family<Map<String, BandArrangement>, String>(
      (ref, bandId) =>
          ref.watch(arrangementRepositoryProvider).watchBand(bandId),
    );

/// The song play history of the bands (ADR-0046).
final playHistoryRepositoryProvider = Provider<PlayHistoryRepository>(
  (ref) => PlayHistoryRepository(ref.watch(databaseProvider)),
);

/// The plays of a song by a band, newest first (ADR-0046).
final songPlaysProvider = StreamProvider.autoDispose
    .family<SongPlays, ({String band, String song})>(
      (ref, key) => ref
          .watch(playHistoryRepositoryProvider)
          .watchSongPlays(key.band, key.song),
    );

/// The repertoire of a band: the songs of its library with their plays
/// (ADR-0046).
final repertoireProvider = StreamProvider.autoDispose
    .family<Repertoire, ({String band, String library})>(
      (ref, key) => ref
          .watch(playHistoryRepositoryProvider)
          .watchRepertoire(key.band, key.library),
    );

/// How the other bands of the organization played a song (ADR-0046).
final otherBandPlaysProvider = StreamProvider.autoDispose
    .family<List<OrgPlay>, ({String song, String? exceptBand})>(
      (ref, key) => ref
          .watch(playHistoryRepositoryProvider)
          .watchOtherBands(key.song, exceptBandId: key.exceptBand),
    );

/// When the plays across an organization's bands were fetched last.
final orgPlaysFetchedProvider = StreamProvider.autoDispose
    .family<DateTime?, String>(
      (ref, orgId) =>
          ref.watch(playHistoryRepositoryProvider).watchOrgPlaysFetched(orgId),
    );

/// The songs of a library no band played (ADR-0046).
final libraryUsageProvider = StreamProvider.autoDispose
    .family<({List<SongEntry> unplayed, int total}), String>(
      (ref, libraryId) =>
          ref.watch(playHistoryRepositoryProvider).watchLibraryUsage(libraryId),
    );

/// When a band last played each song (ADR-0046).
final lastPlayedProvider = StreamProvider.autoDispose
    .family<Map<String, DateTime>, String>(
      (ref, bandId) =>
          ref.watch(playHistoryRepositoryProvider).watchLastPlayed(bandId),
    );

/// The next gig of each song in the current band's sets, for the song list
/// of [libraryId]; empty when the band plays from another library.
final upcomingGigsProvider = StreamProvider.autoDispose
    .family<Map<String, UpcomingGig>, String>((ref, libraryId) {
      if (ref.watch(bandLibraryIdProvider) != libraryId) {
        return Stream.value(const {});
      }
      return ref.watch(setRepositoryProvider).watchUpcomingGigs();
    });

/// Whether the past sets on the sets tab are collapsed (stored per device,
/// #265). Collapsed until the user expands them on this device (#282).
class PastSetsCollapsedNotifier extends Notifier<bool> {
  static const _key = 'pastSetsCollapsed';

  @override
  bool build() => ref.watch(sharedPreferencesProvider).getBool(_key) ?? true;

  Future<void> toggle() async {
    state = !state;
    await ref.read(sharedPreferencesProvider).setBool(_key, state);
  }
}

final pastSetsCollapsedProvider =
    NotifierProvider<PastSetsCollapsedNotifier, bool>(
      PastSetsCollapsedNotifier.new,
    );

/// The sets whose *You are planned* hint was dismissed on this device
/// (ADR-0061): each set is announced once.
class PlannedSeenNotifier extends Notifier<Set<String>> {
  static const _key = 'lineupPlannedSeen';

  @override
  Set<String> build() =>
      (ref.watch(sharedPreferencesProvider).getStringList(_key) ?? const [])
          .toSet();

  Future<void> markSeen(Iterable<String> setIds) async {
    state = {...state, ...setIds};
    await ref
        .read(sharedPreferencesProvider)
        .setStringList(_key, state.toList());
  }
}

final plannedSeenProvider = NotifierProvider<PlannedSeenNotifier, Set<String>>(
  PlannedSeenNotifier.new,
);

/// Upcoming gigs the user was put in the lineup of by name (ADR-0061) and
/// not told about yet on this device: the overview's *You are planned*.
final plannedGigsProvider = StreamProvider.autoDispose<List<SubstituteGig>>((
  ref,
) {
  final userId = ref.watch(authProvider.select((u) => u?.id));
  if (userId == null) return Stream.value(const []);
  final seen = ref.watch(plannedSeenProvider);
  return watchPlannedGigs(ref.watch(databaseProvider), userId).map(
    (gigs) => [
      for (final g in gigs)
        if (!seen.contains(g.set.id)) g,
    ],
  );
});

/// The set chosen on the sets tab (#266): shown next to the list on wide
/// screens. Kept outside the widgets, so it survives a change of layout
/// (e.g. rotating a tablet); null shows the next gig.
class SelectedSetNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? setId) => state = setId;
}

final selectedSetProvider = NotifierProvider<SelectedSetNotifier, String?>(
  SelectedSetNotifier.new,
);

final setsProvider = StreamProvider<List<SetSummary>>(
  (ref) => ref.watch(setRepositoryProvider).watchSets(),
);

/// The upcoming sets the user plays as a substitute in other bands
/// (ADR-0061), for the overview.
final substituteGigsProvider = StreamProvider.autoDispose<List<SubstituteGig>>(
  (ref) => watchSubstituteGigs(ref.watch(databaseProvider)),
);

final setProvider = StreamProvider.autoDispose.family<SetlistEntry?, String>(
  (ref, id) => ref.watch(setRepositoryProvider).watchSet(id),
);

/// The lineup of a set of the current band with the people's names
/// (ADR-0061); null for an unknown set and in the local library, which has
/// no lineups.
final setLineupProvider = Provider.autoDispose.family<SetLineup?, String>((
  ref,
  setId,
) {
  final set = ref.watch(setProvider(setId)).value;
  final band = ref.watch(currentBandProvider);
  if (set == null || band.isLocal) return null;
  final orgId = band.organizationId;
  return resolveLineup(
    set,
    members: ref.watch(bandMembersProvider(set.bandId)).value ?? const [],
    orgMembers: orgId == null
        ? const []
        : ref.watch(orgMembersProvider(orgId)).value ?? const [],
    userId: ref.watch(authProvider.select((u) => u?.id)),
    contacts: orgId == null
        ? const []
        : ref.watch(allOrgContactsProvider(orgId)).value ?? const [],
    format: ref.watch(nameFormatProvider),
  );
});

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

/// Deleted sets of a band that can still be restored (ADR-0043).
final trashedSetsProvider = StreamProvider.autoDispose
    .family<List<SetlistEntry>, String>(
      (ref, bandId) => ref.watch(trashRepositoryProvider).watchSets(bandId),
    );

final setItemsProvider = StreamProvider.autoDispose
    .family<List<SetItemView>, String>(
      (ref, setId) => ref.watch(setRepositoryProvider).watchItems(setId),
    );

/// Per set of the current band, the song items not available offline,
/// from one query.
final _offlineMissingProvider = StreamProvider.autoDispose<Map<String, int>>(
  (ref) => ref.watch(setRepositoryProvider).watchOfflineMissing(),
);

/// How many songs of a set are not available offline (ADR-0001): 0 = the set
/// is offline ready; null on the web client, which makes no offline promise
/// (ADR-0018).
final offlineMissingProvider = FutureProvider.autoDispose.family<int?, String>((
  ref,
  setId,
) async {
  if (ref.watch(webClientProvider)) return null;
  return (await ref.watch(_offlineMissingProvider.future))[setId] ?? 0;
});

/// Number of songs with ChordPro problems per set of the current band
/// (#314).
final problemSongCountsProvider = StreamProvider.autoDispose<Map<String, int>>(
  (ref) => ref.watch(setRepositoryProvider).watchProblemSongCounts(),
);

/// Number of songs per set of the current band that wait for a check or
/// have open mistake reports (ADR-0060).
final reviewSongCountsProvider = StreamProvider.autoDispose<Map<String, int>>(
  (ref) => ref.watch(setRepositoryProvider).watchReviewSongCounts(),
);

final storageUsageProvider = FutureProvider<int>((ref) async {
  ref.watch(attachmentCountsProvider);
  return ref.watch(attachmentStorageProvider).usedBytes();
});

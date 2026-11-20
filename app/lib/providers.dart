import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/annotation_repository.dart';
import 'data/arrangement_repository.dart';
import 'data/attachment_storage.dart';
import 'data/backup.dart';
import 'data/band_copy.dart';
import 'data/band_view.dart';
import 'data/database.dart';
import 'data/import_export.dart';
import 'data/play_history.dart';
import 'data/set_repository.dart';
import 'data/song_repository.dart';
import 'data/trash.dart';
import 'settings/settings.dart';
import 'sync/auth_providers.dart';
import 'sync/band_service.dart';

final databaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('Overridden in main()'),
);

final attachmentStorageProvider = Provider<AttachmentStorage>(
  (ref) => throw UnimplementedError('Overridden in main()'),
);

/// Whether this is the web client (ADR-0018): signing in is required, the
/// local library and file import/export are hidden, and signing out deletes
/// the local data. Overridden in tests.
final webClientProvider = Provider<bool>((ref) => kIsWeb);

// Bands (ADR-0005) -------------------------------------------------------------

final bandServiceProvider = Provider<BandService>(
  (ref) => BandService(
    ref.watch(databaseProvider),
    ref.watch(syncBackendProvider),
    storage: ref.watch(attachmentStorageProvider),
  ),
);

/// The local library followed by the bands of the signed-in user. The web
/// client has no local library (ADR-0018).
final bandsProvider = StreamProvider<List<BandView>>((ref) {
  final bands = ref
      .watch(bandServiceProvider)
      .watchBands(ref.watch(authProvider.select((u) => u?.id)));
  if (!ref.watch(webClientProvider)) return bands;
  return bands.map(
    (list) => [
      for (final b in list)
        if (!b.isLocal) b,
    ],
  );
});

/// The band chosen in the band switcher (stored per device).
class SelectedBandNotifier extends Notifier<String> {
  static const _key = 'currentBandId';

  @override
  String build() =>
      ref.watch(sharedPreferencesProvider).getString(_key) ?? localBandId;

  Future<void> select(String bandId) async {
    state = bandId;
    await ref.read(sharedPreferencesProvider).setString(_key, bandId);
  }

  /// Forgets the choice (web sign-out).
  Future<void> reset() async {
    state = localBandId;
    await ref.read(sharedPreferencesProvider).remove(_key);
  }
}

final selectedBandIdProvider = NotifierProvider<SelectedBandNotifier, String>(
  SelectedBandNotifier.new,
);

/// The band whose songs and sets are shown. Falls back to the local library
/// when the selected band is not available (signed out, removed).
final currentBandProvider = Provider<BandView>((ref) {
  // The web client never falls back to the local library (ADR-0018); its
  // start screen waits for a band.
  final bands =
      ref.watch(bandsProvider).value ??
      (ref.watch(webClientProvider)
          ? const <BandView>[]
          : const [BandView.local]);
  final selected = ref.watch(selectedBandIdProvider);
  return bands.firstWhere(
    (b) => b.id == selected,
    orElse: () => bands.firstOrNull ?? BandView.local,
  );
});

final _currentBandIdProvider = Provider<String>(
  (ref) => ref.watch(currentBandProvider.select((b) => b.id)),
);

/// Song library of the current band: its organization (ADR-0017), or the
/// local library. Sets, their song picker and Live mode use it.
final _bandLibraryIdProvider = Provider<String>(
  (ref) => ref.watch(currentBandProvider.select((b) => b.libraryId)),
);

// Song libraries (ADR-0017) ---------------------------------------------------

/// The local library followed by the libraries of the user's
/// organizations. The web client has no local library (ADR-0018).
final librariesProvider = StreamProvider<List<LibraryView>>((ref) {
  final libraries = ref
      .watch(bandServiceProvider)
      .watchLibraries(ref.watch(authProvider.select((u) => u?.id)));
  if (!ref.watch(webClientProvider)) return libraries;
  return libraries.map(
    (list) => [
      for (final l in list)
        if (!l.isLocal) l,
    ],
  );
});

/// The song library chosen on the songs tab (stored per device),
/// independent of the band; null until one is chosen.
class SelectedLibraryNotifier extends Notifier<String?> {
  static const _key = 'currentLibraryId';

  @override
  String? build() => ref.watch(sharedPreferencesProvider).getString(_key);

  Future<void> select(String libraryId) async {
    state = libraryId;
    await ref.read(sharedPreferencesProvider).setString(_key, libraryId);
  }

  /// Forgets the choice (web sign-out).
  Future<void> reset() async {
    state = null;
    await ref.read(sharedPreferencesProvider).remove(_key);
  }
}

final selectedLibraryIdProvider =
    NotifierProvider<SelectedLibraryNotifier, String?>(
      SelectedLibraryNotifier.new,
    );

/// The song library shown on the songs tab. Without a choice, or when the
/// chosen library is not available (signed out, left the organization),
/// the library of the current band.
final currentLibraryProvider = Provider<LibraryView>((ref) {
  final libraries =
      ref.watch(librariesProvider).value ??
      (ref.watch(webClientProvider)
          ? const <LibraryView>[]
          : const [LibraryView.local]);
  final bandLibrary = ref.watch(_bandLibraryIdProvider);
  final selected = ref.watch(selectedLibraryIdProvider) ?? bandLibrary;
  return libraries.where((l) => l.id == selected).firstOrNull ??
      libraries.where((l) => l.id == bandLibrary).firstOrNull ??
      libraries.firstOrNull ??
      LibraryView.local;
});

/// A song library with the user's permissions, e.g. of the song shown;
/// without permissions when the user cannot see it (any more).
final libraryProvider = Provider.family<LibraryView, String>((ref, id) {
  if (id == localBandId) return LibraryView.local;
  final libraries = ref.watch(librariesProvider).value ?? const [];
  return libraries.where((l) => l.id == id).firstOrNull ?? LibraryView(id: id);
});

final _currentLibraryIdProvider = Provider<String>(
  (ref) => ref.watch(currentLibraryProvider.select((l) => l.id)),
);

/// The organizations of the signed-in user.
final organizationsProvider = StreamProvider<List<OrganizationView>>(
  (ref) => ref
      .watch(bandServiceProvider)
      .watchOrganizations(ref.watch(authProvider.select((u) => u?.id))),
);

/// People of an organization, admins first.
final orgMembersProvider = StreamProvider.autoDispose
    .family<List<OrgMembershipEntry>, String>(
      (ref, orgId) => ref.watch(bandServiceProvider).watchOrgMembers(orgId),
    );

/// Members of a band, admins first.
final bandMembersProvider = StreamProvider.autoDispose
    .family<List<MembershipEntry>, String>(
      (ref, bandId) => ref.watch(bandServiceProvider).watchMembers(bandId),
    );

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
    librarySongRepositoryProvider(ref.watch(_currentLibraryIdProvider)),
  ),
);

/// Songs of the current band's library, for its sets.
final bandSongRepositoryProvider = Provider<SongRepository>(
  (ref) => ref.watch(
    librarySongRepositoryProvider(ref.watch(_bandLibraryIdProvider)),
  ),
);

final setRepositoryProvider = Provider<SetRepository>(
  (ref) => SetRepository(
    ref.watch(databaseProvider),
    ref.watch(attachmentStorageProvider),
    bandId: ref.watch(_currentBandIdProvider),
    userId: ref.watch(authProvider.select((u) => u?.id)),
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

/// Songs filtered by search text and optional tag, in the chosen order.
final songsProvider = StreamProvider.autoDispose
    .family<List<SongListEntry>, ({String query, String? tag})>(
      (ref, filter) => ref
          .watch(songRepositoryProvider)
          .watchSongList(
            query: filter.query,
            tag: filter.tag,
            sort: ref.watch(songSortProvider),
          ),
    );

/// Songs of the current band's library filtered by search text, for adding
/// them to a set.
final bandSongsProvider = StreamProvider.autoDispose
    .family<List<SongListEntry>, String>(
      (ref, query) =>
          ref.watch(bandSongRepositoryProvider).watchSongList(query: query),
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
      if (ref.watch(_bandLibraryIdProvider) != libraryId) {
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

final setProvider = StreamProvider.autoDispose.family<SetlistEntry?, String>(
  (ref, id) => ref.watch(setRepositoryProvider).watchSet(id),
);

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

/// Sets of the current band that are not offline ready, from one query.
final _notOfflineReadySetsProvider = StreamProvider.autoDispose<Set<String>>(
  (ref) => ref.watch(setRepositoryProvider).watchNotOfflineReady(),
);

/// Whether a set of the current band is offline ready (ADR-0001).
/// Whether a set is offline ready (ADR-0001); null on the web client, which
/// makes no offline promise (ADR-0018).
final offlineReadyProvider = FutureProvider.autoDispose.family<bool?, String>((
  ref,
  setId,
) async {
  if (ref.watch(webClientProvider)) return null;
  return !(await ref.watch(_notOfflineReadySetsProvider.future))
      .contains(setId);
});

/// Number of songs with ChordPro problems per set of the current band
/// (#314).
final problemSongCountsProvider = StreamProvider.autoDispose<Map<String, int>>(
  (ref) => ref.watch(setRepositoryProvider).watchProblemSongCounts(),
);

final storageUsageProvider = FutureProvider<int>((ref) async {
  ref.watch(attachmentCountsProvider);
  return ref.watch(attachmentStorageProvider).usedBytes();
});

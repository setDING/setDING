import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/attachment_storage.dart';
import 'data/band_copy.dart';
import 'data/band_view.dart';
import 'data/database.dart';
import 'data/import_export.dart';
import 'data/set_repository.dart';
import 'data/song_repository.dart';
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
  (ref) =>
      BandService(ref.watch(databaseProvider), ref.watch(syncBackendProvider)),
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
/// local library.
final _currentLibraryIdProvider = Provider<String>(
  (ref) => ref.watch(currentBandProvider.select((b) => b.libraryId)),
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

// Songs of the current library, sets of the current band --------------------------------------------

final songRepositoryProvider = Provider<SongRepository>(
  (ref) => SongRepository(
    ref.watch(databaseProvider),
    ref.watch(attachmentStorageProvider),
    libraryId: ref.watch(_currentLibraryIdProvider),
    userId: ref.watch(authProvider.select((u) => u?.id)),
  ),
);

final setRepositoryProvider = Provider<SetRepository>(
  (ref) => SetRepository(
    ref.watch(databaseProvider),
    ref.watch(attachmentStorageProvider),
    bandId: ref.watch(_currentBandIdProvider),
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

final importExportProvider = Provider<ImportExportService>(
  (ref) => ImportExportService(
    ref.watch(songRepositoryProvider),
    ref.watch(setRepositoryProvider),
  ),
);

/// Songs filtered by search text and optional tag.
final songsProvider = StreamProvider.autoDispose
    .family<List<SongListEntry>, ({String query, String? tag})>(
      (ref, filter) => ref
          .watch(songRepositoryProvider)
          .watchSongList(query: filter.query, tag: filter.tag),
    );

/// All tags used in the library.
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

final setsProvider = StreamProvider<List<SetSummary>>(
  (ref) => ref.watch(setRepositoryProvider).watchSets(),
);

final setProvider = StreamProvider.autoDispose.family<SetlistEntry?, String>(
  (ref, id) => ref.watch(setRepositoryProvider).watchSet(id),
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

final storageUsageProvider = FutureProvider<int>((ref) async {
  ref.watch(attachmentCountsProvider);
  return ref.watch(attachmentStorageProvider).usedBytes();
});

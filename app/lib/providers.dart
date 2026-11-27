// Moving to the areas' own provider files (#1203); re-exports the moved
// ones until every caller imports them directly.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/auto_backup.dart';
import 'data/backup.dart';
import 'data/band_copy.dart';
import 'data/band_providers.dart';
import 'data/database.dart';
import 'data/import_export.dart';
import 'data/lineup.dart';
import 'data/set_archive.dart';
import 'data/set_repository.dart';
import 'data/song_archive.dart';
import 'data/song_providers.dart';
import 'data/storage_providers.dart';
import 'data/trash.dart';
import 'platform/backup_folder.dart';
import 'platform/web_client.dart';
import 'settings/settings.dart';
import 'sync/auth_providers.dart';

export 'data/annotation_providers.dart';
export 'data/arrangement_providers.dart';
export 'data/band_providers.dart';
export 'data/play_history_providers.dart';
export 'data/song_providers.dart';
export 'data/storage_providers.dart';
export 'platform/web_client.dart';

// Songs of the current library, sets of the current band ----------------------

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

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../platform/web_client.dart';
import '../settings/settings.dart';
import '../sync/auth_providers.dart';
import 'band_providers.dart';
import 'database.dart';
import 'lineup.dart';
import 'set_repository.dart';
import 'storage_providers.dart';

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

/// The next gig of each song in the current band's sets, for the song list
/// of [libraryId]; empty when the band plays from another library.
final upcomingGigsProvider = StreamProvider.autoDispose
    .family<Map<String, UpcomingGig>, String>((ref, libraryId) {
      if (ref.watch(bandLibraryIdProvider) != libraryId) {
        return Stream.value(const {});
      }
      return ref.watch(setRepositoryProvider).watchUpcomingGigs();
    });

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

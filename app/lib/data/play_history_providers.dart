import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database.dart';
import 'play_history.dart';
import 'storage_providers.dart';

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

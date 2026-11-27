import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../sync/auth_providers.dart';
import 'arrangement_repository.dart';
import 'band_providers.dart';
import 'band_view.dart';
import 'database.dart';
import 'storage_providers.dart';

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

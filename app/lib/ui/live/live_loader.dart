import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/arrangement_providers.dart';
import '../../data/database.dart';
import '../../data/set_providers.dart';
import '../../data/song_providers.dart';
import 'live_item.dart';

/// The items of the set [setId] and the index to start at: [index], or
/// with [firstSong] its first song. Empty when the set has no items.
Future<({List<LiveItem> items, int start})> loadLiveSet(
  ProviderContainer container,
  String setId, {
  int index = 0,
  bool firstSong = false,
}) async {
  final sets = container.read(setRepositoryProvider);
  final views = await sets.getItems(setId);
  final set = await sets.getSet(setId);
  // The arrangements of the set's band (ADR-0025).
  final arrangements = set == null
      ? const <String, BandArrangement>{}
      : await container.read(arrangementRepositoryProvider).forBand(set.bandId);
  final items = [
    for (final v in views)
      if (v.item.type != SetItemType.song)
        LiveItem.marker(v.item.icon, v.item.note)
      else if (v.song != null)
        LiveItem.song(
          v.song!,
          arrangement: arrangements[v.song!.id],
          setTranspose: v.item.transpose,
          setSequence: v.item.sequence,
          setItemId: v.item.id,
        ),
  ];
  if (items.isEmpty) return (items: items, start: 0);
  final start = firstSong
      ? items.indexWhere((i) => i.song != null).clamp(0, items.length - 1)
      : index.clamp(0, items.length - 1);
  return (items: items, start: start);
}

/// The song [songId] alone as a live item, or no item if it is missing.
Future<List<LiveItem>> loadLiveSong(
  ProviderContainer container,
  String songId, {
  String? attachmentId,
}) async {
  final song = await container.read(songRepositoryProvider).getSong(songId);
  if (song == null) return const [];
  // Outside a set the song keeps its own key and tempo; only the sequence
  // of the band chosen on the sets tab applies (ADR-0025, #552).
  final band = container.read(arrangementBandProvider(song.libraryId));
  final arrangement = band == null
      ? null
      : await container
            .read(arrangementRepositoryProvider)
            .get(band.id, song.id);
  final sequenceOnly = arrangement?.sequence == null
      ? null
      : arrangement!.copyWith(transpose: 0, tempo: const Value(null));
  return [
    LiveItem.song(song, arrangement: sequenceOnly, attachmentId: attachmentId),
  ];
}

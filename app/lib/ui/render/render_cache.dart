import 'package:chordpro/chordpro.dart';

import '../../data/database.dart' show VerseChords;

/// A small least-recently-used cache for results that are expensive to
/// compute while rendering (parsing, fitting a song to the screen).
class LruCache<K, V extends Object> {
  LruCache(this.capacity);

  final int capacity;
  final _entries = <K, V>{};

  /// The cached value of [key], or the result of [create], which is cached.
  V get(K key, V Function() create) {
    final value = _entries.remove(key) ?? create();
    _entries[key] = value;
    if (_entries.length > capacity) _entries.remove(_entries.keys.first);
    return value;
  }

  /// The cached value of [key] (now the most recently used), or null; does
  /// not create it.
  V? lookup(K key) {
    final value = _entries.remove(key);
    if (value != null) _entries[key] = value;
    return value;
  }

  void clear() => _entries.clear();
}

final _parsed = LruCache<(String, String?, String?), Song>(32);

/// [parseChordPro] with a cache: the same source and selectors give the same
/// [Song] instance, so rebuilds do not parse again and later caches can use
/// the instance as a key.
Song parseChordProCached(
  String source, {
  SelectorContext selectors = const SelectorContext(),
}) => _parsed.get((
  source,
  selectors.instrument,
  selectors.user,
), () => parseChordPro(source, selectors: selectors));

final _selected = LruCache<(Song, String, bool), SequenceSelection>(32);

/// [filterBySequence] with a cache keyed by the [song] instance (see
/// [parseChordProCached]), the raw [sequence] and [keepOutside].
SequenceSelection filterBySequenceCached(
  Song song,
  String sequence, {
  bool keepOutside = false,
}) => _selected.get(
  (song, sequence, keepOutside),
  () =>
      filterBySequence(song, parseSequence(sequence), keepOutside: keepOutside),
);

final _firstVerse = LruCache<Song, Song>(32);
final _stacked = LruCache<Song, Song>(32);

/// [firstVerseChordsOnly] with a cache keyed by the [song] instance (see
/// [parseChordProCached]), so the result is the same instance, too.
Song firstVerseChordsOnlyCached(Song song) =>
    _firstVerse.get(song, () => firstVerseChordsOnly(song));

/// [stackVerses] with a cache keyed by the [song] instance.
Song stackVersesCached(Song song) =>
    _stacked.get(song, () => stackVerses(song));

/// [song] as a person's adjustments show its verses' chords (#518, #521).
Song songWithVerseChords(Song song, VerseChords mode) => switch (mode) {
  VerseChords.all => song,
  VerseChords.first => firstVerseChordsOnlyCached(song),
  VerseChords.stacked => stackVersesCached(song),
};

import 'package:chordpro/chordpro.dart';

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

final _selected = LruCache<(Song, String), SequenceSelection>(32);

/// [filterBySequence] with a cache keyed by the [song] instance (see
/// [parseChordProCached]) and the raw [sequence].
SequenceSelection filterBySequenceCached(Song song, String sequence) =>
    _selected.get((
      song,
      sequence,
    ), () => filterBySequence(song, parseSequence(sequence)));

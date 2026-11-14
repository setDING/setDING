/// Chord model: parsing, transposition and formatting.
library;

/// How chord names are displayed.
enum ChordNotation {
  /// International notation: B, Bb.
  international,

  /// German notation: H for B, B for B flat.
  german,
}

const _sharpNames = [
  'C',
  'C#',
  'D',
  'D#',
  'E',
  'F',
  'F#',
  'G',
  'G#',
  'A',
  'A#',
  'B',
];
const _flatNames = [
  'C',
  'Db',
  'D',
  'Eb',
  'E',
  'F',
  'Gb',
  'G',
  'Ab',
  'A',
  'Bb',
  'B',
];

const _letterPitch = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11};

/// A pitch class (0 = C … 11 = B) together with its preferred spelling.
class Note {
  const Note(this.pitch, {this.preferFlat = false});

  /// Pitch class 0..11.
  final int pitch;

  /// Whether the original spelling used a flat.
  final bool preferFlat;

  Note transpose(int semitones, {bool? useFlats}) =>
      Note((pitch + semitones) % 12, preferFlat: useFlats ?? preferFlat);

  /// Spells the note in the given notation.
  String spell(ChordNotation notation, {bool? useFlats}) {
    final flat = useFlats ?? preferFlat;
    final name = (flat ? _flatNames : _sharpNames)[pitch];
    if (notation == ChordNotation.german) {
      if (name == 'B') return 'H';
      if (name == 'Bb') return 'B';
    }
    return name;
  }

  @override
  bool operator ==(Object other) => other is Note && other.pitch == pitch;

  @override
  int get hashCode => pitch.hashCode;
}

/// Parses a note name like `C`, `F#`, `Bb`, `H`.
///
/// With [germanInput], `B` means B flat and `H` means B.
/// Returns the note and the number of characters consumed, or null.
(Note, int)? parseNote(String input, {bool germanInput = false}) {
  if (input.isEmpty) return null;
  final letter = input[0].toUpperCase();
  // Only accept an upper-case letter as root to avoid treating words as chords.
  if (input[0] != letter) return null;
  int pitch;
  if (letter == 'H') {
    pitch = 11;
  } else if (_letterPitch.containsKey(letter)) {
    pitch = _letterPitch[letter]!;
    if (germanInput && letter == 'B') pitch = 10;
  } else {
    return null;
  }
  var consumed = 1;
  var preferFlat = germanInput && letter == 'B';
  if (input.length > 1) {
    final acc = input[1];
    if (acc == '#' || acc == '♯') {
      pitch += 1;
      consumed = 2;
      preferFlat = false;
    } else if (acc == 'b' || acc == '♭') {
      pitch -= 1;
      consumed = 2;
      preferFlat = true;
    } else {
      // German/Dutch note names: Cis, Fis (sharp), Des, Bes, As, Es (flat).
      // "sus" must not be read as a flat (Asus, Esus).
      final rest = input.substring(1);
      if (rest.startsWith('is') && !rest.startsWith('isu')) {
        pitch += 1;
        consumed = 3;
        preferFlat = false;
      } else if (rest.startsWith('es') && !rest.startsWith('esu')) {
        pitch -= 1;
        consumed = 3;
        preferFlat = true;
      } else if ((letter == 'A' || letter == 'E') &&
          rest.startsWith('s') &&
          !rest.startsWith('su')) {
        pitch -= 1;
        consumed = 2;
        preferFlat = true;
      }
    }
  }
  return (Note(pitch % 12, preferFlat: preferFlat), consumed);
}

/// A parsed chord such as `F#m7/C#`.
class Chord {
  const Chord({required this.root, this.suffix = '', this.bass});

  final Note root;

  /// Everything after the root, e.g. `m7`, `sus4`, `maj7(#11)`.
  final String suffix;

  /// Optional bass note (slash chord).
  final Note? bass;

  /// Whether the chord quality is minor (used for keys and Nashville).
  bool get isMinor =>
      suffix.startsWith('m') && !suffix.startsWith('maj') ||
      suffix.startsWith('min') ||
      suffix.startsWith('-');

  /// Parses a chord. Returns null if [input] is not a recognisable chord
  /// (e.g. `N.C.`, `x`, annotations).
  static Chord? tryParse(String input, {bool germanInput = false}) {
    final text = input.trim();
    if (text.isEmpty) return null;
    final rootResult = parseNote(text, germanInput: germanInput);
    if (rootResult == null) return null;
    final (root, used) = rootResult;
    var rest = text.substring(used);
    Note? bass;
    final slash = rest.lastIndexOf('/');
    if (slash >= 0) {
      final bassText = rest.substring(slash + 1);
      final bassResult = parseNote(bassText, germanInput: germanInput);
      if (bassResult != null && bassResult.$2 == bassText.length) {
        bass = bassResult.$1;
        rest = rest.substring(0, slash);
      }
    }
    if (!_validSuffix.hasMatch(rest)) return null;
    return Chord(root: root, suffix: rest, bass: bass);
  }

  /// Characters allowed in a chord suffix.
  static final _validSuffix = RegExp(r'^[a-zA-Z0-9#b♯♭+\-()/°ø△^,.*]*$');

  Chord transpose(int semitones, {bool? useFlats}) => Chord(
    root: root.transpose(semitones, useFlats: useFlats),
    suffix: suffix,
    bass: bass?.transpose(semitones, useFlats: useFlats),
  );

  /// Formats the chord in the given notation.
  String format(ChordNotation notation, {bool? useFlats}) {
    final buffer = StringBuffer(root.spell(notation, useFlats: useFlats))
      ..write(suffix);
    if (bass != null) {
      buffer
        ..write('/')
        ..write(bass!.spell(notation, useFlats: useFlats));
    }
    return buffer.toString();
  }

  /// Formats the chord as a Nashville number relative to [key].
  String toNashville(Key key) {
    // The suffix is kept as written, so `Am` in A minor becomes `1m`
    // and `Am` in C major becomes `6m`.
    final buffer = StringBuffer(_degree(root.pitch, key))..write(suffix);
    if (bass != null) {
      buffer
        ..write('/')
        ..write(_degree(bass!.pitch, key));
    }
    return buffer.toString();
  }

  static const _degrees = [
    '1',
    'b2',
    '2',
    'b3',
    '3',
    '4',
    'b5',
    '5',
    'b6',
    '6',
    'b7',
    '7',
  ];

  static String _degree(int pitch, Key key) =>
      _degrees[(pitch - key.tonic.pitch) % 12];

  @override
  String toString() => format(ChordNotation.international);
}

/// Major keys usually written with flats.
const _flatMajorKeys = {5, 10, 3, 8, 1}; // F Bb Eb Ab Db (F# preferred over Gb)

/// Minor keys usually written with flats.
const _flatMinorKeys = {2, 7, 0, 5, 10, 3}; // d g c f bb eb

/// A musical key such as `G` or `Em`.
class Key {
  const Key(this.tonic, {this.minor = false});

  final Note tonic;
  final bool minor;

  static Key? tryParse(String input, {bool germanInput = false}) {
    final chord = Chord.tryParse(input, germanInput: germanInput);
    if (chord == null) return null;
    return Key(chord.root, minor: chord.isMinor);
  }

  Key transpose(int semitones) {
    final pitch = (tonic.pitch + semitones) % 12;
    return Key(Note(pitch, preferFlat: _usesFlats(pitch, minor)), minor: minor);
  }

  /// Whether chords in this key are conventionally spelled with flats.
  bool get usesFlats => _usesFlats(tonic.pitch, minor);

  static bool _usesFlats(int pitch, bool minor) =>
      minor ? _flatMinorKeys.contains(pitch) : _flatMajorKeys.contains(pitch);

  String format(ChordNotation notation) =>
      tonic.spell(notation, useFlats: usesFlats) + (minor ? 'm' : '');

  @override
  bool operator ==(Object other) =>
      other is Key && other.tonic == tonic && other.minor == minor;

  @override
  int get hashCode => Object.hash(tonic, minor);

  @override
  String toString() => format(ChordNotation.international);
}

/// Chord definitions from `{define}` and `{chord}` (chord diagrams).
library;

/// A chord diagram definition for a string or keyboard instrument.
class ChordDefinition {
  const ChordDefinition({
    required this.name,
    this.baseFret = 1,
    this.frets,
    this.fingers,
    this.keys,
    this.copy,
    this.display,
    this.diagram = true,
    this.transposable = false,
  });

  /// Chord name; for `[Am]` the brackets are removed and [transposable] set.
  final String name;

  /// First fret shown in the diagram (`base-fret`).
  final int baseFret;

  /// Fret positions from the lowest string; `null` = muted (`x`/`N`),
  /// `0` = open. Relative to [baseFret] (1 = first fret shown).
  final List<int?>? frets;

  /// Finger numbers per string; `null` = no finger.
  final List<int?>? fingers;

  /// Keyboard keys (semitones from the root), for keyboard diagrams.
  final List<int>? keys;

  /// `copy NAME`: take the diagram of another chord.
  final String? copy;

  /// `display NAME`: text shown instead of the chord name.
  final String? display;

  /// `diagram off` suppresses the diagram for this chord.
  final bool diagram;

  /// The name was written in brackets (`[Am]`): subject to transposition.
  final bool transposable;

  /// Whether this definition contains a diagram of its own.
  bool get hasShape => frets != null || keys != null;

  static final _bracketed = RegExp(r'^\[(.+)\]$');

  /// Parses the argument of `{define}` or `{chord}`, e.g.
  /// `Am base-fret 1 frets x 0 2 2 1 0 fingers 0 0 2 3 1 0`.
  static ChordDefinition? tryParse(String argument) {
    final words = argument.trim().split(RegExp(r'\s+'));
    if (words.isEmpty || words.first.isEmpty) return null;
    var name = words.first;
    var transposable = false;
    final bracketed = _bracketed.firstMatch(name);
    if (bracketed != null) {
      name = bracketed.group(1)!;
      transposable = true;
    }
    // ChordPro also accepts "name:" forms like {define: Am: base-fret …}.
    if (name.endsWith(':')) name = name.substring(0, name.length - 1);

    var baseFret = 1;
    List<int?>? frets;
    List<int?>? fingers;
    List<int>? keys;
    String? copy;
    String? display;
    var diagram = true;

    const keywords = {
      'base-fret',
      'frets',
      'fingers',
      'keys',
      'copy',
      'copyall',
      'display',
      'format',
      'diagram',
    };
    var i = 1;
    List<String> valuesAfter() {
      final values = <String>[];
      while (i < words.length && !keywords.contains(words[i].toLowerCase())) {
        values.add(words[i]);
        i++;
      }
      return values;
    }

    while (i < words.length) {
      final keyword = words[i].toLowerCase();
      i++;
      final values = valuesAfter();
      switch (keyword) {
        case 'base-fret':
          baseFret = int.tryParse(values.firstOrNull ?? '') ?? 1;
        case 'frets':
          frets = [for (final v in values) _fret(v)];
        case 'fingers':
          fingers = [for (final v in values) _finger(v)];
        case 'keys':
          keys = [for (final v in values) ?int.tryParse(v)];
        case 'copy' || 'copyall':
          copy = values.firstOrNull;
        case 'display':
          display = values.join(' ');
        case 'diagram':
          diagram = (values.firstOrNull ?? 'on').toLowerCase() != 'off';
        default:
          break;
      }
    }
    return ChordDefinition(
      name: name,
      baseFret: baseFret,
      frets: frets,
      fingers: fingers,
      keys: keys,
      copy: copy,
      display: display,
      diagram: diagram,
      transposable: transposable,
    );
  }

  static int? _fret(String v) {
    final lower = v.toLowerCase();
    if (lower == 'x' || lower == 'n' || lower == '-1') return null;
    return int.tryParse(v);
  }

  static int? _finger(String v) {
    final n = int.tryParse(v);
    return n == null || n == 0 ? null : n;
  }
}

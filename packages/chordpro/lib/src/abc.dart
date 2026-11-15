/// ABC music notation (`{start_of_abc}`, ADR-0012): parser, accidentals
/// and transposition. Covers single-voice tunes: header fields, notes,
/// rests, chords, durations, broken rhythm, tuplets, ties, bar lines,
/// voltas, chord symbols, annotations, inline fields and lyrics (`w:`).
library;

import 'chord.dart';

const _letters = 'CDEFGAB';
const _naturalPc = [0, 2, 4, 5, 7, 9, 11];

/// Order in which sharps are added to key signatures (F C G D A E B).
const _sharpOrder = [3, 0, 4, 1, 5, 2, 6];

/// A key (signature) of a tune.
class AbcKey {
  const AbcKey({required this.fifths, this.tonic = 'C', this.mode = ''});

  /// Number of sharps (positive) or flats (negative), −7 … 7.
  final int fifths;

  /// Tonic as written, e.g. `G`, `Bb`, `F#`.
  final String tonic;

  /// Mode suffix as written (`m`, `dor`, `mix`, …), empty for major.
  final String mode;

  static const _modeOffsets = {
    '': 0,
    'maj': 0,
    'major': 0,
    'ion': 0,
    'm': -3,
    'min': -3,
    'minor': -3,
    'aeo': -3,
    'dor': -2,
    'phr': -4,
    'lyd': 1,
    'mix': -1,
    'loc': -5,
  };

  static const _tonicFifths = {
    'C': 0,
    'G': 1,
    'D': 2,
    'A': 3,
    'E': 4,
    'B': 5,
    'F#': 6,
    'C#': 7,
    'F': -1,
    'Bb': -2,
    'Eb': -3,
    'Ab': -4,
    'Db': -5,
    'Gb': -6,
    'Cb': -7,
    'G#': 8,
    'D#': 9,
    'A#': 10,
    'E#': 11,
    'Fb': -8,
  };

  /// Parses the value of a `K:` field (clef and other settings ignored).
  static AbcKey parse(String value) {
    final m = _keyPattern.firstMatch(value);
    if (m == null || value.trim().toLowerCase().startsWith('none')) {
      return const AbcKey(fifths: 0);
    }
    final tonic = '${m.group(1)!.toUpperCase()}${m.group(2)}';
    final modeWord = m.group(3)!.toLowerCase();
    final mode = modeWord.startsWith('m') && modeWord.length <= 1
        ? 'm'
        : modeWord.length >= 3
        ? modeWord.substring(0, 3)
        : modeWord;
    final offset = _modeOffsets[mode] ?? _modeOffsets[modeWord] ?? 0;
    var fifths = (_tonicFifths[tonic] ?? 0) + offset;
    if (fifths > 7) fifths -= 12;
    if (fifths < -7) fifths += 12;
    return AbcKey(
      fifths: fifths,
      tonic: tonic,
      mode: mode == 'maj' ? '' : mode,
    );
  }

  /// Alteration of [letter] (0 = C … 6 = B) in this key signature.
  int alterationOf(int letter) {
    if (fifths > 0) {
      return _sharpOrder.take(fifths).contains(letter) ? 1 : 0;
    }
    if (fifths < 0) {
      return _sharpOrder.reversed.take(-fifths).contains(letter) ? -1 : 0;
    }
    return 0;
  }

  /// Letters with an accidental in the signature, in drawing order.
  List<int> get signatureLetters => fifths >= 0
      ? _sharpOrder.take(fifths).toList()
      : _sharpOrder.reversed.take(-fifths).toList();

  bool get isMinorLike => mode == 'm' || mode == 'min' || mode == 'aeo';

  /// This key transposed by [semitones] (same mode).
  AbcKey transpose(int semitones, {bool? preferFlats}) {
    if (semitones % 12 == 0) return this;
    var fifths = this.fifths + semitones * 7;
    fifths = ((fifths + 6) % 12 + 12) % 12 - 6; // −6 … 5
    if (fifths == -6 && preferFlats == false) fifths = 6;
    if (fifths == 5 && preferFlats == true) fifths = -7;
    final majorFifths = fifths - (_modeOffsets[mode] ?? 0);
    var tonic = 'C';
    _tonicFifths.forEach((name, f) {
      if (f == majorFifths) tonic = name;
    });
    // Use the tonic of the mode: shift the major tonic accordingly.
    final tonicKey = Key.tryParse(this.tonic);
    if (tonicKey != null) {
      final transposed = tonicKey.transpose(semitones);
      tonic = transposed.tonic.spell(
        ChordNotation.international,
        useFlats: fifths < 0,
      );
    }
    return AbcKey(fifths: fifths, tonic: tonic, mode: mode);
  }

  /// Field value for display, e.g. `G`, `Em`, `Ddor`.
  String get name => '$tonic$mode';
}

/// A pitch: diatonic [step] (0 = C4 = middle C, 7 = C5) and absolute
/// [alter]ation in semitones (−2 … 2).
class AbcPitch {
  const AbcPitch(this.step, this.alter);

  final int step;
  final int alter;

  int get letter => ((step % 7) + 7) % 7;

  int get octave => (step - letter) ~/ 7;

  /// MIDI note number.
  int get midi => 60 + 12 * octave + _naturalPc[letter] + alter;

  @override
  bool operator ==(Object other) =>
      other is AbcPitch && other.step == step && other.alter == alter;

  @override
  int get hashCode => Object.hash(step, alter);

  /// Scientific pitch notation, e.g. `C4` for middle C, `F5#`.
  @override
  String toString() =>
      '${_letters[letter]}${octave + 4}${'#' * (alter > 0 ? alter : 0)}${'b' * (alter < 0 ? -alter : 0)}';
}

/// An element of a music line.
sealed class AbcElement {
  const AbcElement();
}

/// A note or a chord of notes.
class AbcNote extends AbcElement {
  AbcNote({
    required this.pitches,
    required this.duration,
    this.tie = false,
    this.chordSymbol,
    this.annotations = const [],
    this.spaceBefore = false,
    this.tuplet,
  });

  final List<AbcPitch> pitches;

  /// Duration as a fraction of a whole note.
  double duration;
  bool tie;

  /// Chord symbol above the note (`"G"`).
  String? chordSymbol;

  /// Text annotations (`"^text"`).
  final List<String> annotations;

  /// A space before this note breaks beaming.
  final bool spaceBefore;

  /// Tuplet number shown above a group (on its first note).
  int? tuplet;

  /// Lyric syllable below the note (from `w:`).
  String? lyric;

  /// Accidentals to draw per pitch (null = none), see [applyAccidentals].
  List<int?> shownAccidentals = const [];
}

/// A rest; [invisible] for `x`.
class AbcRest extends AbcElement {
  AbcRest({
    required this.duration,
    this.invisible = false,
    this.spaceBefore = false,
    this.chordSymbol,
  });

  double duration;
  final bool invisible;
  final bool spaceBefore;
  String? chordSymbol;
}

/// A bar line: `|`, `||`, `|]`, `[|`, `|:`, `:|`, `::`, with an optional
/// volta number (`[1`, `:|2`).
class AbcBar extends AbcElement {
  const AbcBar(this.type, {this.volta});

  final String type;
  final int? volta;
}

/// A key change in the middle of the music (`[K:…]`).
class AbcKeyChange extends AbcElement {
  const AbcKeyChange(this.key);

  final AbcKey key;
}

/// A meter change in the middle of the music (`[M:…]`).
class AbcMeterChange extends AbcElement {
  const AbcMeterChange(this.meter);

  final String meter;
}

/// One line of music (one staff line).
class AbcLine {
  AbcLine(this.elements);

  final List<AbcElement> elements;
}

/// A parsed ABC tune.
class AbcTune {
  AbcTune({
    required this.fields,
    required this.key,
    required this.meter,
    required this.lines,
    this.bassClef = false,
  });

  /// Header fields by letter, e.g. `T` → titles.
  final Map<String, List<String>> fields;
  final AbcKey key;

  /// Meter as written (`4/4`, `C`, `C|`, `6/8`), empty for none.
  final String meter;
  final List<AbcLine> lines;
  final bool bassClef;

  String? get title => fields['T']?.firstOrNull;
}

/// Parses an ABC tune.
AbcTune parseAbc(String source) => _AbcParser(source).parse();

// Patterns of the parser, compiled once. Patterns used at a position of a
// line are matched with matchAsPrefix(text, i), without copying the rest
// of the line.
final _keyPattern = RegExp(r'^\s*([A-Ga-g])([#b]?)\s*([A-Za-z]*)');
final _headerPattern = RegExp(r'^([A-Za-z]):\s?(.*)$');
final _bassClefPattern = RegExp(r'clef\s*=\s*bass|\bbass\b');
final _fractionPattern = RegExp(r'^\s*(\d+)\s*/\s*(\d+)');
final _durationPattern = RegExp(r'(\d*)(/*)(\d*)');
final _pitchPattern = RegExp(r"(\^\^|\^|__|_|=)?([A-Ga-g])([,']*)");
final _decoratedPattern = RegExp(r'[\^_=A-Ga-g\[]');
final _inlineFieldPattern = RegExp(r'\[([KML]):([^\]]*)\]');
final _barPattern = RegExp(
  r'(:\|:|:\|\]|\|\]|\[\||:\||\|:|::|\|\||\|)(\d)?|\[(\d)',
);
final _tupletPattern = RegExp(r'\((\d)(?::(\d)?)?(?::(\d))?');
final _brokenPattern = RegExp(r'>+|<+');

class _AbcParser {
  _AbcParser(this.source);

  final String source;
  final fields = <String, List<String>>{};
  var key = const AbcKey(fifths: 0);
  var meter = '4/4';
  double? unit;
  var bassClef = false;
  final lines = <AbcLine>[];

  AbcTune parse() {
    var inBody = false;
    AbcLine? lastMusic;
    final pending = StringBuffer();
    for (final raw in source.replaceAll('\r', '').split('\n')) {
      var line = raw;
      final comment = line.indexOf('%');
      if (comment >= 0 && !line.startsWith('%%')) {
        line = line.substring(0, comment);
      }
      if (line.trim().isEmpty || line.startsWith('%%')) continue;
      final header = _headerPattern.firstMatch(line);
      if (header != null && !(inBody && header.group(1) == 'w')) {
        final name = header.group(1)!;
        final value = header.group(2)!.trim();
        if (name == 'w' || name == 'W') {
          if (name == 'w' && lastMusic != null) _lyrics(lastMusic, value);
          continue;
        }
        fields.putIfAbsent(name, () => []).add(value);
        switch (name) {
          case 'K':
            key = AbcKey.parse(value);
            bassClef = _bassClefPattern.hasMatch(value);
            inBody = true;
          case 'M':
            meter = value;
          case 'L':
            unit = _fraction(value);
        }
        continue;
      }
      if (header != null && header.group(1) == 'w') {
        if (lastMusic != null) _lyrics(lastMusic, header.group(2)!.trim());
        continue;
      }
      // Music line; a trailing backslash continues the line.
      final text = line.trimRight();
      if (text.endsWith(r'\')) {
        pending.write(text.substring(0, text.length - 1));
        continue;
      }
      pending.write(text);
      lastMusic = _music(pending.toString());
      lines.add(lastMusic);
      pending.clear();
    }
    if (pending.isNotEmpty) lines.add(_music(pending.toString()));
    final result = AbcTune(
      fields: fields,
      key: _initialKey ?? key,
      meter: _initialMeter ?? meter,
      lines: lines,
      bassClef: bassClef,
    );
    applyAccidentals(result);
    return result;
  }

  AbcKey? _initialKey;
  String? _initialMeter;

  double get _unit {
    if (unit != null) return unit!;
    final m = _fraction(meter == 'C' || meter == 'C|' ? '4/4' : meter);
    return m != null && m < 0.75 ? 1 / 16 : 1 / 8;
  }

  static double? _fraction(String text) {
    final m = _fractionPattern.firstMatch(text);
    if (m == null) return null;
    return int.parse(m.group(1)!) / int.parse(m.group(2)!);
  }

  AbcLine _music(String text) {
    _initialKey ??= key;
    _initialMeter ??= meter;
    final elements = <AbcElement>[];
    var i = 0;
    String? chordSymbol;
    final annotations = <String>[];
    var space = false;
    var brokenNext = 1.0;
    var tupletLeft = 0;
    var tupletFactor = 1.0;
    int? tupletNumber;
    // Accidentals carried through the current measure: step → alteration.
    final measure = <int, int>{};

    double readDuration() {
      var num = 1.0;
      var den = 1.0;
      final m = _durationPattern.matchAsPrefix(text, i)!;
      if (m.group(1)!.isNotEmpty) num = double.parse(m.group(1)!);
      final slashes = m.group(2)!.length;
      if (slashes > 0) {
        den = m.group(3)!.isNotEmpty
            ? double.parse(m.group(3)!)
            : (1 << slashes).toDouble();
      }
      i += m.group(0)!.length;
      return num / den;
    }

    AbcPitch? readPitch() {
      final m = _pitchPattern.matchAsPrefix(text, i);
      if (m == null) return null;
      i += m.group(0)!.length;
      final letterChar = m.group(2)!;
      final letter = _letters.indexOf(letterChar.toUpperCase());
      var step = letter + (letterChar == letterChar.toLowerCase() ? 7 : 0);
      for (final c in m.group(3)!.split('')) {
        step += c == "'" ? 7 : -7;
      }
      final acc = m.group(1);
      int alter;
      if (acc != null) {
        alter = switch (acc) {
          '^^' => 2,
          '^' => 1,
          '__' => -2,
          '_' => -1,
          _ => 0,
        };
        measure[step] = alter;
      } else {
        alter = measure[step] ?? key.alterationOf(letter);
      }
      return AbcPitch(step, alter);
    }

    void addTimed(AbcElement e, double duration) {
      var d = duration * brokenNext;
      brokenNext = 1;
      if (tupletLeft > 0) {
        d *= tupletFactor;
        tupletLeft--;
      }
      switch (e) {
        case AbcNote n:
          n.duration = d;
          if (tupletNumber != null) {
            n.tuplet = tupletNumber;
            tupletNumber = null;
          }
        case AbcRest r:
          r.duration = d;
        default:
          break;
      }
      elements.add(e);
    }

    void applyBroken(String symbol) {
      final last = elements.lastWhere(
        (e) => e is AbcNote || e is AbcRest,
        orElse: () => const AbcBar(''),
      );
      final count = symbol.length;
      final factor = 1 - 1 / (1 << count); // > : 1/2, >> : 3/4
      if (symbol.startsWith('>')) {
        if (last is AbcNote) last.duration *= 1 + factor;
        if (last is AbcRest) last.duration *= 1 + factor;
        brokenNext = 1 - factor;
      } else {
        if (last is AbcNote) last.duration *= 1 - factor;
        if (last is AbcRest) last.duration *= 1 - factor;
        brokenNext = 1 + factor;
      }
    }

    while (i < text.length) {
      final c = text[i];

      if (c == ' ' || c == '\t') {
        space = true;
        i++;
        continue;
      }
      if (c == '"') {
        final end = text.indexOf('"', i + 1);
        if (end < 0) break;
        final content = text.substring(i + 1, end);
        i = end + 1;
        if (content.isNotEmpty && '^_<>@'.contains(content[0])) {
          annotations.add(content.substring(1));
        } else {
          chordSymbol = content;
        }
        continue;
      }
      if (c == '!' || c == '+') {
        final end = text.indexOf(c, i + 1);
        i = end < 0 ? text.length : end + 1; // decorations ignored
        continue;
      }
      if ('~.HLMOPST'.contains(c) &&
          i + 1 < text.length &&
          _decoratedPattern.hasMatch(text[i + 1])) {
        i++; // Short decorations are ignored.
        continue;
      }
      // Inline fields [K:…], [M:…], [L:…].
      final inline = _inlineFieldPattern.matchAsPrefix(text, i);
      if (inline != null) {
        i += inline.group(0)!.length;
        final value = inline.group(2)!.trim();
        switch (inline.group(1)) {
          case 'K':
            key = AbcKey.parse(value);
            measure.clear();
            elements.add(AbcKeyChange(key));
          case 'M':
            meter = value;
            elements.add(AbcMeterChange(value));
          case 'L':
            unit = _fraction(value);
        }
        continue;
      }
      // Bar lines and voltas.
      final bar = _barPattern.matchAsPrefix(text, i);
      if (bar != null) {
        i += bar.group(0)!.length;
        final volta = int.tryParse(bar.group(2) ?? bar.group(3) ?? '');
        elements.add(AbcBar(bar.group(1) ?? '', volta: volta));
        measure.clear();
        space = false;
        continue;
      }
      if (c == '(') {
        final tuplet = _tupletPattern.matchAsPrefix(text, i);
        if (tuplet != null) {
          i += tuplet.group(0)!.length;
          final p = int.parse(tuplet.group(1)!);
          final defaultQ = switch (p) {
            2 || 4 || 8 => 3,
            3 || 6 => 2,
            _ => meter.contains('/8') && !meter.startsWith('2') ? 3 : 2,
          };
          final q = int.tryParse(tuplet.group(2) ?? '') ?? defaultQ;
          tupletFactor = q / p;
          tupletLeft = int.tryParse(tuplet.group(3) ?? '') ?? p;
          tupletNumber = p;
          continue;
        }
        i++; // slur start
        continue;
      }
      if (c == ')') {
        i++;
        continue;
      }
      if (c == '-') {
        final last = elements.whereType<AbcNote>().lastOrNull;
        last?.tie = true;
        i++;
        continue;
      }
      if (c == '>' || c == '<') {
        final m = _brokenPattern.matchAsPrefix(text, i)!;
        i += m.group(0)!.length;
        applyBroken(m.group(0)!);
        continue;
      }
      if (c == 'z' || c == 'x' || c == 'Z' || c == 'X') {
        i++;
        final d = readDuration();
        final r = AbcRest(
          duration: 0,
          invisible: c == 'x' || c == 'X',
          spaceBefore: space,
          chordSymbol: chordSymbol,
        );
        addTimed(r, (c == 'Z' || c == 'X') ? _barLength() * d : _unit * d);
        chordSymbol = null;
        annotations.clear();
        space = false;
        continue;
      }
      if (c == '[') {
        // Chord of notes [CEG]2.
        final close = text.indexOf(']', i);
        if (close > i) {
          i++;
          final pitches = <AbcPitch>[];
          var inner = 1.0;
          while (i < close) {
            final p = readPitch();
            if (p == null) {
              i++;
              continue;
            }
            pitches.add(p);
            inner = readDuration();
          }
          i = close + 1;
          final outer = readDuration();
          if (pitches.isNotEmpty) {
            final note = AbcNote(
              pitches: pitches,
              duration: 0,
              chordSymbol: chordSymbol,
              annotations: [...annotations],
              spaceBefore: space,
            );
            addTimed(note, _unit * inner * outer);
          }
          chordSymbol = null;
          annotations.clear();
          space = false;
          continue;
        }
      }
      final pitch = readPitch();
      if (pitch != null) {
        final note = AbcNote(
          pitches: [pitch],
          duration: 0,
          chordSymbol: chordSymbol,
          annotations: [...annotations],
          spaceBefore: space,
        );
        addTimed(note, _unit * readDuration());
        chordSymbol = null;
        annotations.clear();
        space = false;
        continue;
      }
      i++; // Unknown character.
    }
    return AbcLine(elements);
  }

  double _barLength() {
    final m = _fraction(meter == 'C' || meter == 'C|' ? '4/4' : meter);
    return m ?? 1;
  }

  /// Assigns `w:` syllables to the notes of [line].
  void _lyrics(AbcLine line, String text) {
    final syllables = <String>[];
    final buffer = StringBuffer();
    for (var k = 0; k < text.length; k++) {
      final ch = text[k];
      if (ch == ' ') {
        if (buffer.isNotEmpty) syllables.add(buffer.toString());
        buffer.clear();
      } else if (ch == '-') {
        buffer.write('-');
        syllables.add(buffer.toString());
        buffer.clear();
      } else if (ch == '*' || ch == '_') {
        if (buffer.isNotEmpty) syllables.add(buffer.toString());
        buffer.clear();
        syllables.add('');
      } else if (ch == '|') {
        if (buffer.isNotEmpty) syllables.add(buffer.toString());
        buffer.clear();
      } else if (ch == '~') {
        buffer.write(' ');
      } else if (ch == r'\' && k + 1 < text.length) {
        buffer.write(text[++k]);
      } else {
        buffer.write(ch);
      }
    }
    if (buffer.isNotEmpty) syllables.add(buffer.toString());
    final notes = line.elements.whereType<AbcNote>().toList();
    for (var k = 0; k < notes.length && k < syllables.length; k++) {
      final s = syllables[k];
      notes[k].lyric = s.isEmpty ? null : s;
    }
  }
}

/// Computes which accidentals must be drawn: an accidental is shown when a
/// note's alteration differs from the key signature or from an earlier note
/// on the same step in the same measure.
void applyAccidentals(AbcTune tune) {
  var key = tune.key;
  for (final line in tune.lines) {
    final measure = <int, int>{};
    for (final e in line.elements) {
      switch (e) {
        case AbcBar():
          measure.clear();
        case AbcKeyChange k:
          key = k.key;
          measure.clear();
        case AbcNote n:
          n.shownAccidentals = [
            for (final p in n.pitches)
              () {
                final expected = measure[p.step] ?? key.alterationOf(p.letter);
                measure[p.step] = p.alter;
                return p.alter == expected ? null : p.alter;
              }(),
          ];
        default:
          break;
      }
    }
  }
}

/// Transposes [tune] by [semitones]: key signature, notes (respelled in
/// the new key) and chord symbols.
AbcTune transposeAbc(AbcTune tune, int semitones, {bool? preferFlats}) {
  if (semitones == 0) return tune;
  var key = tune.key.transpose(semitones, preferFlats: preferFlats);
  final newKey = key;
  String? chord(String? symbol) {
    if (symbol == null) return null;
    final c = Chord.tryParse(symbol);
    if (c == null) return symbol;
    return c
        .transpose(semitones, useFlats: key.fifths < 0)
        .format(ChordNotation.international);
  }

  final lines = <AbcLine>[];
  for (final line in tune.lines) {
    final elements = <AbcElement>[];
    for (final e in line.elements) {
      switch (e) {
        case AbcNote n:
          final note = AbcNote(
            pitches: [
              for (final p in n.pitches) _respell(p.midi + semitones, key),
            ],
            duration: n.duration,
            tie: n.tie,
            chordSymbol: chord(n.chordSymbol),
            annotations: n.annotations,
            spaceBefore: n.spaceBefore,
            tuplet: n.tuplet,
          )..lyric = n.lyric;
          elements.add(note);
        case AbcRest r:
          elements.add(
            AbcRest(
              duration: r.duration,
              invisible: r.invisible,
              spaceBefore: r.spaceBefore,
              chordSymbol: chord(r.chordSymbol),
            ),
          );
        case AbcKeyChange k:
          key = k.key.transpose(semitones, preferFlats: preferFlats);
          elements.add(AbcKeyChange(key));
        default:
          elements.add(e);
      }
    }
    lines.add(AbcLine(elements));
  }
  final result = AbcTune(
    fields: tune.fields,
    key: newKey,
    meter: tune.meter,
    lines: lines,
    bassClef: tune.bassClef,
  );
  applyAccidentals(result);
  return result;
}

/// Spells MIDI note [midi] in [key]: scale tones without accidental,
/// other tones with the accidental that suits the key.
AbcPitch _respell(int midi, AbcKey key) {
  final pc = midi % 12;
  int? bestLetter;
  int? bestAlter;
  var bestCost = 99;
  for (var letter = 0; letter < 7; letter++) {
    var alter = pc - _naturalPc[letter];
    if (alter > 6) alter -= 12;
    if (alter < -6) alter += 12;
    if (alter.abs() > 2) continue;
    final signature = key.alterationOf(letter);
    var cost = alter == signature ? 0 : 2 + alter.abs();
    if (alter != signature) {
      // Prefer sharps in sharp keys and flats in flat keys.
      if (key.fifths >= 0 && alter < 0) cost += 1;
      if (key.fifths < 0 && alter > 0) cost += 1;
    }
    if (cost < bestCost) {
      bestCost = cost;
      bestLetter = letter;
      bestAlter = alter;
    }
  }
  final letter = bestLetter!;
  final alter = bestAlter!;
  // midi − alter − natural pitch is an exact multiple of 12.
  final octave = (midi - alter - 60 - _naturalPc[letter]) ~/ 12;
  return AbcPitch(letter + 7 * octave, alter);
}

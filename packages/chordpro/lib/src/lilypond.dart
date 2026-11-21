/// LilyPond notation (`{start_of_ly}`, ADR-0012): a subset of LilyPond for
/// single-voice lead sheets. LilyPond itself is an external program that
/// does not run on tablets, so setDING reads the common lead-sheet syntax
/// itself and converts it to the ABC tune model: the ABC engraver draws it
/// and it follows the set transposition like ABC.
///
/// Supported: `\relative`, `\fixed` and absolute pitches; Dutch, German and
/// English note names; durations with dots and multipliers; rests, spacers
/// and full-measure rests; chords `<…>` and `q`; ties, slurs and beams;
/// `\key`, `\time`, `\partial`, `\clef`, `\bar`, `\break`, `\cadenzaOn`;
/// `\repeat volta` with `\alternative`, `\repeat unfold`; `\tuplet` and
/// `\times`; variables; `\header { title }`; lyrics (`\addlyrics`,
/// `\lyricsto`); chord names from `\chordmode` / `\chords` above the melody;
/// text scripts (`^"…"`). Layout settings (`\override`, `\set`, `\layout`,
/// `\paper`, Scheme values) are ignored. Grace notes are not drawn.
///
/// Music outside the subset (several voices or staves, `\transpose`,
/// unknown note names or languages) makes [parseLilypond] return null, and
/// the app shows the source instead.
library;

import 'abc.dart';

const _names = 'CDEFGAB';

/// Parses LilyPond [source] into an ABC tune; null when it uses features
/// outside the supported subset or contains no notes.
AbcTune? parseLilypond(String source) {
  try {
    return _LyParser(_expandVariables(_stripComments(source))).parse();
  } on _Unsupported {
    return null;
  } on FormatException {
    return null;
  }
}

class _Unsupported implements Exception {
  const _Unsupported();
}

bool _isLetter(String c) {
  if (c.isEmpty) return false;
  final u = c.codeUnitAt(0) | 0x20;
  return u >= 0x61 && u <= 0x7a;
}

bool _isDigit(String c) =>
    c.isNotEmpty && c.codeUnitAt(0) >= 0x30 && c.codeUnitAt(0) <= 0x39;

bool _isSpace(String c) => c == ' ' || c == '\t' || c == '\n' || c == '\r';

/// Removes `% line` and `%{ block %}` comments outside strings.
String _stripComments(String s) {
  final out = StringBuffer();
  var i = 0;
  while (i < s.length) {
    final c = s[i];
    if (c == '"') {
      final end = _stringEnd(s, i);
      out.write(s.substring(i, end));
      i = end;
    } else if (c == '%') {
      if (i + 1 < s.length && s[i + 1] == '{') {
        final end = s.indexOf('%}', i + 2);
        i = end < 0 ? s.length : end + 2;
        out.write(' ');
      } else {
        final end = s.indexOf('\n', i);
        i = end < 0 ? s.length : end;
      }
    } else {
      out.write(c);
      i++;
    }
  }
  return out.toString();
}

/// Index after the string literal starting at [i] (a `"`).
int _stringEnd(String s, int i) {
  var k = i + 1;
  while (k < s.length) {
    if (s[k] == r'\') {
      k += 2;
      continue;
    }
    if (s[k] == '"') return k + 1;
    k++;
  }
  return s.length;
}

/// Index after the block that starts with [open] at [i] and ends with the
/// matching [close] (`{…}`, `<<…>>`, `(…)`); strings are skipped.
int _blockEnd(String s, int i, String open, String close) {
  var depth = 0;
  var k = i;
  while (k < s.length) {
    if (s[k] == '"') {
      k = _stringEnd(s, k);
      continue;
    }
    if (s.startsWith(open, k)) {
      depth++;
      k += open.length;
    } else if (s.startsWith(close, k)) {
      depth--;
      k += close.length;
      if (depth == 0) return k;
    } else {
      k++;
    }
  }
  return s.length;
}

/// Index after the Scheme value starting at [i] (a `#`).
int _schemeEnd(String s, int i) {
  var k = i + 1;
  if (k < s.length && s[k] == '#') k++;
  while (k < s.length && (s[k] == "'" || s[k] == '`')) {
    k++;
  }
  if (k >= s.length) return k;
  if (s[k] == '(') return _blockEnd(s, k, '(', ')');
  if (s[k] == '"') return _stringEnd(s, k);
  while (k < s.length && !_isSpace(s[k]) && !'{}<>()'.contains(s[k])) {
    k++;
  }
  return k;
}

/// Index after the value of a variable assignment starting at [i].
int _expressionEnd(String s, int i) {
  var k = i;
  while (k < s.length && _isSpace(s[k])) {
    k++;
  }
  if (k >= s.length) return k;
  if (s[k] == '"') return _stringEnd(s, k);
  if (s[k] == '#') return _schemeEnd(s, k);
  if (_isDigit(s[k])) {
    while (k < s.length && !_isSpace(s[k])) {
      k++;
    }
    return k;
  }
  // Music: commands and words up to the first block.
  while (k < s.length) {
    if (s[k] == '{') return _blockEnd(s, k, '{', '}');
    if (s.startsWith('<<', k)) return _blockEnd(s, k, '<<', '>>');
    if (s[k] == '"') {
      k = _stringEnd(s, k);
      continue;
    }
    k++;
  }
  return k;
}

final _assignPattern = RegExp(r'([A-Za-z]+)\s*=(?!=)');
final _referencePattern = RegExp(r'\\([A-Za-z]+)(?![A-Za-z])');

/// Whether only spaces precede [i] on its line.
bool _atLineStart(String s, int i) {
  for (var k = i - 1; k >= 0 && s[k] != '\n'; k--) {
    if (s[k] != ' ' && s[k] != '\t') return false;
  }
  return true;
}

/// Removes top-level variable definitions (`melody = \relative c' {…}`) and
/// replaces their uses (`\melody`) with their value.
String _expandVariables(String s) {
  final vars = <String, String>{};
  final out = StringBuffer();
  var i = 0;
  var depth = 0;
  while (i < s.length) {
    final c = s[i];
    if (c == '"') {
      final end = _stringEnd(s, i);
      out.write(s.substring(i, end));
      i = end;
      continue;
    }
    if (depth == 0 && _isLetter(c) && _atLineStart(s, i)) {
      final m = _assignPattern.matchAsPrefix(s, i);
      if (m != null) {
        final end = _expressionEnd(s, m.end);
        vars[m.group(1)!] = s.substring(m.end, end);
        i = end;
        continue;
      }
    }
    if (c == '{' || s.startsWith('<<', i)) depth++;
    if (c == '}' || s.startsWith('>>', i)) depth--;
    final step = s.startsWith('<<', i) || s.startsWith('>>', i) ? 2 : 1;
    out.write(s.substring(i, i + step));
    i += step;
  }
  var text = out.toString();
  for (var round = 0; round < 10 && vars.isNotEmpty; round++) {
    var changed = false;
    text = text.replaceAllMapped(_referencePattern, (m) {
      final value = vars[m.group(1)!];
      if (value == null) return m.group(0)!;
      changed = true;
      return ' $value ';
    });
    if (!changed) break;
    if (text.length > 200000) throw const _Unsupported();
  }
  return text;
}

enum _Lang { nederlands, deutsch, english }

typedef _Pitch = ({int letter, int alter});

class _Tuplet {
  _Tuplet(this.factor, this.number, this.span);

  final double factor;
  final int number;

  /// Length of each tuplet group (`\tuplet 3/2 4 {…}`), null for one group.
  final double? span;

  /// Duration of the notes so far.
  var done = 0.0;
}

class _Repeat {
  var alternatives = false;
}

typedef _PostEvents = ({
  bool tie,
  bool slurStart,
  bool slurEnd,
  bool beamStart,
  bool beamEnd,
  List<String> annotations,
});

const _modes = {
  'major': '',
  'ionian': '',
  'minor': 'm',
  'aeolian': 'm',
  'dorian': 'dor',
  'phrygian': 'phr',
  'lydian': 'lyd',
  'mixolydian': 'mix',
  'locrian': 'loc',
};

/// Context types whose music is not part of the melody.
const _skippedContexts = {
  'TabStaff',
  'TabVoice',
  'DrumStaff',
  'DrumVoice',
  'RhythmicStaff',
  'FiguredBass',
  'Dynamics',
  'NoteNames',
  'FretBoards',
};

/// Commands that would change the music in ways the subset cannot show.
const _unsupportedCommands = {
  'transpose',
  'partCombine',
  'partcombine',
  'parallelMusic',
  'change',
  'simultaneous',
  'autoChange',
};

/// Commands attached to a note after its duration (articulations,
/// dynamics, spanners).
const _postCommands = {
  'fermata', 'accent', 'staccato', 'staccatissimo', 'tenuto', 'portato', //
  'marcato', 'espressivo', 'trill', 'prall', 'mordent', 'turn', 'upbow',
  'downbow', 'open', 'stopped', 'flageolet', 'snappizzicato', 'segno',
  'coda', 'varcoda', 'arpeggio', 'glissando', 'laissezVibrer', 'repeatTie',
  'p', 'pp', 'ppp', 'pppp', 'mp', 'mf', 'f', 'ff', 'fff', 'ffff', 'fp',
  'sf', 'sff', 'sfz', 'sp', 'spp', 'rfz', 'cresc', 'decresc', 'dim',
  'startTrillSpan', 'stopTrillSpan', 'sustainOn', 'sustainOff',
};

final _timePattern = RegExp(r'(?:\d+(?:,\d+)+\s+)?(\d+)\s*/\s*(\d+)');
final _fractionPattern = RegExp(r'(\d+)\s*/\s*(\d+)');
final _chordModPattern = RegExp(r'[0-9a-z.+\-^]*');
final _titlePattern = RegExp(r'(?:^|\s)title\s*=\s*"((?:[^"\\]|\\.)*)"');
final _durationSuffix = RegExp(r'\d+\.*$');

class _LyParser {
  _LyParser(this.t);

  final String t;
  var i = 0;

  var _lang = _Lang.nederlands;

  /// Reference step in `\relative` mode, null otherwise.
  int? _relStep;

  /// Step of the unmarked `c` in absolute and `\fixed` mode (C3 = −7).
  var _fixedBase = -7;
  var _duration = 0.25;
  var _chordDuration = 0.25;
  List<AbcPitch> _lastChord = const [];
  final _tuplets = <_Tuplet>[];
  final _repeats = <_Repeat>[];

  /// Inside grace notes: pitches are read, nothing is drawn.
  var _discard = 0;

  // Output.
  final _lines = <List<AbcElement>>[[]];
  final _timed = <({double time, AbcElement element})>[];

  /// Notes that get no syllable (inside slurs, after ties).
  final _melisma = <AbcNote>{};
  final _chords = <({double time, String symbol})>[];
  List<String?>? _syllables;
  String? _title;

  // Notation state.
  var _time = 0.0;
  var _pos = 0.0;
  var _measure = 1.0;
  var _beat = 0.25;
  double? _partial;
  var _cadenza = false;
  var _numericTime = false;
  AbcKey? _initialKey;
  String? _initialMeter;
  var _bassClef = false;
  var _inSlur = false;
  var _tieOpen = false;
  var _beamOpen = false;
  var _beamEnded = false;

  List<AbcElement> get _line => _lines.last;

  bool get _started => _timed.isNotEmpty;

  bool get _end => i >= t.length;

  String get _c => i < t.length ? t[i] : '';

  bool _at(String s) => t.startsWith(s, i);

  void _ws() {
    while (i < t.length && _isSpace(t[i])) {
      i++;
    }
  }

  String _word() {
    final start = i;
    while (i < t.length && _isLetter(t[i])) {
      i++;
    }
    return t.substring(start, i);
  }

  /// End of the `{…}` block at the current position; it must be closed.
  int _closedBlockEnd() {
    final end = _blockEnd(t, i, '{', '}');
    if (end - 1 <= i || t[end - 1] != '}') throw const _Unsupported();
    return end;
  }

  int? _int() {
    final start = i;
    while (i < t.length && _isDigit(t[i])) {
      i++;
    }
    return start == i ? null : int.parse(t.substring(start, i));
  }

  String _string() {
    if (_c != '"') throw const _Unsupported();
    final end = _stringEnd(t, i);
    if (end - 1 <= i || t[end - 1] != '"') throw const _Unsupported();
    final value = t.substring(i + 1, end - 1).replaceAll(r'\"', '"');
    i = end;
    return value;
  }

  /// Reads a command after `\`: its name, or the single character of
  /// `\\`, `\(`, `\)`, `\<`, `\>`, `\!`.
  String _command() {
    i++;
    if (_end) return '';
    if (!_isLetter(_c)) return t[i++];
    return _word();
  }

  AbcTune parse() {
    while (true) {
      _ws();
      if (_end) break;
      _music();
    }
    if (!_started) throw const _Unsupported();
    _attachChords();
    _attachLyrics();
    final tune = AbcTune(
      fields: {
        if (_title != null) 'T': [_title!],
      },
      key: _initialKey ?? const AbcKey(fifths: 0),
      meter: _initialMeter ?? (_numericTime ? '4/4' : 'C'),
      lines: [
        for (final line in _lines)
          if (line.isNotEmpty) AbcLine(line),
      ],
      bassClef: _bassClef,
    );
    applyAccidentals(tune);
    return tune;
  }

  // Music ---------------------------------------------------------------------

  /// Reads one music expression.
  void _music() {
    _ws();
    if (_end) return;
    final c = _c;
    if (c == '{') {
      i++;
      _sequential();
    } else if (_at('<<')) {
      i += 2;
      _simultaneous();
    } else if (c == '<') {
      _chord();
    } else if (c == '}' || _at('>>')) {
      throw const _Unsupported();
    } else if (c == r'\') {
      _commandMusic();
    } else if (c == '#') {
      i = _schemeEnd(t, i);
    } else if (c == '"') {
      i = _stringEnd(t, i);
    } else if (_isLetter(c)) {
      _wordMusic();
    } else {
      i++; // Bar checks, stray post-events and other characters.
    }
  }

  void _sequential() {
    while (true) {
      _ws();
      if (_end) throw const _Unsupported();
      if (_c == '}') {
        i++;
        return;
      }
      _music();
    }
  }

  /// `<< … >>`: chord names and lyrics may run next to one melody.
  void _simultaneous() {
    final start = _time;
    var end = start;
    var melodies = 0;
    while (true) {
      _ws();
      if (_end) throw const _Unsupported();
      if (_at('>>')) {
        i += 2;
        break;
      }
      final before = _timed.length;
      _time = start;
      _music();
      if (_timed.length > before && ++melodies > 1) {
        throw const _Unsupported();
      }
      if (_time > end) end = _time;
    }
    _time = end;
  }

  void _commandMusic() {
    final name = _command();
    if (_unsupportedCommands.contains(name) || name == r'\') {
      throw const _Unsupported();
    }
    switch (name) {
      case 'relative':
        _ws();
        var ref = -4; // f below middle C: the first note is absolute.
        if (_atPitch) ref = _absolutePitch().step;
        _octaveMode(ref, _fixedBase);
      case 'fixed':
        _ws();
        final step = _absolutePitch().step;
        _octaveMode(null, step - step % 7);
      case 'absolute':
        _octaveMode(null, -7);
      case 'new' || 'context':
        _newContext();
      case 'score' || 'book' || 'bookpart' || 'sequential':
        _music();
      case 'header':
        _header();
      case 'layout' || 'midi' || 'paper' || 'with':
        _ws();
        if (_c == '{') i = _blockEnd(t, i, '{', '}');
      case 'version':
        _ws();
        if (_c == '"') _string();
      case 'language':
        _ws();
        _setLanguage(_string());
      case 'include':
        _ws();
        final file = _string();
        if (file.endsWith('.ly')) {
          final lang = file.substring(0, file.length - 3);
          if (_Lang.values.any((l) => l.name == lang)) _setLanguage(lang);
        }
      case 'key':
        _keyCommand();
      case 'time':
        _ws();
        final m = _timePattern.matchAsPrefix(t, i);
        if (m == null) throw const _Unsupported();
        i = m.end;
        _setMeter(int.parse(m.group(1)!), int.parse(m.group(2)!));
      case 'numericTimeSignature':
        _numericTime = true;
      case 'defaultTimeSignature':
        _numericTime = false;
      case 'partial':
        _ws();
        final d = _durationOpt() ?? (throw const _Unsupported());
        if (!_started) _partial = d;
        _pos = _measure - d;
      case 'clef':
        _ws();
        final clef = _c == '"' ? _string() : _word();
        if (!_started) _bassClef = clef == 'bass' || clef == 'F';
      case 'bar':
        _ws();
        _bar(_barType(_string()));
      case 'break' || 'pageBreak':
        if (_line.isNotEmpty && _discard == 0) _lines.add([]);
      case 'cadenzaOn':
        _cadenza = true;
      case 'cadenzaOff':
        _cadenza = false;
        _pos = 0;
      case 'repeat':
        _repeat();
      case 'alternative':
        if (_repeats.isNotEmpty && !_repeats.last.alternatives) {
          _repeats.last.alternatives = true;
        }
        _alternatives();
      case 'tuplet':
        final (n, m) = _fraction();
        _ws();
        final span = _durationOpt();
        _tupletMusic(_Tuplet(m / n, n, span));
      case 'times':
        final (n, m) = _fraction();
        _tupletMusic(_Tuplet(n / m, m, null));
      case 'chordmode' || 'chords':
        i -= name.length + 1;
        _chordMusic();
      case 'addlyrics' || 'lyricmode' || 'lyrics' || 'lyricsto':
        i -= name.length + 1;
        _lyricMusic();
      case 'grace' || 'acciaccatura' || 'appoggiatura' || 'slashedGrace':
        _discard++;
        _music();
        _discard--;
      case 'afterGrace':
        _ws();
        if (_isDigit(_c)) _fraction();
        _music();
        _discard++;
        _music();
        _discard--;
      case 'skip':
        _ws();
        final d = _durationOpt();
        if (d != null) _duration = d;
        _addTimed(AbcRest(duration: 0, invisible: true), _duration);
      case 'markup' || 'markuplist' || 'mark' || 'textMark' || 'sectionLabel':
        _skipArg();
      case 'tempo':
        _tempo();
      case 'override' || 'set':
        _skipAssignment();
      case 'revert' || 'unset':
        _skipToken();
      case 'tweak':
        _skipToken();
        _skipArg();
      case 'transposition':
        _ws();
        _absolutePitch();
      default:
        break; // Commands without arguments (\stemUp, \autoBeamOff, …).
    }
  }

  /// Reads the next music expression in an octave mode: relative to
  /// [relative], or absolute with the unmarked `c` at [fixedBase].
  void _octaveMode(int? relative, int fixedBase) {
    final savedRelative = _relStep;
    final savedBase = _fixedBase;
    _relStep = relative;
    _fixedBase = fixedBase;
    _music();
    _relStep = savedRelative;
    _fixedBase = savedBase;
  }

  void _newContext() {
    _ws();
    final type = _word();
    _ws();
    if (_c == '=') {
      i++;
      _ws();
      if (_c == '"') {
        _string();
      } else {
        _word();
      }
    }
    _ws();
    if (_at(r'\with')) {
      i += 5;
      _ws();
      if (_c == '{') i = _blockEnd(t, i, '{', '}');
    }
    if (type == 'ChordNames') {
      _chordMusic();
    } else if (type == 'Lyrics') {
      _lyricMusic();
    } else if (_skippedContexts.contains(type)) {
      _skipMusic();
    } else {
      _music();
    }
  }

  /// Skips a music expression of a context that is not drawn.
  void _skipMusic() {
    while (true) {
      _ws();
      if (_end || _c == '}' || _at('>>')) return;
      if (_c == '{') {
        i = _blockEnd(t, i, '{', '}');
        return;
      }
      if (_at('<<')) {
        i = _blockEnd(t, i, '<<', '>>');
        return;
      }
      if (_c == '"') {
        i = _stringEnd(t, i);
        continue;
      }
      i++;
    }
  }

  void _header() {
    _ws();
    if (_c != '{') return;
    final end = _closedBlockEnd();
    final m = _titlePattern.firstMatch(t.substring(i + 1, end - 1));
    if (m != null) _title ??= m.group(1)!.replaceAll(r'\"', '"');
    i = end;
  }

  void _setLanguage(String name) {
    _lang = switch (name) {
      'nederlands' => _Lang.nederlands,
      'deutsch' => _Lang.deutsch,
      'english' => _Lang.english,
      _ => throw const _Unsupported(),
    };
  }

  void _keyCommand() {
    _ws();
    final p = _pitchName(_word()) ?? (throw const _Unsupported());
    _ws();
    var mode = '';
    if (_c == r'\') {
      final save = i;
      final m = _modes[_command()];
      if (m == null) {
        i = save;
      } else {
        mode = m;
      }
    }
    final key = AbcKey.parse('${_rootName(p)}$mode');
    if (_discard > 0) return;
    if (_started) {
      _line.add(AbcKeyChange(key));
    } else {
      _initialKey = key;
    }
  }

  void _setMeter(int num, int den) {
    if (den <= 0 || num <= 0) throw const _Unsupported();
    final text = !_numericTime && num == 4 && den == 4
        ? 'C'
        : !_numericTime && num == 2 && den == 2
        ? 'C|'
        : '$num/$den';
    _measure = num / den;
    _beat = num % 3 == 0 && num > 3 && den >= 8 ? 3 / den : 1 / den;
    if (_discard > 0) return;
    if (_started) {
      _line.add(AbcMeterChange(text));
      _pos = 0;
    } else {
      _initialMeter = text;
      _pos = _partial == null ? 0 : _measure - _partial!;
    }
  }

  (int, int) _fraction() {
    _ws();
    final m = _fractionPattern.matchAsPrefix(t, i);
    if (m == null) throw const _Unsupported();
    i = m.end;
    final n = int.parse(m.group(1)!);
    final d = int.parse(m.group(2)!);
    if (n == 0 || d == 0) throw const _Unsupported();
    return (n, d);
  }

  void _tupletMusic(_Tuplet tuplet) {
    _tuplets.add(tuplet);
    _music();
    _tuplets.removeLast();
  }

  void _tempo() {
    _ws();
    if (_c == '"') {
      _string();
    } else if (_at(r'\markup')) {
      _command();
      _skipArg();
    }
    final save = i;
    _ws();
    if (!_isDigit(_c)) {
      i = save;
      return;
    }
    _durationOpt();
    _ws();
    if (_c == '=') {
      i++;
      _ws();
      _int();
      if (_c == '-') {
        i++;
        _int();
      }
    }
  }

  /// Skips one argument: a block, string, Scheme value, markup or word.
  void _skipArg() {
    _ws();
    if (_end) return;
    final c = _c;
    if (c == '{') {
      i = _blockEnd(t, i, '{', '}');
    } else if (c == '"') {
      i = _stringEnd(t, i);
    } else if (c == '#') {
      i = _schemeEnd(t, i);
    } else if (c == r'\') {
      final name = _command();
      if (name == 'markup' || name == 'markuplist') _skipArg();
    } else {
      _skipToken();
    }
  }

  void _skipToken() {
    _ws();
    while (!_end && !_isSpace(_c) && _c != '{' && _c != '}') {
      i++;
    }
  }

  /// Skips `path = value` of `\override` and `\set`.
  void _skipAssignment() {
    final eq = t.indexOf('=', i);
    if (eq < 0) throw const _Unsupported();
    i = eq + 1;
    _skipArg();
  }

  // Notes ---------------------------------------------------------------------

  void _wordMusic() {
    final w = _word();
    switch (w) {
      case 'r':
        _rest(invisible: false);
      case 's':
        _rest(invisible: true);
      case 'R':
        _fullRest();
      case 'q':
        if (_lastChord.isEmpty) throw const _Unsupported();
        _note(_lastChord);
      default:
        final p = _pitchName(w) ?? (throw const _Unsupported());
        _note([_resolve(p, _marks())]);
    }
  }

  bool get _atPitch {
    if (!_isLetter(_c)) return false;
    final save = i;
    final w = _word();
    i = save;
    return _pitchName(w) != null;
  }

  /// A pitch written in absolute octaves (`c'` = middle C).
  AbcPitch _absolutePitch() {
    final p = _pitchName(_word()) ?? (throw const _Unsupported());
    return AbcPitch(p.letter - 7 + 7 * _marks(), p.alter);
  }

  /// The note name [w] in the current language, or null.
  _Pitch? _pitchName(String w) {
    if (w.isEmpty) return null;
    var letter = 'cdefgab'.indexOf(w[0]);
    var rest = w.substring(1);
    if (_lang == _Lang.english) {
      if (letter < 0) return null;
      final alter = switch (rest) {
        '' => 0,
        's' || 'sharp' => 1,
        'f' || 'flat' => -1,
        'ss' || 'x' || 'sharpsharp' => 2,
        'ff' || 'flatflat' => -2,
        _ => null,
      };
      return alter == null ? null : (letter: letter, alter: alter);
    }
    var base = 0;
    if (_lang == _Lang.deutsch) {
      if (w[0] == 'h') letter = 6;
      if (w[0] == 'b') base = -1; // German b is B flat.
    }
    if (letter < 0) return null;
    // "es", "as": the vowel of the name stands for the e of "es".
    if ((w[0] == 'e' || w[0] == 'a') && rest.startsWith('s')) rest = 'e$rest';
    final alter = switch (rest) {
      '' => 0,
      'is' => 1,
      'isis' => 2,
      'es' => -1,
      'eses' => -2,
      _ => null,
    };
    return alter == null ? null : (letter: letter, alter: base + alter);
  }

  /// Octave marks after a pitch; skips `!`, `?` and octave checks.
  int _marks() {
    var marks = 0;
    while (_c == "'" || _c == ',') {
      marks += _c == "'" ? 1 : -1;
      i++;
    }
    while (_c == '!' || _c == '?') {
      i++;
    }
    if (_c == '=') {
      i++;
      while (_c == "'" || _c == ',') {
        i++;
      }
    }
    return marks;
  }

  /// The pitch of a note in the current octave mode.
  AbcPitch _resolve(_Pitch p, int marks) {
    final ref = _relStep;
    if (ref == null) {
      return AbcPitch(_fixedBase + p.letter + 7 * marks, p.alter);
    }
    var diff = (p.letter - ref % 7) % 7;
    if (diff > 3) diff -= 7;
    final step = ref + diff + 7 * marks;
    _relStep = step;
    return AbcPitch(step, p.alter);
  }

  void _chord() {
    i++; // <
    final pitches = <AbcPitch>[];
    while (true) {
      _ws();
      if (_end) throw const _Unsupported();
      final c = _c;
      if (c == '>') {
        i++;
        break;
      }
      if (_isLetter(c)) {
        final p = _pitchName(_word()) ?? (throw const _Unsupported());
        pitches.add(_resolve(p, _marks()));
      } else if (c == r'\') {
        _command();
      } else if (c == '"') {
        i = _stringEnd(t, i);
      } else {
        i++; // Fingerings and articulations inside the chord.
      }
    }
    if (pitches.isEmpty) throw const _Unsupported();
    // The next note is relative to the first note of the chord.
    if (_relStep != null) _relStep = pitches.first.step;
    _lastChord = pitches;
    _note(pitches);
  }

  /// Reads a duration (`4`, `8.`, `2*3`, `\breve`), or null if none.
  double? _durationOpt() {
    double base;
    if (_isDigit(_c)) {
      final n = _int()!;
      if (n <= 0 || n & (n - 1) != 0) throw const _Unsupported();
      base = 1 / n;
    } else if (_at(r'\breve')) {
      i += 6;
      base = 2;
    } else if (_at(r'\longa')) {
      i += 6;
      base = 4;
    } else {
      return null;
    }
    var dots = 0;
    while (_c == '.') {
      dots++;
      i++;
    }
    var d = base * (2 - 1 / (1 << dots));
    while (_c == '*') {
      i++;
      final a = _int() ?? (throw const _Unsupported());
      var b = 1;
      if (_c == '/') {
        i++;
        b = _int() ?? (throw const _Unsupported());
      }
      if (b == 0) throw const _Unsupported();
      d = d * a / b;
    }
    return d;
  }

  _PostEvents _postEvents() {
    var tie = false;
    var slurStart = false;
    var slurEnd = false;
    var beamStart = false;
    var beamEnd = false;
    final annotations = <String>[];
    while (true) {
      final save = i;
      _ws();
      final c = _c;
      if (c == '~') {
        tie = true;
        i++;
      } else if (c == '(') {
        slurStart = true;
        i++;
      } else if (c == ')') {
        slurEnd = true;
        i++;
      } else if (c == '[') {
        beamStart = true;
        i++;
      } else if (c == ']') {
        beamEnd = true;
        i++;
      } else if (c == ':' && _isDigit(i + 1 < t.length ? t[i + 1] : '')) {
        i++;
        _int(); // Tremolo.
      } else if (c == '-' || c == '^' || c == '_') {
        i++;
        final d = _c;
        if (d == '"') {
          final text = _string();
          if (c != '_') annotations.add(text);
        } else if (d == r'\') {
          if (_command() == 'markup') _skipArg();
        } else if (_isDigit(d)) {
          _int(); // Fingering.
        } else if (d.isNotEmpty) {
          i++; // Articulation shorthand (-. -> -^ -- -! -_ -+).
        }
      } else if (c == r'\') {
        final name = _command();
        if (!_postCommands.contains(name) &&
            (name.length != 1 || name == r'\' || _isLetter(name))) {
          i = save;
          break;
        }
      } else {
        i = save;
        break;
      }
    }
    return (
      tie: tie,
      slurStart: slurStart,
      slurEnd: slurEnd,
      beamStart: beamStart,
      beamEnd: beamEnd,
      annotations: annotations,
    );
  }

  /// Whether a new beam group starts at the current position.
  bool _beamBreak(_PostEvents post) {
    bool result;
    if (_beamOpen) {
      result = false;
    } else if (post.beamStart || _beamEnded) {
      result = true;
    } else {
      final beats = _pos / _beat;
      result = (beats - beats.round()).abs() < 1e-6;
    }
    _beamEnded = false;
    if (post.beamStart) _beamOpen = true;
    if (post.beamEnd) {
      _beamOpen = false;
      _beamEnded = true;
    }
    return result;
  }

  void _note(List<AbcPitch> pitches) {
    final d = _durationOpt();
    if (d != null) _duration = d;
    final post = _postEvents();
    if (_discard > 0) return;
    final note = AbcNote(
      pitches: pitches,
      duration: 0,
      tie: post.tie,
      annotations: post.annotations,
      spaceBefore: _beamBreak(post),
    );
    if (_inSlur || _tieOpen) _melisma.add(note);
    if (post.slurEnd) _inSlur = false;
    if (post.slurStart) _inSlur = true;
    _tieOpen = post.tie;
    _addTimed(note, _duration);
  }

  void _rest({required bool invisible}) {
    final d = _durationOpt();
    if (d != null) _duration = d;
    _postEvents();
    _tieOpen = false;
    _addTimed(
      AbcRest(duration: 0, invisible: invisible, spaceBefore: true),
      _duration,
    );
  }

  /// `R1*4`: one rest per measure.
  void _fullRest() {
    final d = _durationOpt();
    if (d != null) _duration = d;
    _postEvents();
    _tieOpen = false;
    final measures = (_duration / _measure).round();
    if (measures < 2) {
      _addTimed(AbcRest(duration: 0, spaceBefore: true), _duration);
      return;
    }
    for (var k = 0; k < measures && k < 64; k++) {
      _addTimed(AbcRest(duration: 0, spaceBefore: true), _measure);
    }
  }

  void _addTimed(AbcElement e, double duration) {
    if (_discard > 0) return;
    var d = duration;
    for (final tuplet in _tuplets) {
      d *= tuplet.factor;
    }
    int? number;
    if (_tuplets.isNotEmpty) {
      final tuplet = _tuplets.last;
      final span = tuplet.span;
      final groupStart =
          tuplet.done < 1e-9 || span != null && _isMultiple(tuplet.done, span);
      if (groupStart) number = tuplet.number;
      for (final tuplet in _tuplets) {
        tuplet.done += d;
      }
    }
    switch (e) {
      case final AbcNote n:
        n.duration = d;
        n.tuplet = number;
      case final AbcRest r:
        r.duration = d;
      default:
        break;
    }
    _line.add(e);
    _timed.add((time: _time, element: e));
    _time += d;
    if (_cadenza) return;
    _pos += d;
    if (_pos >= _measure - 1e-9) {
      _line.add(const AbcBar('|'));
      _pos -= _measure * ((_pos + 1e-9) / _measure).floor();
      if (_pos < 1e-9) _pos = 0;
    }
  }

  static bool _isMultiple(double value, double unit) {
    final x = value / unit;
    return (x - x.round()).abs() < 1e-6;
  }

  // Bar lines and repeats -----------------------------------------------------

  /// The bar line at the end of the music (key and meter changes after it
  /// do not count), or null when the music ends with a note.
  ({List<AbcElement> line, int index})? _lastBar() {
    for (final line in _lines.reversed) {
      for (var k = line.length - 1; k >= 0; k--) {
        final e = line[k];
        if (e is AbcKeyChange || e is AbcMeterChange) continue;
        return e is AbcBar ? (line: line, index: k) : null;
      }
    }
    return null;
  }

  /// Sets the bar line at the current position: replaces the bar line the
  /// music ends with, or adds one in the middle of a measure.
  void _bar(String type, {int? volta}) {
    if (_discard > 0) return;
    final last = _lastBar();
    if (last == null) {
      _line.add(AbcBar(type, volta: volta));
    } else {
      final old = last.line[last.index] as AbcBar;
      last.line[last.index] = AbcBar(type, volta: volta ?? old.volta);
    }
  }

  String? get _lastBarType {
    final last = _lastBar();
    return last == null ? null : (last.line[last.index] as AbcBar).type;
  }

  static String _barType(String lily) => switch (lily) {
    '||' => '||',
    '|.' || '|.|' => '|]',
    '.|' => '[|',
    '' => '',
    '.|:' || '[|:' || '|:' || '.|:-||' || '.|:-|' => '|:',
    ':|.' || ':|]' || ':|' || ':|.|' => ':|',
    ':..:' || ':|.|:' || ':|.:' || ':.|.:' || '[|:|]' || ':|][|:' => '::',
    _ => '|',
  };

  void _repeatStart() => _bar(_lastBarType == ':|' ? '::' : '|:');

  void _repeatEnd() => _bar(_lastBarType == '|:' ? '::' : ':|');

  void _repeat() {
    _ws();
    final type = _word();
    _ws();
    final count = _int() ?? 2;
    switch (type) {
      case 'volta' || 'percent' || 'segno':
        _repeatStart();
        final repeat = _Repeat();
        _repeats.add(repeat);
        _music();
        _repeats.removeLast();
        if (repeat.alternatives) return;
        final save = i;
        _ws();
        if (_at(r'\alternative')) {
          _command();
          _alternatives();
        } else {
          i = save;
          _repeatEnd();
        }
      case 'unfold':
        final start = i;
        final ref = _relStep;
        int? end;
        for (var k = 0; k < count.clamp(1, 16); k++) {
          i = start;
          _relStep = ref;
          _music();
          end ??= _relStep;
        }
        _relStep = end;
      default:
        throw const _Unsupported(); // Tremolo repeats.
    }
  }

  /// `\alternative { {…} {…} }`: volta brackets 1, 2, …
  void _alternatives() {
    _ws();
    if (_c != '{') throw const _Unsupported();
    final end = _closedBlockEnd();
    i++;
    final starts = <int>[];
    var k = i;
    while (true) {
      while (k < end && _isSpace(t[k])) {
        k++;
      }
      if (k >= end - 1) break;
      starts.add(k);
      k = _expressionEnd(t, k);
    }
    for (var n = 0; n < starts.length; n++) {
      i = starts[n];
      if (_lastBar() == null) {
        _bar('|', volta: n + 1);
      } else {
        _bar(_lastBarType!, volta: n + 1);
      }
      _music();
      if (n < starts.length - 1) _repeatEnd();
    }
    i = end;
  }

  // Chord names -----------------------------------------------------------------

  void _chordMusic() {
    _ws();
    while (_at(r'\chordmode') || _at(r'\chords')) {
      _command();
      _ws();
    }
    if (_c != '{') throw const _Unsupported();
    i++;
    _chordSequence(_time);
  }

  /// Reads chord names up to the closing brace; returns the end time.
  double _chordSequence(double start) {
    var time = start;
    while (true) {
      _ws();
      if (_end) throw const _Unsupported();
      final c = _c;
      if (c == '}') {
        i++;
        return time;
      }
      if (c == '{') {
        i++;
        time = _chordSequence(time);
      } else if (c == r'\') {
        final name = _command();
        switch (name) {
          case 'repeat':
            _ws();
            final type = _word();
            _ws();
            final count = _int() ?? 2;
            _ws();
            if (_c != '{') throw const _Unsupported();
            final body = i + 1;
            final times = type == 'unfold' ? count.clamp(1, 16) : 1;
            for (var k = 0; k < times; k++) {
              i = body;
              time = _chordSequence(time);
            }
          case 'alternative':
            _ws();
            if (_c == '{') {
              i++;
              time = _chordSequence(time);
            }
          case 'set' || 'override':
            _skipAssignment();
          case 'partial':
            _ws();
            _durationOpt();
          case 'markup' || 'mark':
            _skipArg();
          default:
            break;
        }
      } else if (_isLetter(c)) {
        final w = _word();
        final rest = w == 'r' || w == 's' || w == 'R';
        final root = rest
            ? null
            : _pitchName(w) ?? (throw const _Unsupported());
        _marks();
        final d = _durationOpt();
        if (d != null) _chordDuration = d;
        var suffix = '';
        if (_c == ':') {
          i++;
          final m = _chordModPattern.matchAsPrefix(t, i)!;
          suffix = _chordSuffix(m.group(0)!);
          i = m.end;
        }
        var bass = '';
        if (_c == '/') {
          i++;
          if (_c == '+') i++;
          final b = _pitchName(_word());
          _marks();
          if (b != null) bass = '/${_rootName(b)}';
        }
        if (root != null && _discard == 0) {
          _chords.add((time: time, symbol: '${_rootName(root)}$suffix$bass'));
        }
        time += _chordDuration;
      } else if (c == '"') {
        i = _stringEnd(t, i);
      } else {
        i++; // Bar checks and ties.
      }
    }
  }

  void _attachChords() {
    for (final chord in _chords) {
      for (final e in _timed) {
        if ((e.time - chord.time).abs() > 1e-6) continue;
        switch (e.element) {
          case final AbcNote n:
            n.chordSymbol = chord.symbol;
          case final AbcRest r:
            r.chordSymbol = chord.symbol;
          default:
            break;
        }
        break;
      }
    }
  }

  // Lyrics ----------------------------------------------------------------------

  void _lyricMusic() {
    while (true) {
      _ws();
      if (_c != r'\') break;
      final save = i;
      final name = _command();
      if (name == 'lyricsto') {
        _ws();
        if (_c == '"') {
          _string();
        } else {
          _word();
        }
      } else if (!{'addlyrics', 'lyricmode', 'lyrics'}.contains(name)) {
        i = save;
        break;
      }
    }
    _ws();
    if (_c != '{') throw const _Unsupported();
    final end = _closedBlockEnd();
    final syllables = _syllablesOf(t.substring(i + 1, end - 1));
    // The first verse is shown below the notes.
    _syllables ??= syllables;
    i = end;
  }

  static List<String?> _syllablesOf(String body) {
    final result = <String?>[];
    var k = 0;
    while (k < body.length) {
      final c = body[k];
      if (_isSpace(c) || c == '{' || c == '}' || c == '|') {
        k++;
        continue;
      }
      if (c == '#') {
        k = _schemeEnd(body, k);
        continue;
      }
      if (c == r'\') {
        var e = k + 1;
        while (e < body.length && _isLetter(body[e])) {
          e++;
        }
        final name = body.substring(k + 1, e);
        k = e;
        if (name == 'set' || name == 'override') {
          final eq = body.indexOf('=', k);
          k = eq < 0 ? body.length : _expressionEnd(body, eq + 1);
        } else if (name == 'markup') {
          while (k < body.length && _isSpace(body[k])) {
            k++;
          }
          if (k < body.length && body[k] == '{') {
            k = _blockEnd(body, k, '{', '}');
          }
        }
        continue;
      }
      String word;
      if (c == '"') {
        final e = _stringEnd(body, k);
        word = body
            .substring(k + 1, e - 1 > k + 1 ? e - 1 : k + 1)
            .replaceAll(r'\"', '"');
        k = e;
      } else {
        var e = k;
        while (e < body.length &&
            !_isSpace(body[e]) &&
            body[e] != '{' &&
            body[e] != '}') {
          e++;
        }
        word = body.substring(k, e).replaceFirst(_durationSuffix, '');
        k = e;
        if (word == '--') {
          final last = result.lastOrNull;
          if (last != null) result[result.length - 1] = '$last-';
          continue;
        }
        if (word == '__' || word.isEmpty) continue;
        if (word == '_') {
          result.add(null);
          continue;
        }
        word = word.replaceAll('~', ' ').replaceAll('_', ' ');
      }
      result.add(word);
    }
    return result;
  }

  void _attachLyrics() {
    final syllables = _syllables;
    if (syllables == null) return;
    var k = 0;
    for (final (:element, time: _) in _timed) {
      if (element is! AbcNote || _melisma.contains(element)) continue;
      if (k >= syllables.length) break;
      element.lyric = syllables[k++];
    }
  }
}

String _rootName(_Pitch p) =>
    '${_names[p.letter]}${p.alter > 0 ? '#' * p.alter : 'b' * -p.alter}';

/// Converts LilyPond chord modifiers (`m7`, `7.9-`, `maj7`, `sus4`) to a
/// chord suffix (`m7`, `7b9`, `maj7`, `sus4`).
String _chordSuffix(String mods) {
  final parts = mods.split('^').first.split('.');
  final out = StringBuffer();
  final first = parts.first;
  final power = first == '1';
  var head = switch (first) {
    'min' => 'm',
    'maj' => 'maj7',
    'sus' => 'sus4',
    '1' || '3' || '5' => '',
    '5+' => 'aug',
    _ => first.startsWith('min') ? 'm${first.substring(3)}' : first,
  };
  if (head.endsWith('7+')) {
    head = '${head.substring(0, head.length - 2)}maj7';
  }
  out.write(head);
  for (final part in parts.skip(1)) {
    final m = RegExp(r'^(\d+)([+-]?)$').firstMatch(part);
    if (m == null) {
      out.write(part);
      continue;
    }
    final number = m.group(1)!;
    final alter = m.group(2)!;
    if (power && number == '5' && alter.isEmpty) {
      out.write('5');
    } else if (alter == '+') {
      out.write('#$number');
    } else if (alter == '-') {
      out.write('b$number');
    } else {
      out.write('add$number');
    }
  }
  return out.toString();
}

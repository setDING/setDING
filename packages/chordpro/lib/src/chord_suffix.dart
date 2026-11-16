/// Structured chord suffix and chord display styles (ADR-0022).
library;

/// How the part of a chord after its root is spelled.
enum ChordStyle {
  /// The suffix exactly as written in the source.
  asWritten,

  /// Pop spelling: `Cm7`, `Cmaj7`, `Cdim`, `Caug`, `Cm7b5`.
  standard,

  /// Jazz symbols: `C−7`, `CΔ7`, `C°`, `C+`, `Cø7`.
  jazz,
}

/// Basic quality of a chord.
enum ChordQuality { major, minor, diminished, augmented, halfDiminished }

/// A piece of a displayed chord; [raised] pieces are shown as superscript
/// when the display asks for it.
class ChordPart {
  const ChordPart(this.text, {this.raised = false});

  final String text;
  final bool raised;

  @override
  bool operator ==(Object other) =>
      other is ChordPart && other.text == text && other.raised == raised;

  @override
  int get hashCode => Object.hash(text, raised);

  @override
  String toString() => raised ? '^($text)' : text;
}

/// Plain text of [parts].
String chordPartsText(Iterable<ChordPart> parts) =>
    parts.map((p) => p.text).join();

/// Joins neighbouring parts with the same [ChordPart.raised]; with
/// [superscript] false, everything becomes one plain part.
List<ChordPart> mergeChordParts(
  Iterable<ChordPart> parts, {
  bool superscript = true,
}) {
  final result = <ChordPart>[];
  for (final part in parts) {
    if (part.text.isEmpty) continue;
    final raised = superscript && part.raised;
    if (result.isNotEmpty && result.last.raised == raised) {
      result.last = ChordPart(result.last.text + part.text, raised: raised);
    } else {
      result.add(ChordPart(part.text, raised: raised));
    }
  }
  return result;
}

/// The suffix of a chord (everything after the root, without the bass),
/// split into quality, extension and modifiers.
///
/// Spelling variants are normalised: `m7`, `min7`, `mi7`, `-7` and `−7` are
/// all a minor seventh, `maj7`, `M7`, `Δ7` and `^7` a major seventh.
class ChordSuffix {
  const ChordSuffix({
    this.quality = ChordQuality.major,
    this.extension = '',
    this.majorSeventh = false,
    this.modifiers = const [],
  });

  final ChordQuality quality;

  /// Highest added tone: `''`, `2`, `4`, `5`, `6`, `6/9`, `7`, `9`, `11`,
  /// `13`.
  final String extension;

  /// The seventh is a major seventh (`maj7`, `maj9`, `mMaj7`).
  final bool majorSeventh;

  /// Alterations and additions in written order, normalised to `b5`, `#9`,
  /// `add9`, `sus4`, `sus2`, `alt`, `no3`.
  final List<String> modifiers;

  bool get isMinor =>
      quality == ChordQuality.minor || quality == ChordQuality.halfDiminished;

  static final _cache = <String, ChordSuffix?>{};

  /// Parses [suffix]; null if it is not fully understood (it is then shown
  /// as written).
  static ChordSuffix? tryParse(String suffix) {
    if (_cache.length > 2000) _cache.clear();
    return _cache.putIfAbsent(suffix, () => _SuffixParser(suffix).parse());
  }

  /// The suffix in [style] (not [ChordStyle.asWritten]): quality as a normal
  /// part, extension and modifiers as raised parts.
  List<ChordPart> format(ChordStyle style) {
    final jazz = style == ChordStyle.jazz;
    final parts = <ChordPart>[];
    var ext = extension;
    final mods = [...modifiers];
    switch (quality) {
      case ChordQuality.major:
        break;
      case ChordQuality.minor:
        parts.add(ChordPart(jazz ? '−' : 'm'));
      case ChordQuality.diminished:
        parts.add(ChordPart(jazz ? '°' : 'dim'));
      case ChordQuality.augmented:
        parts.add(ChordPart(jazz ? '+' : 'aug'));
      case ChordQuality.halfDiminished:
        if (jazz) {
          parts.add(const ChordPart('ø'));
        } else {
          parts.add(const ChordPart('m'));
          mods.insert(0, 'b5');
        }
        if (ext.isEmpty) ext = '7';
    }
    if (majorSeventh) {
      final marker = jazz ? 'Δ' : 'maj';
      final text = '$marker${ext.isEmpty ? '7' : ext}';
      parts.add(
        ChordPart(
          quality == ChordQuality.minor && !jazz ? '($text)' : text,
          raised: true,
        ),
      );
    } else if (ext.isNotEmpty) {
      parts.add(ChordPart(ext, raised: true));
    }
    for (final mod in mods) {
      parts.add(ChordPart(jazz ? _jazzAccidentals(mod) : mod, raised: true));
    }
    return parts;
  }

  static String _jazzAccidentals(String mod) {
    if (mod.length < 2) return mod;
    return switch (mod[0]) {
      'b' when _isDigit(mod[1]) => '♭${mod.substring(1)}',
      '#' => '♯${mod.substring(1)}',
      _ => mod,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is ChordSuffix &&
      other.quality == quality &&
      other.extension == extension &&
      other.majorSeventh == majorSeventh &&
      _listEquals(other.modifiers, modifiers);

  @override
  int get hashCode =>
      Object.hash(quality, extension, majorSeventh, Object.hashAll(modifiers));

  @override
  String toString() => chordPartsText(format(ChordStyle.standard));
}

bool _listEquals(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _isDigit(String c) => c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57;

class _SuffixParser {
  _SuffixParser(this.text);

  final String text;
  var _i = 0;
  var _quality = ChordQuality.major;
  var _extension = '';
  var _majorSeventh = false;
  final _modifiers = <String>[];

  bool get _done => _i >= text.length;

  bool _take(String token) {
    if (text.startsWith(token, _i)) {
      _i += token.length;
      return true;
    }
    return false;
  }

  bool _digitAhead(int offset) =>
      _i + offset < text.length && _isDigit(text[_i + offset]);

  ChordSuffix? parse() {
    _quality = _parseQuality();
    if (_parseMajorMarker() == false) return null;
    if (_extension.isEmpty) _extension = _parseNumber() ?? '';
    if (!_parseModifiers()) return null;
    // m7b5 is a half-diminished chord.
    if (_quality == ChordQuality.minor &&
        _extension == '7' &&
        !_majorSeventh &&
        _modifiers.remove('b5')) {
      _quality = ChordQuality.halfDiminished;
    }
    if (_quality == ChordQuality.halfDiminished && _extension == '7') {
      _extension = '';
    }
    return ChordSuffix(
      quality: _quality,
      extension: _extension,
      majorSeventh: _majorSeventh,
      modifiers: List.unmodifiable(_modifiers),
    );
  }

  ChordQuality _parseQuality() {
    if (_take('ø') || _take('Ø')) return ChordQuality.halfDiminished;
    if (_take('dim') ||
        _take('°') ||
        (!text.startsWith('omit', _i) && _take('o'))) {
      return ChordQuality.diminished;
    }
    if (_take('aug') || _take('+')) {
      // `C+5` is the same chord as `C+`.
      if (!_digitAhead(1)) _take('5');
      return ChordQuality.augmented;
    }
    if (_take('min') || _take('mi') || _take('-') || _take('−')) {
      return ChordQuality.minor;
    }
    if (text.startsWith('m', _i) && !text.startsWith('maj', _i)) {
      _i += 1;
      return ChordQuality.minor;
    }
    return ChordQuality.major;
  }

  /// Reads a major-seventh marker with its number (`maj7`, `M9`, `Δ`).
  /// Returns null if there is none, false on a conflict.
  bool? _parseMajorMarker() {
    final start = _i;
    final found =
        _take('maj') ||
        _take('Maj') ||
        _take('MAJ') ||
        _take('Δ') ||
        _take('△') ||
        _take('^') ||
        (text.startsWith('Ma', _i) && _digitAhead(2) && _take('Ma')) ||
        (text.startsWith('M', _i) && _digitAhead(1) && _take('M'));
    if (!found) {
      // A plain `M` means a major triad (`CM`).
      if (_quality == ChordQuality.major && _take('M') && !_done) {
        _i = start;
      }
      return null;
    }
    if (_majorSeventh || _extension.isNotEmpty) return false;
    final number = _parseNumber();
    if (number != null && !const {'7', '9', '11', '13'}.contains(number)) {
      return false;
    }
    _majorSeventh = true;
    _extension = number ?? '7';
    return true;
  }

  String? _parseNumber() {
    for (final n in const [
      '6/9',
      '69',
      '13',
      '11',
      '9',
      '7',
      '6',
      '5',
      '4',
      '2',
    ]) {
      if (text.startsWith(n, _i)) {
        _i += n.length;
        return n == '69' ? '6/9' : n;
      }
    }
    return null;
  }

  bool _parseModifiers() {
    var depth = 0;
    while (!_done) {
      final c = text[_i];
      if (c == '(') {
        depth++;
        _i++;
        continue;
      }
      if (c == ')') {
        if (depth == 0) return false;
        depth--;
        _i++;
        continue;
      }
      if (c == ',' || c == ' ' || c == '/') {
        if (c == '/' && depth == 0) return false;
        _i++;
        continue;
      }
      final mod = _parseModifier();
      if (mod == null) {
        // A major seventh may also come in parentheses: `m(maj7)`.
        if (_parseMajorMarker() == true) continue;
        return false;
      }
      _modifiers.add(mod);
    }
    return depth == 0;
  }

  String? _parseModifier() {
    if (_take('sus')) {
      if (_take('2')) return 'sus2';
      _take('4');
      return 'sus4';
    }
    if (_take('add')) {
      final n = _parseNumber();
      return n == null || n == '6/9' ? null : 'add$n';
    }
    if (_take('alt')) return 'alt';
    if (_take('no') || _take('omit')) {
      final n = _parseNumber();
      return n == null || n == '6/9' ? null : 'no$n';
    }
    final c = text[_i];
    final flat = c == 'b' || c == '♭' || c == '-' || c == '−';
    final sharp = c == '#' || c == '♯' || c == '+';
    if (flat || sharp) {
      _i++;
      final n = _parseNumber();
      if (n == null || !const {'5', '6', '9', '11', '13'}.contains(n)) {
        return null;
      }
      return '${flat ? 'b' : '#'}$n';
    }
    return null;
  }
}

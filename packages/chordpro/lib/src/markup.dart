/// ChordPro markup: a subset of the Pango markup language (ADR-0012).
///
/// `<span …>` with font, size, style, weight, colours, lines and rise, and
/// the convenience tags `<b> <i> <u> <s> <sub> <sup> <big> <small> <tt>`.
/// `<strut/>` and `href` are accepted and ignored. Anything that does not
/// look like a known tag stays as text (e.g. "I <3 you").
library;

/// A font size from markup: either relative ([factor]) or absolute
/// ([points]).
class MarkupSize {
  const MarkupSize.factor(double this.factor) : points = null;
  const MarkupSize.points(double this.points) : factor = null;

  final double? factor;
  final double? points;

  /// Applies this size on top of [outer].
  MarkupSize combine(MarkupSize? outer) {
    if (points != null || outer == null) return this;
    if (outer.points != null) return MarkupSize.points(outer.points! * factor!);
    return MarkupSize.factor(outer.factor! * factor!);
  }

  @override
  bool operator ==(Object other) =>
      other is MarkupSize && other.factor == factor && other.points == points;

  @override
  int get hashCode => Object.hash(factor, points);
}

/// Text attributes of a markup run. Null means "inherit".
class MarkupStyle {
  const MarkupStyle({
    this.bold,
    this.italic,
    this.underline,
    this.underlineColour,
    this.overline,
    this.overlineColour,
    this.strikethrough,
    this.strikethroughColour,
    this.size,
    this.foreground,
    this.background,
    this.family,
    this.rise,
  });

  final bool? bold;
  final bool? italic;

  /// `single`, `double` or `none`.
  final String? underline;
  final String? underlineColour;
  final String? overline;
  final String? overlineColour;
  final bool? strikethrough;
  final String? strikethroughColour;
  final MarkupSize? size;

  /// Colour as written (`#RRGGBB` or a colour name).
  final String? foreground;
  final String? background;

  /// Font family as written (`serif`, `sans`, `monospace`, …).
  final String? family;

  /// Vertical shift as a fraction of the font size (positive = up).
  final double? rise;

  static const plain = MarkupStyle();

  bool get isPlain => this == plain;

  /// [inner] overrides this style; sizes are combined.
  MarkupStyle merge(MarkupStyle inner) => MarkupStyle(
    bold: inner.bold ?? bold,
    italic: inner.italic ?? italic,
    underline: inner.underline ?? underline,
    underlineColour: inner.underlineColour ?? underlineColour,
    overline: inner.overline ?? overline,
    overlineColour: inner.overlineColour ?? overlineColour,
    strikethrough: inner.strikethrough ?? strikethrough,
    strikethroughColour: inner.strikethroughColour ?? strikethroughColour,
    size: inner.size == null ? size : inner.size!.combine(size),
    foreground: inner.foreground ?? foreground,
    background: inner.background ?? background,
    family: inner.family ?? family,
    rise: inner.rise ?? rise,
  );

  @override
  bool operator ==(Object other) =>
      other is MarkupStyle &&
      other.bold == bold &&
      other.italic == italic &&
      other.underline == underline &&
      other.underlineColour == underlineColour &&
      other.overline == overline &&
      other.overlineColour == overlineColour &&
      other.strikethrough == strikethrough &&
      other.strikethroughColour == strikethroughColour &&
      other.size == size &&
      other.foreground == foreground &&
      other.background == background &&
      other.family == family &&
      other.rise == rise;

  @override
  int get hashCode => Object.hashAll([
    bold,
    italic,
    underline,
    underlineColour,
    overline,
    overlineColour,
    strikethrough,
    strikethroughColour,
    size,
    foreground,
    background,
    family,
    rise,
  ]);
}

/// A piece of text with one style.
class MarkupRun {
  const MarkupRun(this.text, this.style);

  final String text;
  final MarkupStyle style;
}

/// Result of [parseMarkup].
class MarkupText {
  const MarkupText(this.runs, this._rawToPlain);

  final List<MarkupRun> runs;
  final List<int> _rawToPlain;

  /// The text without markup.
  String get plain => runs.map((r) => r.text).join();

  bool get hasStyles => runs.any((r) => !r.style.isPlain);

  /// Position in [plain] that corresponds to position [raw] in the source.
  int plainIndex(int raw) => _rawToPlain[raw.clamp(0, _rawToPlain.length - 1)];

  /// The runs covering `plain[start, end)`.
  List<MarkupRun> slice(int start, int end) {
    final result = <MarkupRun>[];
    var pos = 0;
    for (final run in runs) {
      final runEnd = pos + run.text.length;
      final from = start > pos ? start : pos;
      final to = end < runEnd ? end : runEnd;
      if (from < to) {
        result.add(
          MarkupRun(run.text.substring(from - pos, to - pos), run.style),
        );
      }
      pos = runEnd;
    }
    return result;
  }
}

const _convenience = {
  'b': MarkupStyle(bold: true),
  'i': MarkupStyle(italic: true),
  'u': MarkupStyle(underline: 'single'),
  's': MarkupStyle(strikethrough: true),
  'sub': MarkupStyle(size: MarkupSize.factor(0.8), rise: -0.3),
  'sup': MarkupStyle(size: MarkupSize.factor(0.8), rise: 0.3),
  'big': MarkupStyle(size: MarkupSize.factor(1.25)),
  'small': MarkupStyle(size: MarkupSize.factor(0.8)),
  'tt': MarkupStyle(family: 'monospace'),
  'span': MarkupStyle.plain,
};

final _tag = RegExp(
  r'^<(/?)([a-zA-Z]+)((?:\s+[a-zA-Z_]+\s*=\s*(?:"[^"]*"|'
  "'[^']*'"
  r'))*)\s*(/?)>',
);
final _attribute = RegExp(r'''([a-zA-Z_]+)\s*=\s*(?:"([^"]*)"|'([^']*)')''');
const _entities = {
  '&lt;': '<',
  '&gt;': '>',
  '&amp;': '&',
  '&quot;': '"',
  '&apos;': "'",
};

/// Whether [text] may contain markup (fast check).
bool mayContainMarkup(String text) => text.contains('<') || text.contains('&');

/// Parses markup in [raw].
MarkupText parseMarkup(String raw) {
  final runs = <MarkupRun>[];
  final rawToPlain = List<int>.filled(raw.length + 1, 0);
  final stack = <(String, MarkupStyle)>[];
  var style = MarkupStyle.plain;
  final buffer = StringBuffer();
  var plainLength = 0;

  void flush() {
    if (buffer.isEmpty) return;
    runs.add(MarkupRun(buffer.toString(), style));
    plainLength += buffer.length;
    buffer.clear();
  }

  var i = 0;
  while (i < raw.length) {
    rawToPlain[i] = plainLength + buffer.length;
    final c = raw[i];
    if (c == '<') {
      final m = _tag.firstMatch(raw.substring(i));
      final name = m?.group(2)?.toLowerCase();
      if (m != null && (name == 'strut' || _convenience.containsKey(name))) {
        final closing = m.group(1) == '/';
        final selfClosing = m.group(4) == '/';
        if (name != 'strut') {
          if (closing) {
            final index = stack.lastIndexWhere((e) => e.$1 == name);
            if (index >= 0) {
              flush();
              stack.removeRange(index, stack.length);
              style = stack.fold(MarkupStyle.plain, (s, e) => s.merge(e.$2));
            }
          } else if (!selfClosing) {
            flush();
            final tagStyle = name == 'span'
                ? _spanStyle(m.group(3) ?? '')
                : _convenience[name]!;
            stack.add((name!, tagStyle));
            style = style.merge(tagStyle);
          }
        }
        for (var k = i; k < i + m.group(0)!.length; k++) {
          rawToPlain[k] = plainLength + buffer.length;
        }
        i += m.group(0)!.length;
        continue;
      }
    }
    if (c == '&') {
      final entity = _entities.keys
          .where((e) => raw.startsWith(e, i))
          .firstOrNull;
      if (entity != null) {
        for (var k = i; k < i + entity.length; k++) {
          rawToPlain[k] = plainLength + buffer.length;
        }
        buffer.write(_entities[entity]);
        i += entity.length;
        continue;
      }
    }
    buffer.write(c);
    i++;
  }
  flush();
  rawToPlain[raw.length] = plainLength;
  return MarkupText(runs, rawToPlain);
}

/// The text of [raw] without markup.
String stripMarkup(String raw) =>
    mayContainMarkup(raw) ? parseMarkup(raw).plain : raw;

MarkupStyle _spanStyle(String attributes) {
  bool? bold;
  bool? italic;
  String? underline;
  String? underlineColour;
  String? overline;
  String? overlineColour;
  bool? strike;
  String? strikeColour;
  MarkupSize? size;
  String? foreground;
  String? background;
  String? family;
  double? rise;

  for (final m in _attribute.allMatches(attributes)) {
    final name = m.group(1)!.toLowerCase();
    final value = (m.group(2) ?? m.group(3)!).trim();
    switch (name) {
      case 'font_desc' || 'font':
        final words = value.split(RegExp(r'\s+'));
        final familyWords = <String>[];
        for (final w in words) {
          final lower = w.toLowerCase();
          final points = double.tryParse(w);
          if (points != null) {
            size = MarkupSize.points(points);
          } else if (lower == 'bold') {
            bold = true;
          } else if (lower == 'italic' || lower == 'oblique') {
            italic = true;
          } else if (lower != 'normal' && lower != 'regular') {
            familyWords.add(w);
          }
        }
        if (familyWords.isNotEmpty) family = familyWords.join(' ');
      case 'font_family' || 'face':
        family = value;
      case 'size' || 'font_size':
        size = parseMarkupSize(value) ?? size;
      case 'style' || 'font_style':
        italic = value == 'italic' || value == 'oblique';
      case 'weight' || 'font_weight':
        final numeric = int.tryParse(value);
        bold = numeric != null
            ? numeric >= 600
            : const {'bold', 'heavy', 'ultrabold', 'semibold'}.contains(value);
      case 'foreground' || 'fgcolor' || 'color' || 'colour':
        foreground = value;
      case 'background' || 'bgcolor':
        background = value;
      case 'underline':
        underline = value == 'low' || value == 'error' ? 'single' : value;
      case 'underline_colour' || 'underline_color':
        underlineColour = value;
      case 'overline':
        overline = value;
      case 'overline_colour' || 'overline_color':
        overlineColour = value;
      case 'strikethrough':
        strike = value == 'true';
      case 'strikethrough_colour' || 'strikethrough_color':
        strikeColour = value;
      case 'rise':
        rise = _fraction(value);
      default:
        break; // href and unknown attributes are ignored.
    }
  }
  return MarkupStyle(
    bold: bold,
    italic: italic,
    underline: underline,
    underlineColour: underlineColour,
    overline: overline,
    overlineColour: overlineColour,
    strikethrough: strike,
    strikethroughColour: strikeColour,
    size: size,
    foreground: foreground,
    background: background,
    family: family,
    rise: rise,
  );
}

const _sizeSteps = {
  'xx-small': 0.512,
  'x-small': 0.64,
  'small': 0.8,
  'smaller': 0.8,
  'medium': 1.0,
  'large': 1.25,
  'larger': 1.25,
  'x-large': 1.5625,
  'xx-large': 1.953125,
};

/// Parses a size: symbolic, percentage or points.
MarkupSize? parseMarkupSize(String value) {
  final v = value.trim().toLowerCase();
  final step = _sizeSteps[v];
  if (step != null) return MarkupSize.factor(step);
  if (v.endsWith('%')) {
    final p = double.tryParse(v.substring(0, v.length - 1));
    return p == null ? null : MarkupSize.factor(p / 100);
  }
  final points = double.tryParse(v.replaceAll('pt', ''));
  // Pango sizes in 1024ths of a point are > 1000.
  if (points == null) return null;
  return MarkupSize.points(points > 1000 ? points / 1024 : points);
}

double? _fraction(String value) {
  final v = value.trim();
  if (v.endsWith('%')) {
    final p = double.tryParse(v.substring(0, v.length - 1));
    return p == null ? null : p / 100;
  }
  final points = double.tryParse(v.replaceAll('pt', ''));
  return points == null ? null : points / 12;
}

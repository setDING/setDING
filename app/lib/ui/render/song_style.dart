import 'package:chordpro/chordpro.dart';
import 'package:material_ui/material_ui.dart';

/// Spacing of the rendered song, in units of the font size. The widgets
/// (song_view.dart) and the layout measurement (song_layout.dart) both use
/// these values, so measured heights match the rendered ones.
abstract final class SongSpacing {
  /// Space below every block (section, notes card, chorus label).
  static const blockGap = 0.8;

  /// Indent of a chorus next to its border, plus the border in pixels.
  static const chorusIndent = 0.6;
  static const chorusBorderPixels = 3.0;

  /// Height of an empty line.
  static const emptyLine = 0.6;

  /// Space above a line with chords, and between a chord and the next one.
  static const chordLineTop = 0.1;
  static const chordGap = 0.35;

  /// Size of comments and notes relative to the lyrics.
  static const smallText = 0.85;

  /// Comment box: margin above and below, padding inside.
  static const commentMargin = 0.15;
  static const commentPaddingVertical = 0.1;
  static const commentPaddingHorizontal = 0.4;

  /// Notes card: padding, icon and the gap after it.
  static const notesPadding = 0.5;
  static const notesIcon = 1.0;
  static const notesIconGap = 0.4;

  /// Icon of the label of a repeated chorus.
  static const recallIcon = 0.9;

  /// Gap after the icon of a chorus label or a placeholder.
  static const iconGap = 0.3;

  /// Space above and below a chord diagram, an image or a placeholder.
  static const lineItemPadding = 0.15;

  /// Space below the chord diagrams of the song.
  static const diagramsBlockGap = 0.2;
}

/// Colours of the song text that differ on stage (ADR-0007).
@immutable
class StageColors extends ThemeExtension<StageColors> {
  const StageColors({required this.chord});

  /// Chord names (and grid chords): stronger than the theme's primary
  /// colour, with high contrast to the background.
  final Color chord;

  /// Deep indigo on light backgrounds (contrast about 9:1).
  static const light = StageColors(chord: Color(0xFF1A3A9E));

  /// Amber on dark and black backgrounds (contrast above 11:1), clearly
  /// apart from the light lyrics.
  static const dark = StageColors(chord: Color(0xFFFFC54D));

  @override
  StageColors copyWith({Color? chord}) =>
      StageColors(chord: chord ?? this.chord);

  @override
  StageColors lerp(StageColors? other, double t) => other == null
      ? this
      : StageColors(chord: Color.lerp(chord, other.chord, t)!);
}

/// Text styles of the song items at one font size. Rendering and layout
/// measurement use the same styles so the measured sizes match.
class SongTextStyles {
  SongTextStyles._(
    this.fontSize,
    this.lyrics,
    this.chord,
    this.label,
    this.mono,
    this.colors,
  );

  factory SongTextStyles.of(BuildContext context, double fontSize) {
    final theme = Theme.of(context);
    return SongTextStyles.fromBase(
      DefaultTextStyle.of(context).style
          .copyWith(color: theme.colorScheme.onSurface),
      fontSize,
      theme.colorScheme,
      // Live mode sets a stronger chord colour (ADR-0007).
      theme.extension<StageColors>()?.chord,
    );
  }

  /// Styles derived from [base] (the default text style of the context);
  /// chords in [chordColor], or the primary colour of [colors].
  factory SongTextStyles.fromBase(
    TextStyle base,
    double fontSize, [
    ColorScheme? colors,
    Color? chordColor,
  ]) {
    final scheme =
        colors ?? ColorScheme.fromSeed(seedColor: const Color(0xFF3F51B5));
    final text = base.merge(
      TextStyle(fontSize: fontSize, height: lineHeightFactor),
    );
    return SongTextStyles._(
      fontSize,
      text,
      text.copyWith(
        fontSize: fontSize * chordScale,
        fontWeight: FontWeight.w700,
        color: chordColor ?? scheme.primary,
      ),
      text.copyWith(
        fontSize: fontSize * labelScale,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        color: scheme.secondary,
      ),
      text.copyWith(fontFamily: 'monospace', fontSize: fontSize * monoScale),
      scheme,
    );
  }

  static const lineHeightFactor = 1.25;
  static const chordScale = 0.9;
  static const labelScale = 0.75;
  static const monoScale = 0.85;

  final double fontSize;
  final TextStyle lyrics;
  final TextStyle chord;
  final TextStyle label;
  final TextStyle mono;
  final ColorScheme colors;

  /// Lyrics style with the format directives in effect.
  TextStyle lyricsFor(FormatState format, {bool inChorus = false}) =>
      applyFormatValues(lyrics, format.lyricsValues(inChorus: inChorus));

  TextStyle chordFor(FormatState format) =>
      applyFormatValues(chord, format.valuesFor(FormatTarget.chord));

  TextStyle labelFor(FormatState format) =>
      applyFormatValues(label, format.valuesFor(FormatTarget.label));

  TextStyle tabFor(FormatState format) =>
      applyFormatValues(mono, format.valuesFor(FormatTarget.tab));

  /// Grid text (bars, margins) and grid chords.
  TextStyle gridFor(FormatState format) => applyFormatValues(
    lyrics.copyWith(fontSize: fontSize * chordScale),
    format.valuesFor(FormatTarget.grid),
  );

  TextStyle gridChordFor(FormatState format) =>
      applyFormatValues(chord, format.valuesFor(FormatTarget.grid));
}

/// Reference size in points for absolute ChordPro sizes (`{textsize: 14}`,
/// `<span size="14">`): 12 pt corresponds to the normal size of an item.
const chordProReferencePoints = 12.0;

const _serifFallback = [
  'Noto Serif',
  'DejaVu Serif',
  'Times New Roman',
  'Georgia',
];
const _monoFallback = [
  'Noto Sans Mono',
  'DejaVu Sans Mono',
  'Consolas',
  'Courier New',
  'Menlo',
];

/// Maps a ChordPro font family to a Flutter style. `sans`/`normal` keep the
/// app font; `serif` and `monospace` use generic families with fallbacks.
TextStyle withFontFamily(TextStyle style, String family) {
  final name = family.trim().toLowerCase();
  if (name.isEmpty ||
      const {
        'sans',
        'sans-serif',
        'normal',
        'helvetica',
        'arial',
      }.contains(name)) {
    return style;
  }
  if (const {
    'serif',
    'times',
    'times-roman',
    'times new roman',
  }.contains(name)) {
    return style.copyWith(
      fontFamily: 'serif',
      fontFamilyFallback: _serifFallback,
    );
  }
  if (const {'monospace', 'mono', 'courier', 'tt'}.contains(name)) {
    return style.copyWith(
      fontFamily: 'monospace',
      fontFamilyFallback: _monoFallback,
    );
  }
  return style.copyWith(fontFamily: family.trim());
}

/// Applies a ChordPro size to [style] (factor or points relative to
/// [chordProReferencePoints]).
TextStyle withSize(TextStyle style, MarkupSize size) {
  final base = style.fontSize ?? 14;
  final factor = size.factor ?? size.points! / chordProReferencePoints;
  return style.copyWith(fontSize: base * factor);
}

const _namedColours = {
  'black': Color(0xFF000000),
  'white': Color(0xFFFFFFFF),
  'red': Color(0xFFE53935),
  'green': Color(0xFF43A047),
  'blue': Color(0xFF1E88E5),
  'yellow': Color(0xFFFDD835),
  'magenta': Color(0xFFD81B60),
  'cyan': Color(0xFF00ACC1),
  'grey': Color(0xFF9E9E9E),
  'gray': Color(0xFF9E9E9E),
  'orange': Color(0xFFFB8C00),
  'purple': Color(0xFF8E24AA),
  'brown': Color(0xFF6D4C41),
  'pink': Color(0xFFF06292),
  'darkred': Color(0xFF8B0000),
  'darkgreen': Color(0xFF006400),
  'darkblue': Color(0xFF00008B),
  'lightgrey': Color(0xFFD3D3D3),
  'lightgray': Color(0xFFD3D3D3),
  'darkgrey': Color(0xFF616161),
  'darkgray': Color(0xFF616161),
};

/// Parses `#RRGGBB`, `#RGB`, `#AARRGGBB` or a colour name.
Color? parseColour(String? value) {
  if (value == null) return null;
  final v = value.trim().toLowerCase();
  final named = _namedColours[v];
  if (named != null) return named;
  if (!v.startsWith('#')) return null;
  var hex = v.substring(1);
  if (hex.length == 3) hex = hex.split('').map((c) => '$c$c').join();
  if (hex.length == 6) hex = 'ff$hex';
  if (hex.length != 8) return null;
  final n = int.tryParse(hex, radix: 16);
  return n == null ? null : Color(n);
}

/// Applies font/size/colour directive values to [style].
TextStyle applyFormatValues(TextStyle style, FormatValues values) {
  var result = style;
  if (values.font != null) result = withFontFamily(result, values.font!);
  if (values.size != null) result = withSize(result, values.size!);
  final colour = parseColour(values.colour);
  if (colour != null) result = result.copyWith(color: colour);
  return result;
}

/// Applies a markup style to [style].
TextStyle applyMarkupStyle(TextStyle style, MarkupStyle markup) {
  if (markup.isPlain) return style;
  var result = style;
  if (markup.family != null) result = withFontFamily(result, markup.family!);
  if (markup.size != null) result = withSize(result, markup.size!);
  if (markup.bold != null) {
    result = result.copyWith(
      fontWeight: markup.bold! ? FontWeight.w700 : FontWeight.w400,
    );
  }
  if (markup.italic != null) {
    result = result.copyWith(
      fontStyle: markup.italic! ? FontStyle.italic : FontStyle.normal,
    );
  }
  final foreground = parseColour(markup.foreground);
  if (foreground != null) result = result.copyWith(color: foreground);
  final background = parseColour(markup.background);
  if (background != null) {
    result = result.copyWith(backgroundColor: background);
  }

  final decorations = <TextDecoration>[];
  TextDecorationStyle? decorationStyle;
  Color? decorationColor;
  if (markup.underline != null && markup.underline != 'none') {
    decorations.add(TextDecoration.underline);
    if (markup.underline == 'double') {
      decorationStyle = TextDecorationStyle.double;
    }
    decorationColor = parseColour(markup.underlineColour);
  }
  if (markup.overline != null && markup.overline != 'none') {
    decorations.add(TextDecoration.overline);
    decorationColor ??= parseColour(markup.overlineColour);
  }
  if (markup.strikethrough ?? false) {
    decorations.add(TextDecoration.lineThrough);
    decorationColor ??= parseColour(markup.strikethroughColour);
  }
  if (decorations.isNotEmpty) {
    result = result.copyWith(
      decoration: TextDecoration.combine(decorations),
      decorationStyle: decorationStyle,
      decorationColor: decorationColor,
    );
  }
  return result;
}

/// Builds a span for [raw] text with ChordPro markup.
///
/// Runs with `rise` (sub/superscript) are shifted with a widget span unless
/// [forMeasuring] is set (text painters cannot lay out widget spans without
/// placeholder sizes).
InlineSpan markupSpan(
  String raw,
  TextStyle base, {
  String Function(String)? transform,
  bool forMeasuring = false,
}) {
  final text = transform ?? (String s) => s;
  if (!mayContainMarkup(raw)) return TextSpan(text: text(raw), style: base);
  final parsed = parseMarkup(raw);
  return TextSpan(
    style: base,
    children: [
      for (final run in parsed.runs) runSpan(run, base, text, forMeasuring),
    ],
  );
}

/// Span for one markup run (see [markupSpan]).
InlineSpan runSpan(
  MarkupRun run,
  TextStyle base,
  String Function(String) transform,
  bool forMeasuring,
) {
  final style = applyMarkupStyle(base, run.style);
  final rise = run.style.rise;
  if (rise == null || rise == 0 || forMeasuring) {
    return TextSpan(text: transform(run.text), style: style);
  }
  return WidgetSpan(
    alignment: PlaceholderAlignment.baseline,
    baseline: TextBaseline.alphabetic,
    child: Transform.translate(
      offset: Offset(0, -rise * (base.fontSize ?? 14)),
      child: Text(transform(run.text), style: style),
    ),
  );
}

/// Largest font-size factor used by markup in [raw] (for line heights).
double markupSizeFactor(String raw) {
  if (!mayContainMarkup(raw)) return 1;
  var largest = 1.0;
  for (final run in parseMarkup(raw).runs) {
    final size = run.style.size;
    if (size == null) continue;
    final factor = size.factor ?? size.points! / chordProReferencePoints;
    if (factor > largest) largest = factor;
  }
  return largest;
}

final _wordPattern = RegExp(r'\S+\s*|\s+');

/// Size of raised (superscript) chord parts relative to the chord
/// (ADR-0022).
const raisedChordScale = 0.7;

/// How far raised chord parts are lifted, relative to the chord size.
const raisedChordLift = 0.35;

/// Style of raised chord parts.
TextStyle raisedChordStyle(TextStyle style) =>
    style.copyWith(fontSize: (style.fontSize ?? 14) * raisedChordScale);

/// Width of a chord made of [parts], measured with [width].
double chordPartsWidth(
  List<ChordPart> parts,
  TextStyle style,
  double Function(String text, TextStyle style) width,
) {
  var total = 0.0;
  for (final part in parts) {
    total += width(part.text, part.raised ? raisedChordStyle(style) : style);
  }
  return total;
}

/// A chord shown as text, with raised parts as superscript.
class ChordText extends StatelessWidget {
  const ChordText(this.parts, {super.key, required this.style});

  final List<ChordPart> parts;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    if (!parts.any((p) => p.raised)) {
      return Text(
        chordPartsText(parts),
        style: style,
        softWrap: false,
        overflow: TextOverflow.visible,
      );
    }
    final lift = -(style.fontSize ?? 14) * raisedChordLift;
    final raised = raisedChordStyle(style);
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          for (final part in parts)
            if (part.raised)
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: Transform.translate(
                  offset: Offset(0, lift),
                  child: Text(part.text, style: raised, softWrap: false),
                ),
              )
            else
              TextSpan(text: part.text, style: style),
        ],
      ),
      softWrap: false,
      overflow: TextOverflow.visible,
    );
  }
}

/// A word of a chord/lyrics line, with the chord above its start.
class LinePiece {
  const LinePiece(this.chordParts, this.chordMarkup, this.runs);

  /// Formatted chord, or null.
  final List<ChordPart>? chordParts;

  /// Formatted chord as plain text, or null.
  String? get chord => chordParts == null ? null : chordPartsText(chordParts!);

  /// Markup style of the chord (e.g. `[<b>C</b>]`).
  final MarkupStyle chordMarkup;

  /// The word with its markup runs (may be empty).
  final List<MarkupRun> runs;

  String get text => runs.map((r) => r.text).join();
}

/// Splits a lyrics line into word pieces (so lines can wrap between
/// words); the chord of a segment sits on its first word. Markup may span
/// several segments.
List<LinePiece> chordLinePieces(LyricLine line, ChordFormatter formatter) {
  final raw = line.segments.map((s) => s.text).join();
  final markup = parseMarkup(raw);
  final plain = markup.plain;
  final pieces = <LinePiece>[];
  var rawPos = 0;
  for (final segment in line.segments) {
    final start = markup.plainIndex(rawPos);
    rawPos += segment.text.length;
    final end = markup.plainIndex(rawPos);
    final chordToken = segment.chord;
    final chord = chordToken == null ? null : formatter.formatParts(chordToken);
    final chordMarkup = chordToken == null
        ? MarkupStyle.plain
        : chordMarkupStyle(chordToken);
    final words = _wordPattern.allMatches(plain.substring(start, end)).toList();
    if (words.isEmpty) {
      pieces.add(LinePiece(chord, chordMarkup, const []));
      continue;
    }
    for (var i = 0; i < words.length; i++) {
      final w = words[i];
      pieces.add(
        LinePiece(
          i == 0 ? chord : null,
          chordMarkup,
          markup.slice(start + w.start, start + w.end),
        ),
      );
    }
  }
  return pieces;
}

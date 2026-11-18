import 'package:chordpro/chordpro.dart';
import 'package:material_ui/material_ui.dart';

/// Text controller of the ChordPro editor with syntax highlighting and
/// bracket matching.
///
/// Only [buildTextSpan] differs from [TextEditingController]: text,
/// selection, undo and IME composing behave as before. The source is
/// tokenized by the `chordpro` package (ADR-0003), once per text change.
class ChordProEditingController extends TextEditingController {
  ChordProEditingController({super.text});

  String? _tokenized;
  List<SourceToken> _tokens = const [];

  /// Highlighting tokens of the current text.
  List<SourceToken> get tokens {
    if (_tokenized != text) {
      _tokenized = text;
      _tokens = highlightChordPro(text);
    }
    return _tokens;
  }

  List<(int, int)> _searchMatches = const [];
  int? _currentMatch;

  /// Highlighted search matches (#368).
  List<(int, int)> get searchMatches => _searchMatches;

  /// Index of the current match in [searchMatches], highlighted stronger.
  int? get currentMatch => _currentMatch;

  /// Highlights [matches] (sorted, without overlaps), [current] stronger.
  void setSearchMatches(List<(int, int)> matches, int? current) {
    if (identical(matches, _searchMatches) && current == _currentMatch) return;
    _searchMatches = matches;
    _currentMatch = current;
    notifyListeners();
  }

  String? _sectioned;
  List<SourceSection> _sections = const [];

  /// Section environments of the current text, for their backgrounds.
  List<SourceSection> get sections {
    if (_sectioned != text) {
      _sectioned = text;
      _sections = sourceSections(text);
    }
    return _sections;
  }

  /// The bracket next to the cursor and its partner (#37), if any.
  BracketMatch? get bracketMatch {
    final sel = selection;
    if (!sel.isValid || !sel.isCollapsed) return null;
    return matchBracket(text, sel.baseOffset, tokens: tokens);
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final source = text;
    // Styles laid over the token styles: IME composing, bracket matching.
    final overlays = <(int, int, TextStyle)>[
      if (withComposing && value.isComposingRangeValid)
        (
          value.composing.start,
          value.composing.end,
          const TextStyle(decoration: TextDecoration.underline),
        ),
    ];
    if (bracketMatch case final match?) {
      final bracketStyle = match.matched
          ? TextStyle(
              color: scheme.onTertiaryContainer,
              backgroundColor: scheme.tertiaryContainer,
            )
          : TextStyle(
              color: scheme.onErrorContainer,
              backgroundColor: scheme.errorContainer,
            );
      for (final at in [match.bracket, ?match.partner]) {
        overlays.add((at, at + 1, bracketStyle));
      }
    }
    final dark = scheme.brightness == Brightness.dark;
    final matchStyle = TextStyle(
      backgroundColor: dark ? _matchDark : _matchLight,
    );
    final currentStyle = TextStyle(
      backgroundColor: dark ? _currentMatchDark : _currentMatchLight,
    );
    for (final (i, (start, end)) in _searchMatches.indexed) {
      if (end > source.length) break;
      overlays.add((
        start,
        end,
        i == _currentMatch ? currentStyle : matchStyle,
      ));
    }
    // Sorted by start, so each token only looks at the overlays near it;
    // a search can have thousands of matches.
    overlays.sort((a, b) => a.$1.compareTo(b.$1));
    final maxLength = overlays.fold(
      0,
      (m, o) => o.$2 - o.$1 > m ? o.$2 - o.$1 : m,
    );
    var first = 0;
    final children = <TextSpan>[];
    for (final token in tokens) {
      final kindStyle = chordProTokenStyle(token.kind, scheme);
      while (first < overlays.length &&
          overlays[first].$1 + maxLength <= token.start) {
        first++;
      }
      final near = <(int, int, TextStyle)>[];
      for (var j = first; j < overlays.length; j++) {
        if (overlays[j].$1 >= token.end) break;
        if (overlays[j].$2 > token.start) near.add(overlays[j]);
      }
      final cuts = <int>{
        token.start,
        for (final (start, end, _) in near) ...[
          if (start > token.start && start < token.end) start,
          if (end > token.start && end < token.end) end,
        ],
        token.end,
      }.toList()..sort();
      for (var i = 0; i + 1 < cuts.length; i++) {
        final start = cuts[i];
        final end = cuts[i + 1];
        var pieceStyle = kindStyle;
        for (final (oStart, oEnd, overlay) in near) {
          if (start >= oStart && end <= oEnd) {
            pieceStyle = (pieceStyle ?? const TextStyle()).merge(overlay);
          }
        }
        children.add(
          TextSpan(text: source.substring(start, end), style: pieceStyle),
        );
      }
    }
    return TextSpan(style: style, children: children);
  }
}

/// Background of search matches and of the current match (light, dark).
const _matchLight = Color(0x66FFD54F);
const _matchDark = Color(0x66B28F00);
const _currentMatchLight = Color(0xFFFFB74D);
const _currentMatchDark = Color(0xFFB26A00);

/// Colour of setDING's own `x_` directives (light, dark).
const _customLight = Color(0xFF00796B);
const _customDark = Color(0xFF80CBC4);

/// Editor style of a token kind; null for plain text. Not only colour:
/// chords are bold, comments italic (colour-blind friendly).
TextStyle? chordProTokenStyle(SourceTokenKind kind, ColorScheme scheme) {
  final muted = scheme.onSurfaceVariant;
  switch (kind) {
    case SourceTokenKind.text || SourceTokenKind.directiveValue:
      return null;
    case SourceTokenKind.chord:
      return TextStyle(color: scheme.primary, fontWeight: FontWeight.bold);
    case SourceTokenKind.annotation:
      return TextStyle(
        color: scheme.primary,
        fontWeight: FontWeight.bold,
        fontStyle: FontStyle.italic,
      );
    case SourceTokenKind.unknownChord:
      return TextStyle(
        color: scheme.primary,
        fontWeight: FontWeight.bold,
        decoration: TextDecoration.underline,
        decorationStyle: TextDecorationStyle.wavy,
        decorationColor: scheme.error.withValues(alpha: 0.6),
      );
    case SourceTokenKind.sectionDirective:
      return TextStyle(color: scheme.tertiary, fontWeight: FontWeight.bold);
    case SourceTokenKind.metaDirective:
      return TextStyle(color: scheme.secondary, fontWeight: FontWeight.w600);
    case SourceTokenKind.otherDirective:
      return TextStyle(color: muted);
    case SourceTokenKind.customDirective:
      return TextStyle(
        color: scheme.brightness == Brightness.dark
            ? _customDark
            : _customLight,
        fontWeight: FontWeight.w600,
      );
    case SourceTokenKind.selector:
      return TextStyle(
        color: scheme.onSecondaryContainer,
        backgroundColor: scheme.secondaryContainer,
      );
    case SourceTokenKind.attributeName:
      return TextStyle(color: scheme.secondary, fontStyle: FontStyle.italic);
    case SourceTokenKind.attributeValue:
      return TextStyle(color: scheme.onSurface);
    case SourceTokenKind.comment:
      return TextStyle(color: scheme.outline, fontStyle: FontStyle.italic);
    case SourceTokenKind.markup:
      return TextStyle(color: scheme.outline);
    case SourceTokenKind.tab || SourceTokenKind.grid:
      return TextStyle(color: muted);
    case SourceTokenKind.gridBar:
      return TextStyle(color: scheme.tertiary, fontWeight: FontWeight.bold);
    case SourceTokenKind.delegate:
      return TextStyle(
        color: muted,
        backgroundColor: scheme.surfaceContainerHighest,
      );
    case SourceTokenKind.error:
      return TextStyle(
        color: scheme.error,
        decoration: TextDecoration.underline,
        decorationColor: scheme.error,
      );
  }
}

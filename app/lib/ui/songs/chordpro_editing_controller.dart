import 'package:chordpro/chordpro.dart';
import 'package:flutter/material.dart';

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
    final children = <TextSpan>[];
    for (final token in tokens) {
      final kindStyle = chordProTokenStyle(token.kind, scheme);
      final cuts = <int>{
        token.start,
        for (final (start, end, _) in overlays) ...[
          if (start > token.start && start < token.end) start,
          if (end > token.start && end < token.end) end,
        ],
        token.end,
      }.toList()..sort();
      for (var i = 0; i + 1 < cuts.length; i++) {
        final start = cuts[i];
        final end = cuts[i + 1];
        var pieceStyle = kindStyle;
        for (final (oStart, oEnd, overlay) in overlays) {
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

/// Colour of RealChord's own `x_` directives (light, dark).
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

import 'package:chordpro/chordpro.dart';
import 'package:flutter/material.dart';

/// Text controller of the ChordPro editor with syntax highlighting.
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

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final source = text;
    final composing = withComposing && value.isComposingRangeValid
        ? value.composing
        : TextRange.empty;
    final children = <TextSpan>[];
    for (final token in tokens) {
      final kindStyle = chordProTokenStyle(token.kind, scheme);
      // Split at the composing range so the IME underline stays visible.
      final cuts = <int>{
        token.start,
        if (composing.isValid &&
            composing.start > token.start &&
            composing.start < token.end)
          composing.start,
        if (composing.isValid &&
            composing.end > token.start &&
            composing.end < token.end)
          composing.end,
        token.end,
      }.toList();
      for (var i = 0; i + 1 < cuts.length; i++) {
        final start = cuts[i];
        final end = cuts[i + 1];
        final inComposing =
            composing.isValid &&
            start >= composing.start &&
            end <= composing.end;
        children.add(
          TextSpan(
            text: source.substring(start, end),
            style: inComposing
                ? (kindStyle ?? const TextStyle()).merge(
                    const TextStyle(decoration: TextDecoration.underline),
                  )
                : kindStyle,
          ),
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

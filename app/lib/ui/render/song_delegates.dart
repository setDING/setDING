import 'package:chordpro/chordpro.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/generated/app_localizations.dart';
import 'abc_view.dart';
import 'song_image.dart';
import 'song_style.dart';

/// Layout values of a `{start_of_textblock}` (ADR-0012).
class TextBlockStyle {
  const TextBlockStyle({
    required this.sizeFactor,
    required this.textAlign,
    required this.alignment,
    required this.paddingUnits,
  });

  factory TextBlockStyle.of(Map<String, String> attributes) {
    final size = parseMarkupSize(attributes['textsize'] ?? '');
    final factor = size == null
        ? 1.0
        : size.factor ?? size.points! / chordProReferencePoints;
    TextAlign flush(String? v) => switch (v?.toLowerCase()) {
      'center' => TextAlign.center,
      'right' => TextAlign.right,
      _ => TextAlign.left,
    };
    final padding = double.tryParse(
      (attributes['padding'] ?? '').replaceAll('pt', ''),
    );
    return TextBlockStyle(
      sizeFactor: factor,
      textAlign: flush(attributes['flush']),
      alignment: switch (attributes['align']?.toLowerCase()) {
        'center' => Alignment.center,
        'right' => Alignment.centerRight,
        _ => Alignment.centerLeft,
      },
      paddingUnits: (padding ?? 0) / chordProReferencePoints,
    );
  }

  final double sizeFactor;
  final TextAlign textAlign;
  final Alignment alignment;
  final double paddingUnits;
}

/// Natural size of an SVG delegate, as an image box.
ImageBox svgDelegateBox(DelegateSection d) =>
    ImageBox.fromAttributes(d.attributes, svgSize(d.content));

/// Renders a delegated environment.
class DelegateView extends StatelessWidget {
  const DelegateView({
    super.key,
    required this.delegate,
    required this.lyrics,
    required this.label,
    required this.mono,
    required this.colors,
    this.transpose = 0,
  });

  /// Semitones for ABC notation (set and personal transposition).
  final int transpose;

  final DelegateSection delegate;
  final TextStyle lyrics;
  final TextStyle? label;
  final TextStyle mono;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    final size = lyrics.fontSize ?? 14;
    final l10n = AppLocalizations.of(context);
    final abc = delegate.type == DelegateType.abc
        ? abcTuneOf(delegate, transpose)
        : null;
    final title = delegate.label ?? abc?.title;
    final content = switch (delegate.type) {
      DelegateType.svg => SongImageView(
        box: svgDelegateBox(delegate),
        fontSize: size,
        svg: delegate.content,
      ),
      DelegateType.textblock => _TextBlock(delegate: delegate, style: lyrics),
      DelegateType.abc => AbcView(
        tune: abc!,
        fontSize: size,
        color: lyrics.color ?? colors.onSurface,
        accent: colors.primary,
        textStyle: lyrics,
      ),
      DelegateType.ly => _Source(
        notice: l10n.lilypondNotice,
        source: delegate.content,
        mono: mono,
        noticeStyle: lyrics.copyWith(
          fontSize: mono.fontSize,
          fontStyle: FontStyle.italic,
          color: colors.onSurfaceVariant,
        ),
        colors: colors,
      ),
    };
    return Padding(
      padding: EdgeInsets.only(bottom: size * SongSpacing.blockGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null && label != null)
            Text.rich(
              markupSpan(title, label!, transform: (s) => s.toUpperCase()),
            ),
          content,
        ],
      ),
    );
  }
}

class _TextBlock extends StatelessWidget {
  const _TextBlock({required this.delegate, required this.style});

  final DelegateSection delegate;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final block = TextBlockStyle.of(delegate.attributes);
    final size = (style.fontSize ?? 14) * block.sizeFactor;
    final text = style.copyWith(fontSize: size);
    return Align(
      alignment: block.alignment,
      child: Padding(
        padding: EdgeInsets.all(block.paddingUnits * (style.fontSize ?? 14)),
        child: Column(
          crossAxisAlignment: switch (block.textAlign) {
            TextAlign.center => CrossAxisAlignment.center,
            TextAlign.right => CrossAxisAlignment.end,
            _ => CrossAxisAlignment.start,
          },
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final line in delegate.lines)
              Text.rich(markupSpan(line, text), textAlign: block.textAlign),
          ],
        ),
      ),
    );
  }
}

/// Source of a delegate that cannot be rendered, with a notice.
class _Source extends StatelessWidget {
  const _Source({
    required this.notice,
    required this.source,
    required this.mono,
    required this.noticeStyle,
    required this.colors,
  });

  final String notice;
  final String source;
  final TextStyle mono;
  final TextStyle noticeStyle;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    final size = mono.fontSize ?? 12;
    return Container(
      padding: EdgeInsets.all(size * 0.5),
      decoration: BoxDecoration(
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(notice, style: noticeStyle),
          SizedBox(height: size * 0.4),
          Text(source, style: mono, softWrap: false),
        ],
      ),
    );
  }
}

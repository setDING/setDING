/// What the lyrics projection shows right now (ADR-0068 §3): the one piece
/// of data the projection server hands out.
library;

import 'package:chordpro/chordpro.dart';

/// The current state of the projection, sent to every connected browser.
///
/// Carries only what the person in live mode shows to the room anyway: the
/// lines of the current slide (and of the next one for a preview), the
/// song's title and copyright, or a blank or marker slide. No ids, no
/// library data.
class ProjectionState {
  const ProjectionState({
    this.blank = false,
    this.title,
    this.copyright,
    this.label,
    this.lines = const [],
    this.second,
    this.next,
    this.nextSecond,
    this.marker,
    this.style = const ProjectionStyle(),
  });

  /// The black screen: before live mode shows a song, while *Blank* is on,
  /// and for a set marker shown as a blank slide.
  const ProjectionState.blank({ProjectionStyle style = const ProjectionStyle()})
    : this(blank: true, style: style);

  /// A set marker shown with its text (ADR-0068 §7).
  const ProjectionState.marker(
    String text, {
    ProjectionStyle style = const ProjectionStyle(),
  }) : this(marker: text, style: style);

  /// A slide of a song (ADR-0068 §5, §8, §9), with [next] as the preview.
  /// Its label is the section's own, else [defaultLabel] (the name of its
  /// kind, #1185); none without [showLabel].
  factory ProjectionState.slide(
    LyricSlide slide, {
    String? title,
    String? copyright,
    LyricSlide? next,
    bool showLabel = true,
    String? defaultLabel,
    ProjectionStyle style = const ProjectionStyle(),
  }) => ProjectionState(
    style: style,
    title: title,
    copyright: copyright,
    label: showLabel ? slide.source.label ?? defaultLabel : null,
    lines: slide.lines,
    second: slide.second,
    next: next?.lines,
    nextSecond: next?.second,
  );

  /// Whether the screen is black.
  final bool blank;

  final String? title;

  /// `{copyright}` of the song, shown on the slide.
  final String? copyright;

  /// The section's label (`Verse 1`), shown small above the lyrics.
  final String? label;

  /// The lines of the slide (`''` = paragraph break).
  final List<String> lines;

  /// The lines of the second language, null without one.
  final List<String>? second;

  /// The lines of the next slide for the preview, null at the end.
  final List<String>? next;
  final List<String>? nextSecond;

  /// The text of a set marker shown as a text slide.
  final String? marker;

  /// How the page shows it (projection settings, ADR-0068 §11).
  final ProjectionStyle style;

  /// The JSON sent to the page. `v` is the format version, raised when the
  /// page must change with it.
  Map<String, Object?> toJson() => {
    'v': 1,
    'blank': blank,
    if (title != null) 'title': title,
    if (copyright != null) 'copyright': copyright,
    if (label != null) 'label': label,
    'lines': lines,
    if (second != null) 'second': second,
    if (next != null) 'next': next,
    if (nextSecond != null) 'nextSecond': nextSecond,
    if (marker != null) 'marker': marker,
    'style': style.toJson(),
  };
}

/// Colours of the projected page; the lower third is always white on its
/// dark band.
enum ProjectionTheme { dark, light }

enum ProjectionFont { sans, serif }

enum ProjectionAlign { center, left }

/// The look of the projected page, from the projection settings
/// (ADR-0068 §11). The page has no settings of its own.
class ProjectionStyle {
  const ProjectionStyle({
    this.theme = ProjectionTheme.dark,
    this.font = ProjectionFont.sans,
    this.align = ProjectionAlign.center,
  });

  final ProjectionTheme theme;
  final ProjectionFont font;
  final ProjectionAlign align;

  Map<String, Object?> toJson() => {
    'theme': theme.name,
    'font': font.name,
    'align': align.name,
  };
}

/// Where the copyright is shown on the slides of a song (ADR-0068 §8).
enum ProjectionCopyright { everySlide, firstAndLast }

/// The choices of *lines per slide* in the projection settings.
const projectionLineChoices = [2, 4, 6, 8, 10, 12];

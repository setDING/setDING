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
  });

  /// The black screen: before live mode shows a song, while *Blank* is on,
  /// and for a set marker shown as a blank slide.
  const ProjectionState.blank() : this(blank: true);

  /// A set marker shown with its text (ADR-0068 §7).
  const ProjectionState.marker(String text) : this(marker: text);

  /// A slide of a song (ADR-0068 §5, §8, §9), with [next] as the preview.
  factory ProjectionState.slide(
    LyricSlide slide, {
    String? title,
    String? copyright,
    LyricSlide? next,
  }) => ProjectionState(
    title: title,
    copyright: copyright,
    label: slide.source.label,
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

  /// The section's label (`Verse 1`), if it has one.
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
  };
}

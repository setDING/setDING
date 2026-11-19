import 'package:chordpro/chordpro.dart';
import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/annotation.dart' show textHash;

/// Marks a rendered line of a song with its source line and a fingerprint
/// of its text, so freehand annotations can be anchored to it (ADR-0032).
@immutable
class LineMark {
  const LineMark(this.line, this.hash);

  /// Source line number (`sourceLineOf`).
  final int line;

  /// [textHash] of the line's text without chords and markup.
  final int hash;
}

/// The text a [LineMark] fingerprints: what a reader recognizes the line by.
String anchorText(Object element) => switch (element) {
  final LyricLine l => l.plainText.trim(),
  final CommentLine c => c.text.trim(),
  final RawLine r => r.text.trim(),
  final Section s => s.label ?? s.name ?? '',
  final ChorusRecall c => c.label ?? '',
  final DelegateSection d => d.label ?? '',
  _ => '',
};

/// [child] marked as the rendered line of [element]; unchanged when the
/// element has no source line (e.g. built by the app).
Widget markLine(Object? element, Widget child) {
  if (element == null) return child;
  final line = sourceLineOf(element);
  if (line == null) return child;
  return MetaData(
    metaData: LineMark(line, textHash(anchorText(element))),
    behavior: HitTestBehavior.deferToChild,
    child: child,
  );
}

/// A rendered line: its mark, which repetition of the line it is (a chorus
/// shown twice) and where it is, in the coordinates of the box the lines
/// were collected for.
typedef RenderedLine = ({LineMark mark, int repeat, Rect rect});

/// The marked lines below [root] in document order, positioned relative to
/// [ancestor].
List<RenderedLine> collectLines(RenderObject root, RenderBox ancestor) {
  final lines = <RenderedLine>[];
  final seen = <int, int>{};
  void visit(RenderObject o) {
    if (o is RenderMetaData && o.metaData is LineMark && o.hasSize) {
      final mark = o.metaData as LineMark;
      final repeat = seen[mark.line] ?? 0;
      seen[mark.line] = repeat + 1;
      final transform = o.getTransformTo(ancestor);
      final rect = MatrixUtils.transformRect(transform, Offset.zero & o.size);
      lines.add((mark: mark, repeat: repeat, rect: rect));
    }
    o.visitChildren(visit);
  }

  visit(root);
  return lines;
}

/// The marks of all lines of [song] (as [markLine] marks them), to tell a
/// stroke whose line is on another page from one whose line is gone.
({Set<int> lines, Set<int> hashes}) songLineMarks(Song song) {
  final lines = <int>{}, hashes = <int>{};
  void add(Object element) {
    final line = sourceLineOf(element);
    if (line == null) return;
    lines.add(line);
    hashes.add(textHash(anchorText(element)));
  }

  for (final e in song.elements) {
    add(e);
    if (e is Section) {
      for (final line in e.lines) {
        add(line);
        // Stacked verses (#521): each row is its verse's line.
        if (line is StackedLine) {
          for (final row in line.rows) {
            add(row.line);
          }
        }
      }
    }
  }
  return (lines: lines, hashes: hashes);
}

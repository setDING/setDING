import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/data/annotation.dart';
import 'package:setding/ui/annotations/annotation_placement.dart';
import 'package:setding/ui/render/line_marks.dart';

/// Where freehand annotations go on a page (ADR-0032).
void main() {
  LayoutFingerprint layout({
    double width = 800,
    double height = 600,
    double font = 20,
    int content = 1,
  }) => LayoutFingerprint(
    mode: 'page',
    width: width,
    height: height,
    font: font,
    content: content,
  );

  RenderedLine line(int number, int hash, Rect rect, {int repeat = 0}) =>
      (mark: LineMark(number, hash), repeat: repeat, rect: rect);

  final lines = [
    line(3, 30, const Rect.fromLTWH(0, 0, 400, 40)),
    line(4, 40, const Rect.fromLTWH(0, 40, 400, 40)),
    line(9, 30, const Rect.fromLTWH(0, 200, 400, 40), repeat: 1),
  ];

  PagePlacement on(LayoutFingerprint l, {double font = 20, int page = 0}) =>
      PagePlacement(
        width: l.width,
        page: page,
        layout: l,
        lines: lines,
        font: font,
        songLines: (lines: {3, 4, 9}, hashes: {30, 40}),
      );

  test('a stroke drawn here goes back exactly where it was drawn', () {
    final here = on(layout());
    final s = here.toStroke(
      id: 'a',
      tool: AnnotationTool.pen,
      color: 1,
      points: const [Offset(100, 50), Offset(700, 580)],
      lineWidth: 2,
    );
    expect(s.page, 0);
    expect(s.points, [0.125, 0.0625, 0.875, 0.725]);
    expect(s.width, 2 / 800);
    // Anchored to the line under its start (line 4 at y 40…80).
    expect(s.anchor!.line, 4);
    expect(s.anchor!.dx, 5);
    expect(s.anchor!.dy, 0.5);

    final placed = here.place(s)!;
    expect(placed.points, const [Offset(100, 50), Offset(700, 580)]);
    expect(placed.width, 2);
    // Free arrows keep their place: far from any line, still exact.
    expect(
      on(layout(height: 590)).place(s)!.points.last,
      const Offset(700, 580),
    );
    // Another page of the same layout does not show it.
    expect(on(layout(), page: 1).place(s), isNull);
  });

  test('on another layout a stroke follows its line and the font size', () {
    final s = on(layout()).toStroke(
      id: 'a',
      tool: AnnotationTool.pen,
      color: 0,
      points: const [Offset(100, 50), Offset(140, 50)],
      lineWidth: 2,
    );
    // Rotated: other size, font 30; line 4 now at (10, 300).
    final rotated = PagePlacement(
      width: 600,
      page: 0,
      layout: layout(width: 600, height: 800, font: 30),
      lines: [line(4, 40, const Rect.fromLTWH(10, 300, 300, 60))],
      font: 30,
    );
    final placed = rotated.place(s)!;
    // Start: line + (5, 0.5) × 30; length 40 × 30/20.
    expect(placed.points.first, const Offset(160, 315));
    expect(placed.points.last, const Offset(220, 315));
    expect(placed.width, 3);
  });

  test('a changed line is found by its text, then by its number', () {
    final s = on(layout()).toStroke(
      id: 'a',
      tool: AnnotationTool.pen,
      color: 0,
      points: const [Offset(10, 205), Offset(20, 205)],
      lineWidth: 2,
    );
    // The second chorus (line 9, repeat 1).
    expect((s.anchor!.line, s.anchor!.repeat), (9, 1));

    // Lines moved down by two after an edit: found by text and repeat.
    final edited = PagePlacement(
      width: 800,
      page: 0,
      layout: layout(content: 2),
      lines: [
        line(5, 30, const Rect.fromLTWH(0, 0, 400, 40)),
        line(11, 30, const Rect.fromLTWH(0, 400, 400, 40), repeat: 1),
      ],
      font: 20,
    );
    expect(edited.place(s)!.points.first, const Offset(10, 405));

    // The text corrected: found by line number and repeat.
    final corrected = PagePlacement(
      width: 800,
      page: 0,
      layout: layout(content: 3),
      lines: [line(9, 99, const Rect.fromLTWH(0, 100, 400, 40), repeat: 1)],
      font: 20,
    );
    expect(corrected.place(s)!.points.first, const Offset(10, 105));
  });

  test('a stroke whose line is elsewhere or gone', () {
    final s = on(layout()).toStroke(
      id: 'a',
      tool: AnnotationTool.pen,
      color: 0,
      points: const [Offset(10, 45), Offset(20, 45)],
      lineWidth: 2,
    );
    // Another layout whose page does not have line 4, but the song has.
    final otherPage = PagePlacement(
      width: 800,
      page: 1,
      layout: layout(content: 2),
      lines: [line(3, 30, const Rect.fromLTWH(0, 0, 400, 40))],
      font: 20,
      songLines: (lines: {3, 4}, hashes: {30, 40}),
    );
    expect(otherPage.place(s, withOrphans: true), isNull);

    // The line is gone from the song: orphaned, shown while drawing only,
    // on the page it was drawn on.
    final gone = PagePlacement(
      width: 800,
      page: 0,
      layout: layout(content: 2),
      lines: [line(3, 30, const Rect.fromLTWH(0, 0, 400, 40))],
      font: 20,
      songLines: (lines: {3}, hashes: {30}),
    );
    expect(gone.place(s), isNull);
    final orphan = gone.place(s, withOrphans: true)!;
    expect(orphan.orphan, isTrue);
    expect(orphan.points.first, const Offset(10, 45));
  });

  test('PDF pages: page number and page width only', () {
    final pdf = PagePlacement(width: 400, page: 2);
    final s = pdf.toStroke(
      id: 'p',
      tool: AnnotationTool.highlighter,
      color: 3,
      points: const [Offset(40, 80)],
      lineWidth: 10,
    );
    expect((s.page, s.layout, s.anchor), (2, null, null));
    // Zoomed in: twice as wide, same place on the page.
    expect(
      PagePlacement(width: 800, page: 2).place(s)!.points.single,
      const Offset(80, 160),
    );
    expect(PagePlacement(width: 400, page: 1).place(s), isNull);
  });

  test('restore keeps the ID and anchors anew', () {
    final here = on(layout());
    final s = here.toStroke(
      id: 'a',
      tool: AnnotationTool.pen,
      color: 0,
      points: const [Offset(10, 5), Offset(20, 5)],
      lineWidth: 2,
    );
    final moved = here.restore(here.place(s)!.moved(const Offset(0, 40)));
    expect(moved.id, 'a');
    expect(moved.anchor!.line, 4);
    final recoloured = here.restore(here.place(s)!, color: 5);
    expect(recoloured.color, 5);
    expect(recoloured.points, s.points);
  });

  test('simplify and scale helpers', () {
    final (points, pressure) = simplifyStroke(
      [for (var i = 0; i <= 10; i++) Offset(i.toDouble(), 0)],
      [for (var i = 0; i <= 10; i++) i / 10],
    );
    expect(points, const [Offset(0, 0), Offset(10, 0)]);
    expect(pressure, [0, 1]);
    expect(
      scaleAround(const [Offset(0, 0), Offset(10, 0)], const Offset(5, 0), 2),
      const [Offset(-5, 0), Offset(15, 0)],
    );
  });
}

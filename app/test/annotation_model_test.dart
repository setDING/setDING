import 'package:flutter_test/flutter_test.dart';
import 'package:setding/data/annotation.dart';

/// The model of freehand annotations (ADR-0032).
void main() {
  const layout = LayoutFingerprint(
    mode: 'page',
    pages: 2,
    width: 1000,
    height: 700,
    font: 24,
    columns: 2,
    content: 42,
    sequence: 'V1 C',
  );

  AnnotationStroke pen({List<double>? points, List<double>? pressure}) =>
      AnnotationStroke(
        id: 'a',
        tool: AnnotationTool.pen,
        color: 2,
        width: 0.004,
        points: points ?? const [0.1, 0.2, 0.3, 0.25, 0.5, 0.4],
        pressure: pressure,
        page: 1,
        layout: layout,
        anchor: const LineAnchor(
          line: 7,
          hash: 1234,
          repeat: 1,
          dx: 0.5,
          dy: -1.25,
          font: 24,
        ),
      );

  group('JSON', () {
    test('a stroke survives the round trip', () {
      final s = pen(pressure: const [0, 0.5, 1]);
      final back = AnnotationStroke.fromJson('a', s.toJson())!;
      expect(back.tool, AnnotationTool.pen);
      expect(back.color, 2);
      expect(back.page, 1);
      expect(back.layout, layout);
      expect(back.anchor, s.anchor);
      expect(back.points, s.points);
      for (final (i, p) in back.pressure!.indexed) {
        expect(p, closeTo(s.pressure![i], 1 / 255));
      }
    });

    test('a stamp keeps its symbol', () {
      const s = AnnotationStroke(
        id: 'b',
        tool: AnnotationTool.stamp,
        width: 0.05,
        points: [0.5, 0.5],
        stamp: AnnotationStamp.fermata,
      );
      final back = AnnotationStroke.fromJson('b', s.toJson())!;
      expect(back.stamp, AnnotationStamp.fermata);
      expect(back.layout, isNull);
    });

    test('a text keeps its lines; an empty one is dropped (#570)', () {
      const s = AnnotationStroke(
        id: 't',
        tool: AnnotationTool.text,
        color: 1,
        width: 0.02,
        points: [0.2, 0.3],
        text: 'leise!\n2× Intro',
      );
      final json = s.toJson();
      expect(json['text'], 'leise!\n2× Intro');
      final back = AnnotationStroke.fromJson('t', json)!;
      expect(back.tool, AnnotationTool.text);
      expect(back.text, 'leise!\n2× Intro');
      expect(back.points, [0.2, 0.3]);
      expect(back, s);
      expect(AnnotationStroke.fromJson('t', {...json, 'text': '  \n'}), isNull);
      expect(AnnotationStroke.fromJson('t', {...json}..remove('text')), isNull);
      expect(
        pen().toJson().containsKey('text'),
        isFalse,
        reason: 'only a text stores one',
      );
      expect(
        AnnotationStroke.fromJson('a', {...pen().toJson(), 'text': 'x'})!.text,
        isNull,
      );
    });

    test('points are quantized to 1/10000 of the page width', () {
      final s = pen(points: const [0.123456, 2.5, -0.00004, 0.99999]);
      expect(AnnotationStroke.fromJson('a', s.toJson())!.points, [
        0.1235,
        2.5,
        0,
        1,
      ]);
    });

    test('tombstones, unknown tools and broken data give null', () {
      expect(AnnotationStroke.fromJson('a', annotationTombstone(5)), isNull);
      expect(
        AnnotationStroke.fromJson('a', {...pen().toJson(), 'tool': 'laser'}),
        isNull,
      );
      expect(
        AnnotationStroke.fromJson('a', {...pen().toJson(), 'pts': '%%%'}),
        isNull,
      );
      expect(
        AnnotationStroke.fromJson('a', {...pen().toJson(), 'tool': 'stamp'}),
        isNull,
        reason: 'a stamp needs its symbol',
      );
      expect(AnnotationStroke.fromJson('a', 'text'), isNull);
    });

    test('an unknown colour index is clamped', () {
      expect(
        AnnotationStroke.fromJson('a', {...pen().toJson(), 'color': 99})!.color,
        annotationColorCount - 1,
      );
    });
  });

  group('layout fingerprint', () {
    test('the same layout within the tolerance matches', () {
      expect(layout.matches(layout), isTrue);
      const barShown = LayoutFingerprint(
        mode: 'page',
        pages: 2,
        width: 1000,
        height: 680,
        font: 23.5,
        columns: 2,
        content: 42,
        sequence: 'V1 C',
      );
      expect(barShown.matches(layout), isTrue);
    });

    test('chords in verse 1 only or stacked verses are other layouts and '
        'round-trip', () {
      LayoutFingerprint verses(String mode) => LayoutFingerprint(
        mode: 'page',
        pages: 2,
        width: 1000,
        height: 700,
        font: 24,
        columns: 2,
        verseChords: mode,
        content: 42,
        sequence: 'V1 C',
      );
      final verse1 = verses('first'), stacked = verses('stacked');
      expect(verse1.matches(layout), isFalse);
      expect(stacked.matches(layout), isFalse);
      expect(stacked.matches(verse1), isFalse);
      expect(LayoutFingerprint.fromJson(verse1.toJson()), verse1);
      expect(LayoutFingerprint.fromJson(stacked.toJson()), stacked);
      expect(layout.toJson().containsKey('verses'), isFalse);
      // The boolean of #518 before #521.
      final old = verse1.toJson()
        ..remove('verses')
        ..['verse1'] = true;
      expect(LayoutFingerprint.fromJson(old), verse1);
    });

    test('another orientation, font, text or sequence does not match', () {
      LayoutFingerprint with_({
        double width = 1000,
        double height = 700,
        double font = 24,
        int content = 42,
        String sequence = 'V1 C',
        int pages = 2,
        String mode = 'page',
      }) => LayoutFingerprint(
        mode: mode,
        pages: pages,
        width: width,
        height: height,
        font: font,
        columns: 2,
        content: content,
        sequence: sequence,
      );
      expect(with_(width: 700, height: 1000).matches(layout), isFalse);
      expect(with_(font: 30).matches(layout), isFalse);
      expect(with_(content: 43).matches(layout), isFalse);
      expect(with_(sequence: 'V1').matches(layout), isFalse);
      expect(with_(pages: 3).matches(layout), isFalse);
      expect(with_(mode: 'scroll').matches(layout), isFalse);
      expect(
        with_(mode: 'screen').matches(with_(mode: 'screen')),
        isFalse,
        reason: 'the song screen always uses the line anchor',
      );
    });

    test('a scrolled body ignores its height', () {
      const a = LayoutFingerprint(
        mode: 'scroll',
        width: 800,
        height: 3000,
        font: 20,
        content: 1,
      );
      const b = LayoutFingerprint(
        mode: 'scroll',
        width: 800,
        height: 600,
        font: 20,
        content: 1,
      );
      expect(a.matches(b), isTrue);
    });
  });

  group('geometry', () {
    test('textHash is stable', () {
      expect(textHash('Amazing grace'), textHash('Amazing grace'));
      expect(textHash('Amazing grace'), isNot(textHash('Amazing Grace')));
      expect(textHash(''), 0x811c9dc5);
    });

    test('simplify keeps corners and drops points on a line', () {
      final points = <double>[];
      for (var i = 0; i <= 10; i++) {
        points.addAll([i / 10, 0]);
      }
      for (var i = 1; i <= 10; i++) {
        points.addAll([1, i / 10]);
      }
      final kept = simplifyIndices(points, 0.001);
      expect(kept, [0, 10, 20]);
    });

    test('the partial eraser splits a stroke', () {
      final points = <double>[
        for (var i = 0; i <= 10; i++) ...[i / 10, 0],
      ];
      final pieces = eraseAround(points, 0.5, 0, 0.11)!;
      expect(pieces, [
        [0, 1, 2, 3],
        [7, 8, 9, 10],
      ]);
      expect(eraseAround(points, 0.5, 0.5, 0.1), isNull);
    });

    test('the eraser catches a segment passing through it', () {
      const points = [0.0, 0.0, 1.0, 0.0];
      expect(strokeNear(points, 0.5, 0.01, 0.02), isTrue);
      expect(eraseAround(points, 0.5, 0.01, 0.02), isNotNull);
      expect(strokeNear(points, 0.5, 0.1, 0.02), isFalse);
    });

    test('point in polygon (lasso)', () {
      const square = [0.0, 0.0, 1.0, 0.0, 1.0, 1.0, 0.0, 1.0];
      expect(pointInPolygon(0.5, 0.5, square), isTrue);
      expect(pointInPolygon(1.5, 0.5, square), isFalse);
    });
  });
}

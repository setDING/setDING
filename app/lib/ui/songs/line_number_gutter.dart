import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';

/// Line numbers to the left of the ChordPro editor (#36).
///
/// The numbers are positioned by the editor's own text layout, so they stay
/// aligned with wrapped lines, while scrolling and while typing. A number
/// belongs to the first visual row of its source line.
class LineNumberGutter extends StatefulWidget {
  const LineNumberGutter({
    super.key,
    required this.fieldKey,
    required this.controller,
    required this.scrollController,
    required this.style,
  });

  /// Key of the editor's [TextField].
  final GlobalKey fieldKey;
  final TextEditingController controller;
  final ScrollController scrollController;

  /// Text style of the editor (font and line height are reused).
  final TextStyle style;

  /// Horizontal padding around the numbers.
  static const padding = 8.0;

  @override
  State<LineNumberGutter> createState() => _LineNumberGutterState();
}

class _LineNumberGutterState extends State<LineNumberGutter> {
  final _paintKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final LineNumberGutter(:controller, :scrollController, :style) = widget;
    final scheme = Theme.of(context).colorScheme;
    final numberStyle = style.copyWith(color: scheme.outline);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final lines = '\n'.allMatches(controller.text).length + 1;
        final digits = lines.toString().length.clamp(2, 6);
        final digitWidth = (TextPainter(
          text: TextSpan(text: '0' * digits, style: numberStyle),
          textDirection: TextDirection.ltr,
        )..layout()).width;
        // A new painter per layout, so a resize (other wrapping) repaints.
        return LayoutBuilder(
          builder: (context, constraints) => CustomPaint(
            key: _paintKey,
            size: Size(
              digitWidth + 2 * LineNumberGutter.padding,
              constraints.maxHeight,
            ),
            painter: _LineNumberPainter(
              fieldKey: widget.fieldKey,
              gutterKey: _paintKey,
              style: numberStyle,
              repaint: Listenable.merge([controller, scrollController]),
            ),
          ),
        );
      },
    );
  }
}

/// The [RenderEditable] inside the text field with [fieldKey].
RenderEditable? findRenderEditable(GlobalKey fieldKey) {
  RenderEditable? result;
  void visit(RenderObject object) {
    if (result != null) return;
    if (object is RenderEditable) {
      result = object;
    } else {
      object.visitChildren(visit);
    }
  }

  final root = fieldKey.currentContext?.findRenderObject();
  if (root != null) visit(root);
  return result;
}

/// Vertical centre of the first visual row of every source line of the
/// text of [editable], in the coordinates of [target]: (line number, centre).
List<(int, double)> lineNumberCentres(
  RenderEditable editable,
  RenderBox target,
) {
  final text = editable.plainText;
  final result = <(int, double)>[];
  var line = 1;
  var offset = 0;
  while (true) {
    final caret = editable.getLocalRectForCaret(TextPosition(offset: offset));
    final centre = target
        .globalToLocal(editable.localToGlobal(caret.center))
        .dy;
    result.add((line, centre));
    final next = text.indexOf('\n', offset);
    if (next < 0) break;
    offset = next + 1;
    line++;
  }
  return result;
}

class _LineNumberPainter extends CustomPainter {
  _LineNumberPainter({
    required this.fieldKey,
    required this.gutterKey,
    required this.style,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final GlobalKey fieldKey;
  final GlobalKey gutterKey;
  final TextStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final editable = findRenderEditable(fieldKey);
    final gutter = gutterKey.currentContext?.findRenderObject();
    if (editable == null || gutter is! RenderBox || !editable.hasSize) return;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (final (number, centre) in lineNumberCentres(editable, gutter)) {
      final painter = TextPainter(
        text: TextSpan(text: '$number', style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      final top = centre - painter.height / 2;
      if (top > size.height) break;
      if (top + painter.height < 0) continue;
      painter.paint(
        canvas,
        Offset(size.width - LineNumberGutter.padding - painter.width, top),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LineNumberPainter old) => true;
}

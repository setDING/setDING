import 'package:material_ui/material_ui.dart';
import 'package:flutter/gestures.dart';
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
    this.focusNode,
  });

  /// Focus of the editor; focused when lines are selected by tapping or
  /// dragging over the numbers (#383).
  final FocusNode? focusNode;

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

  /// Line where a drag over the numbers started.
  int? _anchor;

  /// Index of the source line shown at the global vertical position [y].
  int? _lineAt(double y) {
    final editable = findRenderEditable(widget.fieldKey);
    if (editable == null || !editable.hasSize) return null;
    final left = editable.localToGlobal(Offset.zero).dx;
    final offset = editable
        .getPositionForPoint(Offset(left + 1, y))
        .offset
        .clamp(0, widget.controller.text.length);
    return '\n'.allMatches(widget.controller.text.substring(0, offset)).length;
  }

  /// Selects the lines from [from] to [to] (in any order), each with its
  /// line break, as a block that the line commands and dragging handle.
  void _selectLines(int from, int to) {
    final text = widget.controller.text;
    final first = from < to ? from : to;
    final last = from < to ? to : from;
    int lineStart(int line) {
      var offset = 0;
      for (var i = 0; i < line; i++) {
        final nl = text.indexOf('\n', offset);
        if (nl < 0) return text.length;
        offset = nl + 1;
      }
      return offset;
    }

    widget.focusNode?.requestFocus();
    widget.controller.selection = TextSelection(
      baseOffset: lineStart(first),
      extentOffset: lineStart(last + 1),
    );
  }

  void _tap(TapUpDetails details) {
    if (_lineAt(details.globalPosition.dy) case final line?) {
      _selectLines(line, line);
    }
  }

  void _dragStart(DragStartDetails details) {
    _anchor = _lineAt(details.globalPosition.dy);
    if (_anchor case final line?) _selectLines(line, line);
  }

  void _dragUpdate(DragUpdateDetails details) {
    final anchor = _anchor;
    final line = _lineAt(details.globalPosition.dy);
    if (anchor != null && line != null) _selectLines(anchor, line);
  }

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
          builder: (context, constraints) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            // The selection starts at the line first touched.
            dragStartBehavior: DragStartBehavior.down,
            onTapUp: _tap,
            onVerticalDragStart: _dragStart,
            onVerticalDragUpdate: _dragUpdate,
            onVerticalDragEnd: (_) => _anchor = null,
            child: CustomPaint(
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

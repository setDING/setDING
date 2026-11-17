import 'package:chordpro/chordpro.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'line_number_gutter.dart';

/// Drag and drop of the selected text with the mouse in the ChordPro
/// editor (#377), which Flutter's text field does not offer.
///
/// A layer above the text field takes the pointer only where the mouse
/// presses on the selection; everywhere else the text field handles it as
/// usual. Dragging shows where the text will go, Ctrl or Alt (Option)
/// while dropping copies instead of moving, a selection of whole lines is
/// dropped between lines. Clicking the selection without dragging places
/// the cursor, a double click selects the word, a right click opens the
/// context menu, as in the text field.
class SelectionDragDrop extends StatefulWidget {
  const SelectionDragDrop({
    super.key,
    required this.fieldKey,
    required this.controller,
    required this.scrollController,
    required this.focusNode,
    required this.child,
  });

  /// Key of the editor's [TextField].
  final GlobalKey fieldKey;
  final TextEditingController controller;
  final ScrollController scrollController;
  final FocusNode focusNode;
  final Widget child;

  /// Distance the mouse moves before a press becomes a drag.
  static const dragSlop = 4.0;

  /// Height of the zones at the top and bottom that scroll while dragging.
  static const scrollZone = 24.0;

  @override
  State<SelectionDragDrop> createState() => _SelectionDragDropState();
}

class _SelectionDragDropState extends State<SelectionDragDrop> {
  bool _mouseInside = false;
  Offset? _down;
  bool _dragging = false;
  int? _drop;
  Duration? _lastClick;
  final _layerKey = GlobalKey();

  RenderEditable? get _editable => findRenderEditable(widget.fieldKey);

  TextSelection? get _selection {
    final sel = widget.controller.selection;
    return sel.isValid && !sel.isCollapsed ? sel : null;
  }

  /// Whether the selection is made of whole lines (dropped between lines).
  bool _wholeLines(TextSelection sel) {
    final text = widget.controller.text;
    return (sel.start == 0 || text[sel.start - 1] == '\n') &&
        (sel.end == text.length || text[sel.end - 1] == '\n');
  }

  /// Whether the layer takes a pointer at [global]: the mouse is on the
  /// selection (or a drag is going on).
  bool _takesPointer(Offset global) {
    if (_dragging) return true;
    final sel = _selection;
    final editable = _editable;
    if (!_mouseInside || sel == null || editable == null) return false;
    final local = editable.globalToLocal(global);
    return editable
        .getBoxesForSelection(sel)
        .any((box) => box.toRect().inflate(1).contains(local));
  }

  void _onDown(PointerDownEvent event) {
    final editable = _editable;
    if (editable == null) return;
    if (event.buttons & kSecondaryMouseButton != 0) {
      editable.handleSecondaryTapDown(
        TapDownDetails(globalPosition: event.position),
      );
      widget.focusNode.requestFocus();
      findEditableTextState(widget.fieldKey)?.showToolbar();
      return;
    }
    if (event.buttons & kPrimaryMouseButton == 0) return;
    _down = event.position;
  }

  void _onMove(PointerMoveEvent event) {
    final down = _down;
    final editable = _editable;
    if (down == null || editable == null) return;
    if (!_dragging &&
        (event.position - down).distance < SelectionDragDrop.dragSlop) {
      return;
    }
    _autoScroll(event.position);
    setState(() {
      _dragging = true;
      _drop = editable.getPositionForPoint(event.position).offset;
    });
  }

  /// Scrolls the editor while the mouse is near its top or bottom edge.
  void _autoScroll(Offset global) {
    final layer = _layerKey.currentContext?.findRenderObject();
    final scroll = widget.scrollController;
    if (layer is! RenderBox || !scroll.hasClients) return;
    final y = layer.globalToLocal(global).dy;
    final height = layer.size.height;
    const zone = SelectionDragDrop.scrollZone;
    final delta = y < zone
        ? -zone
        : y > height - zone
        ? zone
        : 0.0;
    if (delta == 0) return;
    final position = scroll.position;
    scroll.jumpTo(
      (position.pixels + delta).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      ),
    );
  }

  void _onUp(PointerUpEvent event) {
    final down = _down;
    final editable = _editable;
    final dragging = _dragging;
    final drop = _drop;
    _reset();
    if (down == null || editable == null) return;
    widget.focusNode.requestFocus();
    if (dragging && drop != null) {
      final sel = _selection;
      if (sel == null) return;
      final keyboard = HardwareKeyboard.instance;
      final edit = dropText(
        widget.controller.text,
        sel.start,
        sel.end,
        drop: drop,
        copy: keyboard.isControlPressed || keyboard.isAltPressed,
      );
      if (edit == null) return;
      widget.controller.value = TextEditingValue(
        text: edit.text,
        selection: TextSelection(
          baseOffset: edit.base,
          extentOffset: edit.extent,
        ),
      );
      return;
    }
    // A click on the selection: as in the text field.
    final last = _lastClick;
    _lastClick = event.timeStamp;
    if (last != null && event.timeStamp - last < kDoubleTapTimeout) {
      editable.selectWordsInRange(
        from: event.position,
        cause: SelectionChangedCause.doubleTap,
      );
    } else {
      editable.selectPositionAt(
        from: event.position,
        cause: SelectionChangedCause.tap,
      );
    }
  }

  void _reset() {
    _down = null;
    if (_dragging || _drop != null) {
      setState(() {
        _dragging = false;
        _drop = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sel = _selection;
    return MouseRegion(
      onEnter: (_) => _mouseInside = true,
      onExit: (_) => _mouseInside = false,
      child: Stack(
        children: [
          widget.child,
          Positioned.fill(
            // Part of the text field for "tap outside" handling.
            child: TextFieldTapRegion(
              child: _HitGate(
                key: _layerKey,
                takesPointer: _takesPointer,
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: _onDown,
                  onPointerMove: _onMove,
                  onPointerUp: _onUp,
                  onPointerCancel: (_) => _reset(),
                  child: MouseRegion(
                    cursor: _dragging
                        ? SystemMouseCursors.move
                        : SystemMouseCursors.basic,
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: _DropPainter(
                        editable: _editable,
                        layerKey: _layerKey,
                        drop: _drop,
                        wholeLines: sel != null && _wholeLines(sel),
                        text: widget.controller.text,
                        colour: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The [EditableTextState] inside the text field with [fieldKey].
EditableTextState? findEditableTextState(GlobalKey fieldKey) {
  EditableTextState? result;
  void visit(Element element) {
    if (result != null) return;
    if (element is StatefulElement && element.state is EditableTextState) {
      result = element.state as EditableTextState;
    } else {
      element.visitChildren(visit);
    }
  }

  fieldKey.currentContext?.visitChildElements(visit);
  return result;
}

/// Takes part in hit testing only where [takesPointer] says so.
class _HitGate extends SingleChildRenderObjectWidget {
  const _HitGate({super.key, required this.takesPointer, super.child});

  final bool Function(Offset global) takesPointer;

  @override
  _RenderHitGate createRenderObject(BuildContext context) =>
      _RenderHitGate(takesPointer);

  @override
  void updateRenderObject(BuildContext context, _RenderHitGate renderObject) {
    renderObject.takesPointer = takesPointer;
  }
}

class _RenderHitGate extends RenderProxyBox {
  _RenderHitGate(this.takesPointer);

  bool Function(Offset global) takesPointer;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!size.contains(position) || !takesPointer(localToGlobal(position))) {
      return false;
    }
    return super.hitTest(result, position: position);
  }
}

/// The drop position while dragging: a caret, or a line between lines for
/// a selection of whole lines.
class _DropPainter extends CustomPainter {
  _DropPainter({
    required this.editable,
    required this.layerKey,
    required this.drop,
    required this.wholeLines,
    required this.text,
    required this.colour,
  });

  final RenderEditable? editable;
  final GlobalKey layerKey;
  final int? drop;
  final bool wholeLines;
  final String text;
  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    final editable = this.editable;
    final layer = layerKey.currentContext?.findRenderObject();
    var drop = this.drop;
    if (editable == null || layer is! RenderBox || drop == null) return;
    drop = drop.clamp(0, text.length);
    if (wholeLines) {
      final lineStart = drop == 0 ? 0 : text.lastIndexOf('\n', drop - 1) + 1;
      final onLastLineEnd =
          drop == text.length && !text.endsWith('\n') && lineStart < drop;
      if (!onLastLineEnd) drop = lineStart;
    }
    final caret = editable.getLocalRectForCaret(TextPosition(offset: drop));
    final topLeft = layer.globalToLocal(editable.localToGlobal(caret.topLeft));
    final paint = Paint()
      ..color = colour
      ..strokeWidth = 2;
    if (wholeLines) {
      // At the end of the last line the text goes below it.
      final y = drop == text.length && !text.endsWith('\n')
          ? topLeft.dy + caret.height
          : topLeft.dy;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    } else {
      canvas.drawLine(topLeft, topLeft.translate(0, caret.height), paint);
    }
  }

  @override
  bool shouldRepaint(_DropPainter old) =>
      old.drop != drop || old.wholeLines != wholeLines || old.text != text;
}

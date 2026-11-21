import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:uuid/uuid.dart';

import '../../data/annotation.dart';
import '../../l10n/generated/app_localizations.dart';
import '../render/line_marks.dart';
import 'annotation_editor.dart';
import 'annotation_paint.dart';
import 'annotation_placement.dart';

const _uuid = Uuid();

/// Freehand annotations over one page (ADR-0032): a page of a song in live
/// mode, the scrolled song, or a page of a PDF. Shows the strokes (the
/// highlighter behind [child], the rest above it) and, while [editor] is
/// active, draws, erases and selects with a stylus or a mouse (fingers only
/// when the editor allows it; otherwise they keep turning pages).
class AnnotationLayer extends StatefulWidget {
  const AnnotationLayer({
    super.key,
    required this.songId,
    this.target = '',
    required this.page,
    required this.strokes,
    this.layout,
    this.font = 20,
    this.songLines,
    this.editor,
    this.visible = true,
    this.fill = 0,
    required this.child,
  });

  final String songId;

  /// Empty for the ChordPro text, otherwise the PDF attachment's ID.
  final String target;

  /// The page shown (see [PagePlacement.page]).
  final int page;

  /// All strokes of the song on [target].
  final List<AnnotationStroke> strokes;

  /// Layout of a ChordPro page; null for a PDF page.
  final LayoutFingerprint? layout;

  /// Font size of the page, for line anchors and line widths.
  final double font;

  /// Lines of the whole song, to tell orphaned strokes (ChordPro only).
  final ({Set<int> lines, Set<int> hashes})? songLines;

  /// Drawing mode; null = show only.
  final AnnotationEditor? editor;

  /// The annotations are shown (hidden ones still show while drawing).
  final bool visible;

  /// Share of [annotationMaxBytes] the strokes on [target] take: drawing
  /// mode warns when they are nearly full.
  final double fill;

  final Widget child;

  @override
  State<AnnotationLayer> createState() => _AnnotationLayerState();
}

class _AnnotationLayerState extends State<AnnotationLayer> {
  final _childKey = GlobalKey();
  List<RenderedLine> _lines = const [];
  bool _collecting = false;

  // The gesture in progress.
  List<Offset>? _drawing;
  List<double>? _pressure;
  bool _pressureSeen = false;
  DrawingTool? _gestureTool;
  Offset? _downAt;
  List<Offset>? _lasso;
  Offset? _moveStart;
  Offset _moveOffset = Offset.zero;

  /// A text being typed (#570): its top left corner on the page and, when an
  /// existing text is edited, that one (hidden meanwhile).
  ({Offset at, PlacedStroke? editing})? _text;
  final _textController = TextEditingController();
  late final _textFocus = FocusNode(
    debugLabel: 'annotation text',
    onKeyEvent: _onTextKey,
  );
  final _textFieldKey = GlobalKey();

  /// How far the text field is lifted so the on-screen keyboard does not
  /// cover it.
  double _textLift = 0;

  /// The gesture in progress closed the text field: it does not open
  /// another one.
  bool _textClosedByGesture = false;

  /// The pointer whose tap beside the text field closed it.
  int? _textClosedBy;

  /// Strokes erased by the gesture so far.
  final _erased = <String>{};

  /// Pieces left of strokes erased in part: indices into their [_dense]
  /// points.
  final _pieces = <String, List<List<int>>>{};

  /// Points (and pressure) of strokes erased in part, resampled so that a
  /// cut can fall between two stored points.
  final _dense = <String, (List<Offset>, List<double>?)>{};

  AnnotationEditor? get _editor => widget.editor;
  bool get _editing => _editor?.active ?? false;

  @override
  void initState() {
    super.initState();
    _editor?.addListener(_onEditor);
    _editor?.selectionActions.addListener(_onAction);
  }

  @override
  void didUpdateWidget(AnnotationLayer old) {
    super.didUpdateWidget(old);
    if (old.editor != widget.editor) {
      old.editor?.removeListener(_onEditor);
      old.editor?.selectionActions.removeListener(_onAction);
      _editor?.addListener(_onEditor);
      _editor?.selectionActions.addListener(_onAction);
    }
  }

  @override
  void dispose() {
    // A page turned away while typing keeps its text.
    _commitText(rebuild: false);
    _editor?.removeListener(_onEditor);
    _editor?.selectionActions.removeListener(_onAction);
    _textController.dispose();
    _textFocus.dispose();
    super.dispose();
  }

  void _onEditor() {
    if (!mounted) return;
    // Leaving drawing mode or the text tool stores the text being typed.
    if (_text != null && (!_editing || _editor!.tool != DrawingTool.text)) {
      _commitText();
    }
    setState(() {});
  }

  bool get _needsLines =>
      widget.layout != null && (widget.strokes.isNotEmpty || _editing);

  /// Collects the rendered lines after layout, when they changed.
  void _scheduleLines() {
    // Not while a stroke is drawn: the lines do not move meanwhile.
    if (_collecting || !_needsLines || _gestureTool != null) return;
    _collecting = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _collecting = false;
      if (!mounted) return;
      final root = _childKey.currentContext?.findRenderObject();
      final self = context.findRenderObject();
      if (root == null || self is! RenderBox || !self.hasSize) return;
      final lines = collectLines(root, self);
      if (!_sameLines(lines, _lines)) setState(() => _lines = lines);
    });
  }

  static bool _sameLines(List<RenderedLine> a, List<RenderedLine> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].mark.line != b[i].mark.line ||
          a[i].mark.hash != b[i].mark.hash ||
          a[i].rect != b[i].rect) {
        return false;
      }
    }
    return true;
  }

  PagePlacement _placement(double width) => PagePlacement(
    width: width,
    page: widget.page,
    layout: widget.layout,
    lines: _lines,
    font: widget.font,
    songLines: widget.songLines,
  );

  bool _isSelected(String id) {
    final s = _editor?.selection;
    return s != null &&
        s.songId == widget.songId &&
        s.target == widget.target &&
        s.page == widget.page &&
        s.ids.contains(id);
  }

  Set<String> get _selectedIds {
    final s = _editor?.selection;
    if (s == null ||
        s.songId != widget.songId ||
        s.target != widget.target ||
        s.page != widget.page) {
      return const {};
    }
    return s.ids;
  }

  // Placement -----------------------------------------------------------------

  double _width = 0;
  List<PlacedStroke> _placed = const [];

  List<PlacedStroke> _place(double width) {
    final placement = _placement(width);
    return [
      for (final s in widget.strokes)
        ?placement.place(s, withOrphans: _editing),
    ];
  }

  /// What is painted: placed strokes with the gesture's erasures applied.
  List<PlacedStroke> get _shown => [
    for (final p in _placed)
      if (!_erased.contains(p.stroke.id))
        if (_pieces[p.stroke.id] case final pieces?)
          for (final piece in pieces)
            PlacedStroke(
              stroke: p.stroke,
              points: [for (final i in piece) _dense[p.stroke.id]!.$1[i]],
              width: p.width,
            )
        else
          p,
  ];

  /// [placed]'s points with at most [step] between two of them.
  static (List<Offset>, List<double>?) _densify(
    PlacedStroke placed,
    double step,
  ) {
    final points = placed.points;
    final pressure = placed.stroke.pressure;
    final outPoints = <Offset>[points.first];
    final outPressure = pressure == null ? null : <double>[pressure.first];
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1], b = points[i];
      final n = math.max(1, ((b - a).distance / step).ceil());
      for (var k = 1; k <= n; k++) {
        outPoints.add(Offset.lerp(a, b, k / n)!);
        outPressure?.add(
          pressure![i - 1] + (pressure[i] - pressure[i - 1]) * k / n,
        );
      }
    }
    return (outPoints, outPressure);
  }

  // Input ----------------------------------------------------------------------

  bool _accepts(PointerDeviceKind kind) => switch (kind) {
    PointerDeviceKind.stylus ||
    PointerDeviceKind.invertedStylus ||
    PointerDeviceKind.mouse => true,
    PointerDeviceKind.touch => _editor?.fingerDraws ?? false,
    _ => false,
  };

  void _onStart(PointerEvent e) {
    final editor = _editor!;
    final p = e.localPosition;
    final tool = e.kind == PointerDeviceKind.invertedStylus
        ? DrawingTool.eraser
        : editor.tool;
    _gestureTool = tool;
    _downAt = p;
    _textClosedByGesture = e.pointer == _textClosedBy;
    if (_text != null) {
      // A pointer beside the text field ends typing.
      _commitText();
      _textClosedByGesture = true;
    }
    setState(() {
      switch (tool) {
        case DrawingTool.pen || DrawingTool.highlighter:
          _drawing = [p];
          _pressureSeen = e.kind == PointerDeviceKind.stylus;
          _pressure = [_normalizedPressure(e)];
        case DrawingTool.eraser || DrawingTool.partialEraser:
          _erase(p, partial: tool == DrawingTool.partialEraser);
        case DrawingTool.lasso:
          final selected = _selectionBounds();
          if (selected != null && selected.inflate(12).contains(p)) {
            _moveStart = p;
            _moveOffset = Offset.zero;
          } else if (_strokeAt(p) case final hit?) {
            // Touching a stroke selects it, and dragging moves it right away.
            editor.selection = (
              songId: widget.songId,
              target: widget.target,
              page: widget.page,
              ids: {hit.stroke.id},
            );
            _moveStart = p;
            _moveOffset = Offset.zero;
          } else {
            editor.selection = null;
            _lasso = [p];
          }
        case DrawingTool.stamp || DrawingTool.text:
          break;
      }
    });
  }

  static double _normalizedPressure(PointerEvent e) {
    final range = e.pressureMax - e.pressureMin;
    if (range <= 0) return 0.5;
    return ((e.pressure - e.pressureMin) / range).clamp(0.0, 1.0);
  }

  void _onMove(PointerEvent e) {
    final p = e.localPosition;
    setState(() {
      switch (_gestureTool) {
        case DrawingTool.pen || DrawingTool.highlighter:
          _drawing?.add(p);
          _pressure?.add(_normalizedPressure(e));
        case DrawingTool.eraser || DrawingTool.partialEraser:
          _erase(p, partial: _gestureTool == DrawingTool.partialEraser);
        case DrawingTool.lasso:
          if (_moveStart != null) {
            _moveOffset = p - _moveStart!;
          } else {
            _lasso?.add(p);
          }
        case DrawingTool.stamp || DrawingTool.text || null:
          break;
      }
    });
  }

  void _onEnd(PointerEvent e) {
    final editor = _editor!;
    final placement = _placement(_width);
    final tool = _gestureTool;
    switch (tool) {
      case DrawingTool.pen || DrawingTool.highlighter:
        final points = _drawing;
        if (points != null && points.isNotEmpty) {
          final (kept, pressure) = simplifyStroke(
            points,
            _pressureSeen && tool == DrawingTool.pen ? _pressure : null,
          );
          final stroke = placement.toStroke(
            id: _uuid.v4(),
            tool: tool == DrawingTool.pen
                ? AnnotationTool.pen
                : AnnotationTool.highlighter,
            color: editor.color,
            points: kept,
            lineWidth: editor.lineWidth(widget.font, tool: tool),
            pressure: pressure,
          );
          editor.commit(widget.songId, widget.target, after: [stroke]);
        }
      case DrawingTool.stamp:
        final at = _downAt;
        if (at != null && (e.localPosition - at).distance < 16) {
          editor.commit(
            widget.songId,
            widget.target,
            after: [
              placement.toStroke(
                id: _uuid.v4(),
                tool: AnnotationTool.stamp,
                color: editor.color,
                points: [at],
                lineWidth: editor.stampSize(widget.font),
                stamp: editor.stamp,
              ),
            ],
          );
        }
      case DrawingTool.text:
        final at = _downAt;
        if (!_textClosedByGesture &&
            at != null &&
            (e.localPosition - at).distance < 16) {
          _openText(at);
        }
      case DrawingTool.eraser || DrawingTool.partialEraser:
        _commitErase(placement);
      case DrawingTool.lasso:
        if (_moveStart != null) {
          final offset = _moveOffset;
          if (offset.distance > 1) {
            final selected = [
              for (final p in _placed)
                if (_isSelected(p.stroke.id)) p,
            ];
            editor.commit(
              widget.songId,
              widget.target,
              before: [for (final p in selected) p.stroke],
              after: [
                for (final p in selected) placement.restore(p.moved(offset)),
              ],
            );
          }
        } else if (_lasso case final lasso? when lasso.length > 2) {
          final polygon = [
            for (final p in lasso) ...[p.dx, p.dy],
          ];
          bool inside(PlacedStroke s) {
            if (s.stroke.tool == AnnotationTool.text) {
              final c = s.bounds.center;
              return pointInPolygon(c.dx, c.dy, polygon);
            }
            final n = s.points
                .where((p) => pointInPolygon(p.dx, p.dy, polygon))
                .length;
            return n * 2 >= s.points.length;
          }

          editor.selection = (
            songId: widget.songId,
            target: widget.target,
            page: widget.page,
            ids: {
              for (final p in _placed)
                if (inside(p)) p.stroke.id,
            },
          );
        }
      case null:
        break;
    }
    _reset();
  }

  void _onCancel() => _reset();

  void _reset() {
    if (!mounted) return;
    setState(() {
      _drawing = null;
      _pressure = null;
      _gestureTool = null;
      _downAt = null;
      _lasso = null;
      _moveStart = null;
      _moveOffset = Offset.zero;
      _erased.clear();
      _pieces.clear();
      _dense.clear();
    });
  }

  void _erase(Offset p, {required bool partial}) {
    final radius = _editor!.eraserRadius(widget.font);
    for (final placed in _placed) {
      final id = placed.stroke.id;
      if (_erased.contains(id)) continue;
      final flat = [
        for (final q in placed.points) ...[q.dx, q.dy],
      ];
      final tool = placed.stroke.tool;
      if (!partial ||
          tool == AnnotationTool.stamp ||
          tool == AnnotationTool.text) {
        final near = switch (tool) {
          AnnotationTool.stamp =>
            (placed.points.first - p).distance <= radius + placed.width / 2,
          AnnotationTool.text => placed.bounds.inflate(radius).contains(p),
          _ => strokeNear(flat, p.dx, p.dy, radius + placed.width / 2),
        };
        if (near) _erased.add(id);
        continue;
      }
      final (dense, _) = _dense[id] ??= _densify(placed, radius / 3);
      final denseFlat = [
        for (final q in dense) ...[q.dx, q.dy],
      ];
      final pieces =
          _pieces[id] ??
          [
            [for (var i = 0; i < dense.length; i++) i],
          ];
      final next = <List<int>>[];
      var changed = false;
      for (final piece in pieces) {
        final pieceFlat = [
          for (final i in piece) ...[denseFlat[2 * i], denseFlat[2 * i + 1]],
        ];
        final split = piece.length < 2
            ? null
            : eraseAround(pieceFlat, p.dx, p.dy, radius + placed.width / 2);
        if (split == null) {
          next.add(piece);
        } else {
          changed = true;
          for (final part in split) {
            next.add([for (final j in part) piece[j]]);
          }
        }
      }
      if (!changed) continue;
      if (next.isEmpty) {
        _erased.add(id);
        _pieces.remove(id);
      } else {
        _pieces[id] = next;
      }
    }
  }

  void _commitErase(PagePlacement placement) {
    final before = <AnnotationStroke>[];
    final after = <AnnotationStroke>[];
    for (final placed in _placed) {
      final id = placed.stroke.id;
      if (_erased.contains(id)) {
        before.add(placed.stroke);
      } else if (_pieces[id] case final pieces?) {
        before.add(placed.stroke);
        final (dense, densePressure) = _dense[id]!;
        for (final piece in pieces) {
          final (points, pressure) = simplifyStroke(
            [for (final i in piece) dense[i]],
            densePressure == null
                ? null
                : [for (final i in piece) densePressure[i]],
          );
          after.add(
            placement.restore(
              placed,
              id: _uuid.v4(),
              points: points,
              pressure: pressure,
            ),
          );
        }
      }
    }
    _editor!.commit(widget.songId, widget.target, before: before, after: after);
  }

  // Text ------------------------------------------------------------------------

  /// Opens the text field for a tap at [p]: on the text there to edit it,
  /// otherwise for a new text whose first line is centred on [p].
  void _openText(Offset p) {
    final editor = _editor!;
    PlacedStroke? hit;
    for (final placed in _placed) {
      if (placed.stroke.tool == AnnotationTool.text &&
          placed.bounds.inflate(8).contains(p)) {
        hit = placed; // The last one is on top.
      }
    }
    final size = hit?.width ?? editor.textSize(widget.font);
    final at =
        hit?.points.first ??
        p - Offset(size * 0.1, annotationTextSize('X', size).height / 2);
    _textController.text = hit?.stroke.text ?? '';
    _textController.selection = TextSelection.collapsed(
      offset: _textController.text.length,
    );
    editor.selection = null;
    setState(() {
      _text = (at: at, editing: hit);
      _textLift = 0;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _text != null) _textFocus.requestFocus();
    });
  }

  /// Stores the text being typed: a new text, the edited one, or, when it
  /// was emptied, erases it.
  void _commitText({bool rebuild = true}) {
    final open = _text;
    final editor = _editor;
    if (open == null || editor == null) return;
    _text = null;
    final text = _textController.text.trimRight();
    final placement = _placement(_width);
    final editing = open.editing;
    // From dispose the change is stored after the frame: it rebuilds the
    // other pages, which must not happen while the tree is locked.
    void commit({
      List<AnnotationStroke> before = const [],
      List<AnnotationStroke> after = const [],
    }) {
      void store() => editor.commit(
        widget.songId,
        widget.target,
        before: before,
        after: after,
      );
      rebuild ? store() : scheduleMicrotask(store);
    }

    if (editing == null) {
      if (text.trim().isNotEmpty) {
        commit(
          after: [
            placement.toStroke(
              id: _uuid.v4(),
              tool: AnnotationTool.text,
              color: editor.color,
              points: [open.at],
              lineWidth: editor.textSize(widget.font),
              text: text,
            ),
          ],
        );
      }
    } else if (text.trim().isEmpty) {
      commit(before: [editing.stroke]);
    } else if (text != editing.stroke.text) {
      commit(
        before: [editing.stroke],
        after: [placement.restore(editing, text: text)],
      );
    }
    _closeText(rebuild: rebuild);
  }

  void _closeText({bool rebuild = true}) {
    _text = null;
    if (_textFocus.hasFocus) _textFocus.unfocus();
    if (rebuild && mounted) setState(() {});
  }

  /// Enter stores the text, Shift+Enter starts a new line (the text field
  /// does that), Escape drops it.
  KeyEventResult _onTextKey(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      if (HardwareKeyboard.instance.isShiftPressed) {
        return KeyEventResult.ignored;
      }
      if (event is KeyDownEvent) _commitText();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      if (event is KeyDownEvent) _closeText();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// Lifts the text field above the on-screen keyboard.
  void _scheduleTextLift() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _text == null) return;
      final box = _textFieldKey.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.hasSize) return;
      final media = MediaQuery.of(context);
      final visibleBottom = media.size.height - media.viewInsets.bottom - 8;
      final bottom =
          box.localToGlobal(Offset(0, box.size.height)).dy + _textLift;
      final lift = math.max(0.0, bottom - visibleBottom);
      if ((lift - _textLift).abs() > 0.5) setState(() => _textLift = lift);
    });
  }

  Widget _textField(BuildContext context, double width) {
    final open = _text!;
    final editor = _editor!;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final editing = open.editing;
    final size = editing?.width ?? editor.textSize(widget.font);
    final color = annotationColor(
      editing?.stroke.color ?? editor.color,
      theme.brightness,
    );
    const pad = 6.0;
    final left = (open.at.dx - pad)
        .clamp(0.0, math.max(0.0, width - 160))
        .toDouble();
    _scheduleTextLift();
    return Positioned(
      left: left,
      top: open.at.dy - pad - _textLift,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: math.max(160.0, width - left)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withValues(alpha: 0.85),
                  border: Border.all(color: color, width: 1.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(pad - 1.5),
                  child: IntrinsicWidth(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: size * 4),
                      child: TextField(
                        key: _textFieldKey,
                        controller: _textController,
                        focusNode: _textFocus,
                        style: annotationTextStyle(size, color: color),
                        cursorColor: color,
                        keyboardType: TextInputType.multiline,
                        textCapitalization: TextCapitalization.sentences,
                        minLines: 1,
                        maxLines: null,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(
                            annotationTextMaxLength,
                          ),
                        ],
                        decoration: InputDecoration.collapsed(
                          hintText: l10n.annotationTextHint,
                          hintStyle: annotationTextStyle(
                            size,
                            color: color.withValues(alpha: 0.45),
                          ),
                        ),
                        // A tap beside the field stores the text; on this
                        // page it does not open a new field.
                        onTapOutside: (e) {
                          _textClosedBy = e.pointer;
                          _commitText();
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton.filled(
              key: const Key('annotation-text-done'),
              tooltip: l10n.annotationDone,
              icon: const Icon(Icons.check),
              onPressed: _commitText,
            ),
          ],
        ),
      ),
    );
  }

  /// The topmost stroke within a finger's reach of [p], if any.
  PlacedStroke? _strokeAt(Offset p) {
    const reach = 12.0;
    for (final placed in _placed.reversed) {
      final near = switch (placed.stroke.tool) {
        AnnotationTool.stamp =>
          (placed.points.first - p).distance <= reach + placed.width / 2,
        AnnotationTool.text => placed.bounds.inflate(reach).contains(p),
        _ => strokeNear(
          [
            for (final q in placed.points) ...[q.dx, q.dy],
          ],
          p.dx,
          p.dy,
          reach + placed.width / 2,
        ),
      };
      if (near) return placed;
    }
    return null;
  }

  Rect? _selectionBounds() {
    Rect? bounds;
    for (final p in _placed) {
      if (!_isSelected(p.stroke.id)) continue;
      bounds = bounds == null ? p.bounds : bounds.expandToInclude(p.bounds);
    }
    return bounds;
  }

  /// A request of the toolbar for the selection on this page.
  void _onAction() {
    final action = _editor?.selectionActions.value;
    final ids = _selectedIds;
    if (action == null || ids.isEmpty || !mounted) return;
    final editor = _editor!;
    final selected = [
      for (final p in _placed)
        if (ids.contains(p.stroke.id)) p,
    ];
    if (selected.isEmpty) return;
    final placement = _placement(_width);
    final before = [for (final p in selected) p.stroke];
    switch (action) {
      case SelectionAction.delete:
        editor.selection = null;
        editor.commit(widget.songId, widget.target, before: before);
      case SelectionAction.recolour:
        editor.commit(
          widget.songId,
          widget.target,
          before: before,
          after: [
            for (final p in selected) placement.restore(p, color: editor.color),
          ],
        );
      case SelectionAction.larger || SelectionAction.smaller:
        final factor = action == SelectionAction.larger ? 1.25 : 0.8;
        final center = _selectionBounds()!.center;
        editor.commit(
          widget.songId,
          widget.target,
          before: before,
          after: [
            for (final p in selected)
              placement.restore(
                p,
                points: scaleAround(p.points, center, factor),
                lineWidth: p.width * factor,
                pressure: p.stroke.pressure,
              ),
          ],
        );
    }
  }

  // Build ------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    _scheduleLines();
    final brightness = Theme.of(context).brightness;
    final show = widget.visible || _editing;
    return LayoutBuilder(
      builder: (context, constraints) {
        _width = constraints.maxWidth;
        _placed = show && _width.isFinite && _width > 0
            ? _place(_width)
            : const [];
        final editedId = _text?.editing?.stroke.id;
        final shown = editedId == null
            ? _shown
            : [
                for (final p in _shown)
                  if (p.stroke.id != editedId) p,
              ];
        final selected = _selectedIds;
        final editing = _editing;
        final current = widget.layout;
        final others = !editing || current == null
            ? const <LayoutFingerprint>[]
            : [
                for (final s in widget.strokes)
                  if (s.layout case final l? when !current.matches(l)) l,
              ];
        final orphans = editing ? shown.where((p) => p.orphan).length : 0;
        final full = editing && (_editor!.full || widget.fill >= 1);
        final nearlyFull =
            editing && !full && widget.fill >= annotationWarnShare;
        final preview = _drawing;
        return Stack(
          children: [
            if (shown.any((p) => p.stroke.tool == AnnotationTool.highlighter))
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _StrokesPainter(
                      shown,
                      brightness: brightness,
                      highlighters: true,
                      selected: selected,
                      offset: _moveOffset,
                    ),
                  ),
                ),
              ),
            KeyedSubtree(key: _childKey, child: widget.child),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _StrokesPainter(
                    [
                      ...shown,
                      if (preview != null && preview.isNotEmpty)
                        _previewStroke(preview),
                    ],
                    brightness: brightness,
                    highlighters: false,
                    selected: selected,
                    offset: _moveOffset,
                    lasso: _lasso,
                    previewHighlighter:
                        preview != null &&
                            _gestureTool == DrawingTool.highlighter
                        ? _previewStroke(preview)
                        : null,
                  ),
                ),
              ),
            ),
            if (editing)
              Positioned.fill(
                child: RawGestureDetector(
                  behavior: HitTestBehavior.translucent,
                  gestures: {
                    _DrawRecognizer:
                        GestureRecognizerFactoryWithHandlers<_DrawRecognizer>(
                          () => _DrawRecognizer(debugOwner: this),
                          (r) => r
                            ..accepts = _accepts
                            ..onStart = _onStart
                            ..onMove = _onMove
                            ..onEnd = _onEnd
                            ..onCancel = _onCancel,
                        ),
                  },
                ),
              ),
            if (editing && _text != null) _textField(context, _width),
            if (others.isNotEmpty || orphans > 0 || full || nearlyFull)
              Positioned(
                top: 4,
                right: 4,
                child: _Hints(
                  otherLayout: others.isEmpty
                      ? null
                      : others.every((l) => l.landscape && !current!.landscape)
                      ? _OtherLayout.landscape
                      : others.every((l) => !l.landscape && current!.landscape)
                      ? _OtherLayout.portrait
                      : _OtherLayout.other,
                  orphans: orphans,
                  fill: full
                      ? 1
                      : nearlyFull
                      ? widget.fill
                      : null,
                ),
              ),
          ],
        );
      },
    );
  }

  PlacedStroke _previewStroke(List<Offset> points) {
    final editor = _editor!;
    final tool = _gestureTool == DrawingTool.highlighter
        ? AnnotationTool.highlighter
        : AnnotationTool.pen;
    return PlacedStroke(
      stroke: AnnotationStroke(
        id: '',
        tool: tool,
        color: editor.color,
        width: 0,
        points: const [0, 0],
        pressure: _pressureSeen && tool == AnnotationTool.pen
            ? _pressure
            : null,
      ),
      points: points,
      width: editor.lineWidth(widget.font, tool: _gestureTool),
    );
  }
}

class _StrokesPainter extends CustomPainter {
  _StrokesPainter(
    this.strokes, {
    required this.brightness,
    required this.highlighters,
    required this.selected,
    required this.offset,
    this.lasso,
    this.previewHighlighter,
  });

  final List<PlacedStroke> strokes;
  final Brightness brightness;
  final bool highlighters;
  final Set<String> selected;
  final Offset offset;
  final List<Offset>? lasso;

  /// A highlighter being drawn: shown above the text until it is stored.
  final PlacedStroke? previewHighlighter;

  @override
  void paint(Canvas canvas, Size size) {
    paintStrokes(
      canvas,
      strokes,
      brightness: brightness,
      highlighters: highlighters,
      selected: selected,
      selectionOffset: offset,
    );
    if (previewHighlighter case final p?) {
      paintStroke(
        canvas,
        p,
        annotationColor(
          p.stroke.color,
          brightness,
        ).withValues(alpha: highlighterOpacity),
      );
    }
    final lasso = this.lasso;
    if (lasso != null && lasso.length > 1) {
      final path = Path()..addPolygon(lasso, true);
      canvas.drawPath(
        path,
        Paint()
          ..color =
              (brightness == Brightness.dark ? Colors.white : Colors.black)
                  .withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(_StrokesPainter old) =>
      !identical(old.strokes, strokes) ||
      old.brightness != brightness ||
      old.selected != selected ||
      old.offset != offset ||
      old.lasso != lasso ||
      old.previewHighlighter != previewHighlighter;
}

enum _OtherLayout { landscape, portrait, other }

/// Hints while drawing: strokes drawn for another layout (placed at their
/// lines), strokes whose line is gone, and annotations that are (nearly)
/// full.
class _Hints extends StatelessWidget {
  const _Hints({
    required this.otherLayout,
    required this.orphans,
    required this.fill,
  });

  final _OtherLayout? otherLayout;
  final int orphans;

  /// Share of [annotationMaxBytes] used when nearly full, 1 when full;
  /// null otherwise.
  final double? fill;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    Widget chip(IconData icon, String text, Key key, {bool error = false}) {
      final background = error
          ? theme.colorScheme.errorContainer
          : theme.colorScheme.secondaryContainer;
      final foreground = error
          ? theme.colorScheme.onErrorContainer
          : theme.colorScheme.onSecondaryContainer;
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Material(
          key: key,
          color: background,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: foreground),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    text,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: foreground,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return IgnorePointer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (otherLayout case final other?)
            chip(Icons.devices_other, switch (other) {
              _OtherLayout.landscape => l10n.annotationsOtherLayoutLandscape,
              _OtherLayout.portrait => l10n.annotationsOtherLayoutPortrait,
              _OtherLayout.other => l10n.annotationsOtherLayout,
            }, const Key('annotations-other-layout')),
          if (orphans > 0)
            chip(
              Icons.link_off,
              l10n.annotationsOrphaned(orphans),
              const Key('annotations-orphaned'),
            ),
          if (fill case final f?)
            f >= 1
                ? chip(
                    Icons.block,
                    l10n.annotationsFull,
                    const Key('annotations-full'),
                    error: true,
                  )
                : chip(
                    Icons.warning_amber,
                    l10n.annotationsNearlyFull((f * 100).floor()),
                    const Key('annotations-nearly-full'),
                  ),
        ],
      ),
    );
  }
}

/// Wins the gesture arena at once for the pointers that draw, so a stroke
/// never scrolls the page or turns it; other pointers (fingers, unless they
/// draw) do not take part and keep their gestures.
class _DrawRecognizer extends OneSequenceGestureRecognizer {
  _DrawRecognizer({super.debugOwner});

  bool Function(PointerDeviceKind kind) accepts = (_) => false;
  void Function(PointerEvent event)? onStart;
  void Function(PointerEvent event)? onMove;
  void Function(PointerEvent event)? onEnd;
  VoidCallback? onCancel;

  int? _pointer;

  @override
  bool isPointerAllowed(PointerDownEvent event) =>
      _pointer == null && accepts(event.kind) && super.isPointerAllowed(event);

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    _pointer = event.pointer;
    resolve(GestureDisposition.accepted);
    onStart?.call(event);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event.pointer != _pointer) return;
    if (event is PointerMoveEvent) {
      onMove?.call(event);
    } else if (event is PointerUpEvent) {
      onEnd?.call(event);
      _pointer = null;
      stopTrackingPointer(event.pointer);
    } else if (event is PointerCancelEvent) {
      onCancel?.call();
      _pointer = null;
      stopTrackingPointer(event.pointer);
    }
  }

  @override
  void rejectGesture(int pointer) {
    if (pointer == _pointer) {
      onCancel?.call();
      _pointer = null;
    }
    super.rejectGesture(pointer);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {}

  @override
  String get debugDescription => 'draw annotation';
}

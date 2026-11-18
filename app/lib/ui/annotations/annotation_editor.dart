import 'package:material_ui/material_ui.dart';

import '../../data/annotation_repository.dart';

/// What a pointer does in drawing mode (ADR-0032).
enum DrawingTool { pen, highlighter, eraser, partialEraser, lasso, stamp }

/// Line widths per [DrawingTool] at the three sizes, in units of the font
/// size (so they look alike on every layout).
const _penWidths = [0.07, 0.12, 0.2];
const _highlighterWidths = [0.6, 0.9, 1.3];
const _stampSizes = [1.4, 2.0, 2.8];

/// One undoable change: the strokes of [songId] and [target] before and
/// after it.
typedef _Change = ({
  String songId,
  String target,
  List<AnnotationStroke> before,
  List<AnnotationStroke> after,
});

/// Which strokes are selected with the lasso, on which song and target.
typedef AnnotationSelection = ({
  String songId,
  String target,
  int page,
  Set<String> ids,
});

/// State of drawing mode in live mode (ADR-0032): the tool and its colour
/// and size, the lasso selection, and undo/redo of the session. The pages
/// of live mode share it; changes are stored with [repository].
class AnnotationEditor extends ChangeNotifier {
  AnnotationEditor(this.repository);

  AnnotationRepository repository;

  bool _active = false;

  /// Drawing mode is on.
  bool get active => _active;
  set active(bool value) {
    if (value == _active) return;
    _active = value;
    _selection = null;
    if (!value) {
      _undo.clear();
      _redo.clear();
    }
    notifyListeners();
  }

  DrawingTool _tool = DrawingTool.pen;
  DrawingTool get tool => _tool;
  set tool(DrawingTool value) {
    if (value == _tool) return;
    _tool = value;
    if (value != DrawingTool.lasso) _selection = null;
    notifyListeners();
  }

  int _color = 0;

  /// Palette index of new strokes.
  int get color => _color;

  int _size = 1;

  /// Size of new strokes: 0 (fine), 1 or 2 (bold).
  int get size => _size;
  set size(int value) {
    _size = value.clamp(0, 2);
    notifyListeners();
  }

  AnnotationStamp _stamp = AnnotationStamp.fermata;

  /// The stamp placed by the stamp tool.
  AnnotationStamp get stamp => _stamp;
  set stamp(AnnotationStamp value) {
    _stamp = value;
    _tool = DrawingTool.stamp;
    _selection = null;
    notifyListeners();
  }

  /// Fingers draw too, not only a stylus or a mouse (for devices without a
  /// stylus).
  bool get fingerDraws => _fingerDraws;
  bool _fingerDraws = false;
  set fingerDraws(bool value) {
    if (value == _fingerDraws) return;
    _fingerDraws = value;
    notifyListeners();
  }

  /// Width of a new line at [font] in logical pixels.
  double lineWidth(double font, {DrawingTool? tool}) =>
      font *
      ((tool ?? _tool) == DrawingTool.highlighter
          ? _highlighterWidths
          : _penWidths)[_size];

  /// Size of a new stamp at [font] in logical pixels.
  double stampSize(double font) => font * _stampSizes[_size];

  /// Radius of the erasers at [font].
  double eraserRadius(double font) => font * (0.35 + 0.25 * _size);

  AnnotationSelection? _selection;
  AnnotationSelection? get selection => _selection;
  set selection(AnnotationSelection? value) {
    _selection = value == null || value.ids.isEmpty ? null : value;
    notifyListeners();
  }

  // Changes --------------------------------------------------------------------

  final _undo = <_Change>[];
  final _redo = <_Change>[];

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  /// Stores a change of the strokes of [songId] on [target]: [before] are
  /// the strokes it replaces or erases, [after] the strokes it adds or
  /// replaces them with.
  Future<void> commit(
    String songId,
    String target, {
    List<AnnotationStroke> before = const [],
    List<AnnotationStroke> after = const [],
  }) async {
    if (before.isEmpty && after.isEmpty) return;
    _undo.add((songId: songId, target: target, before: before, after: after));
    _redo.clear();
    notifyListeners();
    await _store(songId, target, before, after);
  }

  Future<void> _store(
    String songId,
    String target,
    List<AnnotationStroke> before,
    List<AnnotationStroke> after,
  ) {
    final kept = {for (final s in after) s.id};
    return repository.apply(
      songId,
      target: target,
      put: after,
      remove: [
        for (final s in before)
          if (!kept.contains(s.id)) s.id,
      ],
    );
  }

  Future<void> undo() async {
    if (_undo.isEmpty) return;
    final c = _undo.removeLast();
    _redo.add(c);
    _selection = null;
    notifyListeners();
    await _store(c.songId, c.target, c.after, c.before);
  }

  Future<void> redo() async {
    if (_redo.isEmpty) return;
    final c = _redo.removeLast();
    _undo.add(c);
    _selection = null;
    notifyListeners();
    await _store(c.songId, c.target, c.before, c.after);
  }

  /// Sets the colour of new strokes and of the selection.
  set color(int value) {
    _color = value;
    notifyListeners();
    if (_selection != null) act(SelectionAction.recolour);
  }

  /// Requests from the toolbar to the layer showing the selection (the one
  /// whose song, target and page it is).
  final selectionActions = ValueNotifier<SelectionAction?>(null);

  void act(SelectionAction action) {
    selectionActions.value = null;
    selectionActions.value = action;
  }

  @override
  void dispose() {
    selectionActions.dispose();
    super.dispose();
  }
}

/// What the toolbar asks the layer to do with the selection.
enum SelectionAction { delete, larger, smaller, recolour }

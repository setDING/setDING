import 'package:material_ui/material_ui.dart';

import '../../data/annotation_repository.dart';

/// What a pointer does in drawing mode (ADR-0032).
enum DrawingTool { pen, highlighter, text, eraser, partialEraser, lasso, stamp }

/// Line widths per [DrawingTool] at the three sizes, in units of the font
/// size (so they look alike on every layout).
const _penWidths = [0.07, 0.12, 0.2];
const _highlighterWidths = [0.6, 0.9, 1.3];
const _stampSizes = [1.4, 2.0, 2.8];
const _textSizes = [0.75, 1.0, 1.35];

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
    _full = false;
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

  /// Font size of a new text at [font] in logical pixels.
  double textSize(double font) => font * _textSizes[_size];

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

  bool _full = false;

  /// The last change was refused: the song's annotations are at
  /// [annotationMaxBytes]. Cleared by the next stored change.
  bool get full => _full;

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
    final change = (
      songId: songId,
      target: target,
      before: before,
      after: after,
    );
    _undo.add(change);
    final redo = [..._redo];
    _redo.clear();
    notifyListeners();
    if (!await _store(songId, target, before, after)) {
      _undo.remove(change);
      _redo.addAll(redo);
      notifyListeners();
    }
  }

  /// Stores a change; false when it was refused because the annotations
  /// are full.
  Future<bool> _store(
    String songId,
    String target,
    List<AnnotationStroke> before,
    List<AnnotationStroke> after,
  ) async {
    final kept = {for (final s in after) s.id};
    try {
      await repository.apply(
        songId,
        target: target,
        put: after,
        remove: [
          for (final s in before)
            if (!kept.contains(s.id)) s.id,
        ],
      );
    } on AnnotationsFullException {
      _full = true;
      notifyListeners();
      return false;
    }
    if (_full) {
      _full = false;
      notifyListeners();
    }
    return true;
  }

  Future<void> undo() async {
    if (_undo.isEmpty) return;
    final c = _undo.removeLast();
    _redo.add(c);
    _selection = null;
    notifyListeners();
    if (!await _store(c.songId, c.target, c.after, c.before)) {
      _undo.add(_redo.removeLast());
      notifyListeners();
    }
  }

  Future<void> redo() async {
    if (_redo.isEmpty) return;
    final c = _redo.removeLast();
    _undo.add(c);
    _selection = null;
    notifyListeners();
    if (!await _store(c.songId, c.target, c.before, c.after)) {
      _redo.add(_undo.removeLast());
      notifyListeners();
    }
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

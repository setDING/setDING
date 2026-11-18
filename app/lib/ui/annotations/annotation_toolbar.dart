import 'package:material_ui/material_ui.dart';

import '../../data/annotation.dart';
import '../../l10n/generated/app_localizations.dart';
import 'annotation_editor.dart';
import 'annotation_paint.dart';

/// The tools of drawing mode in live mode (ADR-0032): pen, highlighter,
/// erasers, lasso and stamps, colour and size, the selection's actions,
/// undo/redo and "done".
class AnnotationToolbar extends StatelessWidget {
  const AnnotationToolbar({
    super.key,
    required this.editor,
    required this.onDone,
    this.onDeleteAll,
  });

  final AnnotationEditor editor;
  final VoidCallback onDone;

  /// Deletes all annotations of the current song; null without a song.
  final VoidCallback? onDeleteAll;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: editor,
      builder: (context, _) {
        Widget tool(DrawingTool t, IconData icon, String tooltip) => IconButton(
          key: Key('annotation-tool-${t.name}'),
          tooltip: tooltip,
          isSelected: editor.tool == t,
          icon: Icon(icon),
          onPressed: () => editor.tool = t,
        );
        final selection = editor.selection != null;
        return Material(
          key: const Key('annotation-toolbar'),
          color: theme.colorScheme.surfaceContainerHigh,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                tool(DrawingTool.pen, Icons.edit, l10n.annotationPen),
                tool(
                  DrawingTool.highlighter,
                  Icons.border_color,
                  l10n.annotationHighlighter,
                ),
                tool(
                  DrawingTool.eraser,
                  Icons.cleaning_services_outlined,
                  l10n.annotationEraser,
                ),
                tool(
                  DrawingTool.partialEraser,
                  Icons.content_cut,
                  l10n.annotationPartialEraser,
                ),
                tool(
                  DrawingTool.lasso,
                  Icons.highlight_alt,
                  l10n.annotationLasso,
                ),
                _StampPicker(editor: editor),
                const _Divider(),
                for (var i = 0; i < annotationColorCount; i++)
                  _ColorDot(
                    index: i,
                    selected: editor.color == i,
                    onTap: () => editor.color = i,
                  ),
                IconButton(
                  key: const Key('annotation-size'),
                  tooltip: l10n.annotationSize,
                  onPressed: () => editor.size = (editor.size + 1) % 3,
                  icon: SizedBox.square(
                    dimension: 24,
                    child: Center(
                      child: Container(
                        width: 6.0 + editor.size * 6,
                        height: 6.0 + editor.size * 6,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurface,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ),
                if (selection) ...[
                  const _Divider(),
                  IconButton(
                    key: const Key('annotation-selection-smaller'),
                    tooltip: l10n.annotationSmaller,
                    icon: const Icon(Icons.zoom_out),
                    onPressed: () => editor.act(SelectionAction.smaller),
                  ),
                  IconButton(
                    key: const Key('annotation-selection-larger'),
                    tooltip: l10n.annotationLarger,
                    icon: const Icon(Icons.zoom_in),
                    onPressed: () => editor.act(SelectionAction.larger),
                  ),
                  IconButton(
                    key: const Key('annotation-selection-delete'),
                    tooltip: l10n.annotationDeleteSelection,
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => editor.act(SelectionAction.delete),
                  ),
                ],
                const _Divider(),
                IconButton(
                  key: const Key('annotation-undo'),
                  tooltip: l10n.annotationUndo,
                  icon: const Icon(Icons.undo),
                  onPressed: editor.canUndo ? editor.undo : null,
                ),
                IconButton(
                  key: const Key('annotation-redo'),
                  tooltip: l10n.annotationRedo,
                  icon: const Icon(Icons.redo),
                  onPressed: editor.canRedo ? editor.redo : null,
                ),
                PopupMenuButton<String>(
                  key: const Key('annotation-more'),
                  tooltip: l10n.annotationMore,
                  itemBuilder: (context) => [
                    CheckedPopupMenuItem(
                      key: const Key('annotation-finger'),
                      value: 'finger',
                      checked: editor.fingerDraws,
                      child: Text(l10n.annotationDrawWithFinger),
                    ),
                    if (onDeleteAll != null)
                      PopupMenuItem(
                        key: const Key('annotation-delete-all'),
                        value: 'delete-all',
                        child: Text(l10n.annotationsDeleteAll),
                      ),
                  ],
                  onSelected: (value) => switch (value) {
                    'finger' => editor.fingerDraws = !editor.fingerDraws,
                    'delete-all' => onDeleteAll?.call(),
                    _ => null,
                  },
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  key: const Key('annotation-done'),
                  onPressed: onDone,
                  icon: const Icon(Icons.check),
                  label: Text(l10n.annotationDone),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) =>
      const SizedBox(height: 32, child: VerticalDivider(width: 16));
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.index,
    required this.selected,
    required this.onTap,
  });

  final int index;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Tooltip(
      message: l10n.annotationColor(index + 1),
      child: InkResponse(
        key: Key('annotation-color-$index'),
        onTap: onTap,
        radius: 20,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: annotationColor(index, theme.brightness),
              shape: BoxShape.circle,
              border: Border.all(
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outlineVariant,
                width: selected ? 3 : 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Picks a stamp (and the stamp tool) from the three groups.
class _StampPicker extends StatelessWidget {
  const _StampPicker({required this.editor});

  final AnnotationEditor editor;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurface;
    Widget preview(AnnotationStamp stamp) => SizedBox.square(
      dimension: 28,
      child: CustomPaint(painter: _StampPreview(stamp, color)),
    );
    PopupMenuEntry<AnnotationStamp> header(String text) => PopupMenuItem(
      enabled: false,
      height: 32,
      child: Text(text, style: theme.textTheme.labelMedium),
    );
    PopupMenuEntry<AnnotationStamp> item(AnnotationStamp s) => PopupMenuItem(
      key: Key('annotation-stamp-${s.name}'),
      value: s,
      child: Row(
        children: [
          preview(s),
          const SizedBox(width: 12),
          Text(stampName(l10n, s)),
        ],
      ),
    );
    return PopupMenuButton<AnnotationStamp>(
      key: const Key('annotation-tool-stamp'),
      tooltip: l10n.annotationStamps,
      icon: editor.tool == DrawingTool.stamp
          ? preview(editor.stamp)
          : const Icon(Icons.approval),
      style: IconButton.styleFrom(
        backgroundColor: editor.tool == DrawingTool.stamp
            ? theme.colorScheme.secondaryContainer
            : null,
      ),
      onSelected: (s) => editor.stamp = s,
      itemBuilder: (context) => [
        header(l10n.annotationStampsMusic),
        for (final s in _music) item(s),
        const PopupMenuDivider(),
        header(l10n.annotationStampsRepeats),
        for (final s in _repeats) item(s),
        const PopupMenuDivider(),
        header(l10n.annotationStampsCues),
        for (final s in _cues) item(s),
      ],
    );
  }
}

const _music = [
  AnnotationStamp.fermata,
  AnnotationStamp.breath,
  AnnotationStamp.crescendo,
  AnnotationStamp.decrescendo,
  AnnotationStamp.ritardando,
  AnnotationStamp.accent,
];
const _repeats = [
  AnnotationStamp.repeat2,
  AnnotationStamp.repeat3,
  AnnotationStamp.repeat4,
  AnnotationStamp.repeatStart,
  AnnotationStamp.repeatEnd,
  AnnotationStamp.coda,
  AnnotationStamp.segno,
];
const _cues = [
  AnnotationStamp.glasses,
  AnnotationStamp.stop,
  AnnotationStamp.eye,
  AnnotationStamp.exclamation,
  AnnotationStamp.star,
];

/// The localized name of [stamp].
String stampName(AppLocalizations l10n, AnnotationStamp stamp) =>
    switch (stamp) {
      AnnotationStamp.fermata => l10n.stampFermata,
      AnnotationStamp.breath => l10n.stampBreath,
      AnnotationStamp.crescendo => l10n.stampCrescendo,
      AnnotationStamp.decrescendo => l10n.stampDecrescendo,
      AnnotationStamp.ritardando => l10n.stampRitardando,
      AnnotationStamp.accent => l10n.stampAccent,
      AnnotationStamp.repeat2 => l10n.stampRepeat(2),
      AnnotationStamp.repeat3 => l10n.stampRepeat(3),
      AnnotationStamp.repeat4 => l10n.stampRepeat(4),
      AnnotationStamp.repeatStart => l10n.stampRepeatStart,
      AnnotationStamp.repeatEnd => l10n.stampRepeatEnd,
      AnnotationStamp.coda => l10n.stampCoda,
      AnnotationStamp.segno => l10n.stampSegno,
      AnnotationStamp.glasses => l10n.stampGlasses,
      AnnotationStamp.stop => l10n.stampStop,
      AnnotationStamp.eye => l10n.stampEye,
      AnnotationStamp.exclamation => l10n.stampExclamation,
      AnnotationStamp.star => l10n.stampStar,
    };

class _StampPreview extends CustomPainter {
  _StampPreview(this.stamp, this.color);

  final AnnotationStamp stamp;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) =>
      paintStamp(canvas, stamp, size.center(Offset.zero), size.width, color);

  @override
  bool shouldRepaint(_StampPreview old) =>
      old.stamp != stamp || old.color != color;
}

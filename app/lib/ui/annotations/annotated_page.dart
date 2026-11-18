import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/annotation.dart';
import '../../providers.dart';
import '../../settings/settings.dart';
import 'annotation_editor.dart';
import 'annotation_layer.dart';

/// [child] with the person's freehand annotations of [songId] on [target]
/// (ADR-0032): loads the strokes and whether they are shown, and lays an
/// [AnnotationLayer] over the page. Without strokes and without [editor]
/// the child stays as it is.
class AnnotatedPage extends ConsumerWidget {
  const AnnotatedPage({
    super.key,
    required this.songId,
    this.target = '',
    required this.page,
    this.layout,
    this.font = 20,
    this.songLines,
    this.editor,
    this.hidden = false,
    required this.child,
  });

  final String songId;
  final String target;
  final int page;
  final LayoutFingerprint? layout;
  final double font;
  final ({Set<int> lines, Set<int> hashes})? songLines;
  final AnnotationEditor? editor;

  /// Hidden for this song (personal overlay, ADR-0032).
  final bool hidden;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strokes =
        ref
            .watch(annotationsProvider((songId: songId, target: target)))
            .value ??
        const <AnnotationStroke>[];
    final shown =
        ref.watch(settingsProvider.select((s) => s.showAnnotations)) && !hidden;
    if (editor == null && (strokes.isEmpty || !shown)) return child;
    final size = editor == null
        ? 0
        : ref
                  .watch(
                    annotationSizeProvider((songId: songId, target: target)),
                  )
                  .value ??
              0;
    return AnnotationLayer(
      songId: songId,
      target: target,
      page: page,
      strokes: strokes,
      layout: layout,
      font: font,
      songLines: songLines,
      editor: editor,
      visible: shown,
      fill: size / annotationMaxBytes,
      child: child,
    );
  }
}

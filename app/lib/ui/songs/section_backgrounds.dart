import 'package:material_ui/material_ui.dart';

import 'chordpro_editing_controller.dart';
import 'line_number_gutter.dart';

/// Paints a full-width background behind every section environment of the
/// ChordPro editor (#371), coloured by its type, with a bar on the left,
/// so the blocks are easy to tell apart. Positioned by the editor's own
/// text layout, like the line numbers.
class SectionBackgrounds extends StatefulWidget {
  const SectionBackgrounds({
    super.key,
    required this.fieldKey,
    required this.controller,
    required this.scrollController,
    required this.child,
  });

  /// Key of the editor's [TextField].
  final GlobalKey fieldKey;
  final ChordProEditingController controller;
  final ScrollController scrollController;
  final Widget child;

  @override
  State<SectionBackgrounds> createState() => _SectionBackgroundsState();
}

class _SectionBackgroundsState extends State<SectionBackgrounds> {
  final _paintKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      key: _paintKey,
      painter: SectionBackgroundPainter(
        fieldKey: widget.fieldKey,
        paintKey: _paintKey,
        controller: widget.controller,
        scheme: Theme.of(context).colorScheme,
        repaint: Listenable.merge([widget.controller, widget.scrollController]),
      ),
      child: widget.child,
    );
  }
}

/// Colour of a section type: verse, chorus and bridge differ, all other
/// environments (tab, grid, abc, …) share a neutral colour.
Color sectionColour(String type, ColorScheme scheme) => switch (type) {
  'verse' => scheme.primary,
  'chorus' => scheme.tertiary,
  'bridge' => scheme.secondary,
  _ => scheme.outline,
};

class SectionBackgroundPainter extends CustomPainter {
  SectionBackgroundPainter({
    required this.fieldKey,
    required this.paintKey,
    required this.controller,
    required this.scheme,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final GlobalKey fieldKey;
  final GlobalKey paintKey;
  final ChordProEditingController controller;
  final ColorScheme scheme;

  /// Width of the bar on the left.
  static const barWidth = 3.0;

  /// The rectangles painted for the sections, as (rect, type); for tests.
  List<(Rect, String)> lastPainted = const [];

  @override
  void paint(Canvas canvas, Size size) {
    final editable = findRenderEditable(fieldKey);
    final box = paintKey.currentContext?.findRenderObject();
    if (editable == null || box is! RenderBox || !editable.hasSize) return;
    final text = editable.plainText;
    final painted = <(Rect, String)>[];
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    double y(Offset local) =>
        box.globalToLocal(editable.localToGlobal(local)).dy;
    for (final section in controller.sections) {
      if (section.end > text.length) break;
      final top = y(
        editable
            .getLocalRectForCaret(TextPosition(offset: section.start))
            .topLeft,
      );
      final bottom = y(
        editable
            .getLocalRectForCaret(
              TextPosition(
                offset: section.end,
                affinity: TextAffinity.upstream,
              ),
            )
            .bottomLeft,
      );
      if (bottom < 0) continue;
      if (top > size.height) break;
      final rect = Rect.fromLTRB(0, top, size.width, bottom);
      final colour = sectionColour(section.type, scheme);
      canvas
        ..drawRect(rect, Paint()..color = colour.withValues(alpha: 0.08))
        ..drawRect(
          Rect.fromLTWH(0, top, barWidth, bottom - top),
          Paint()..color = colour.withValues(alpha: 0.6),
        );
      painted.add((rect, section.type));
    }
    canvas.restore();
    lastPainted = painted;
  }

  @override
  bool shouldRepaint(SectionBackgroundPainter old) => true;
}

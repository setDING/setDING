import 'package:material_ui/material_ui.dart';

/// Where live mode stands (ADR-0007): the item of the set and the position
/// within it.
///
/// [pages] and [page] are the pages of the current item (song pages, PDF
/// pages or spreads); a song that scrolls has one page and [scroll], the
/// part of it seen so far (0–1, up to the bottom of the screen).
typedef StageProgress = ({int index, int pages, int page, double? scroll});

/// Height of the bar.
const setProgressHeight = 8.0;

/// A thin bar across the live screen: one segment per item of the set, the
/// current song split into its pages. The current page is in the accent
/// colour and the pages still to come in a light accent tone, so it is seen
/// at a glance that more of the song follows and where the set stands.
/// Pauses and texts are a dashed line, never filled. Display only.
class SetProgressBar extends StatelessWidget {
  const SetProgressBar({
    super.key,
    required this.markers,
    required this.progress,
  });

  /// One entry per item of the set: true for a pause or text.
  final List<bool> markers;
  final StageProgress progress;

  /// Gap between the items of the set and between the pages of a song.
  static const itemGap = 6.0;
  static const pageGap = 2.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = (
      current: scheme.primary,
      ahead: scheme.primary.withValues(alpha: 0.35),
      done: scheme.onSurfaceVariant.withValues(alpha: 0.55),
      todo: scheme.onSurface.withValues(alpha: 0.25),
    );
    final current = progress.index;
    // The current song is wider, so its pages stay apart in long sets.
    final currentFlex = (progress.pages * 8).clamp(16, 40);
    return SizedBox(
      key: const Key('live-set-progress'),
      height: setProgressHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < markers.length; i++) ...[
            if (i > 0) const SizedBox(width: itemGap),
            Expanded(
              flex: i == current ? currentFlex : 10,
              child: KeyedSubtree(
                key: ValueKey('progress-item-$i'),
                child: markers[i]
                    ? _Dashed(
                        i < current
                            ? colors.done
                            : i == current
                            ? colors.current
                            : colors.todo,
                      )
                    : i != current
                    ? ColoredBox(color: i < current ? colors.done : colors.todo)
                    : _pages(colors),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _pages(({Color current, Color ahead, Color done, Color todo}) colors) {
    final scroll = progress.scroll;
    if (scroll != null) {
      // Continuous: seen so far in the accent colour, the rest ahead.
      return ColoredBox(
        color: colors.ahead,
        child: FractionallySizedBox(
          key: const Key('progress-scroll'),
          alignment: Alignment.centerLeft,
          widthFactor: scroll.clamp(0.0, 1.0),
          child: ColoredBox(color: colors.current),
        ),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var k = 0; k < progress.pages; k++) ...[
          if (k > 0) const SizedBox(width: pageGap),
          Expanded(
            child: ColoredBox(
              key: ValueKey('progress-page-$k'),
              color: k < progress.page
                  ? colors.done
                  : k == progress.page
                  ? colors.current
                  : colors.ahead,
            ),
          ),
        ],
      ],
    );
  }
}

/// A dashed line in the middle of the bar: a pause or text of the set.
class _Dashed extends StatelessWidget {
  const _Dashed(this.color);

  final Color color;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: DashedLinePainter(color), size: Size.infinite);
}

/// Dashes across the width, as high as the bar's middle third.
class DashedLinePainter extends CustomPainter {
  DashedLinePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const dash = 5.0;
    const gap = 3.0;
    final height = size.height / 3;
    final top = (size.height - height) / 2;
    for (var x = 0.0; x < size.width; x += dash + gap) {
      final width = (size.width - x).clamp(0.0, dash);
      canvas.drawRect(Rect.fromLTWH(x, top, width, height), paint);
    }
  }

  @override
  bool shouldRepaint(DashedLinePainter old) => old.color != color;
}

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
/// Pauses and texts are a dashed line, never filled. Taps go through it;
/// [SetProgressScrubber] jumps by holding and dragging on it (#979).
class SetProgressBar extends StatelessWidget {
  const SetProgressBar({
    super.key,
    required this.markers,
    required this.progress,
    this.height = setProgressHeight,
    this.selected,
  });

  /// One entry per item of the set: true for a pause or text.
  final List<bool> markers;
  final StageProgress progress;
  final double height;

  /// The item under the finger while scrubbing, outlined.
  final int? selected;

  /// Gap between the items of the set and between the pages of a song.
  static const itemGap = 6.0;
  static const pageGap = 2.0;

  /// The flex of the current item: wider, so its pages stay apart in long
  /// sets.
  static int _currentFlex(int pages) => (pages * 8).clamp(16, 40);

  /// The item of a set of [count] items at [x] of a bar [width] wide; a gap
  /// belongs half to each of its neighbours.
  static int itemAt(double x, double width, int count, StageProgress progress) {
    final flexes = [
      for (var i = 0; i < count; i++)
        i == progress.index ? _currentFlex(progress.pages) : 10,
    ];
    final total = flexes.fold(0, (a, b) => a + b);
    final free = (width - itemGap * (count - 1)).clamp(0.0, double.infinity);
    var start = 0.0;
    for (var i = 0; i < count; i++) {
      final end = start + free * flexes[i] / total;
      if (x < end + itemGap / 2) return i;
      start = end + itemGap;
    }
    return count - 1;
  }

  /// The horizontal centre of item [index], as laid out by [itemAt].
  static double centerOf(
    int index,
    double width,
    int count,
    StageProgress progress,
  ) {
    final flexes = [
      for (var i = 0; i < count; i++)
        i == progress.index ? _currentFlex(progress.pages) : 10,
    ];
    final total = flexes.fold(0, (a, b) => a + b);
    final free = (width - itemGap * (count - 1)).clamp(0.0, double.infinity);
    var start = 0.0;
    for (var i = 0; i < index; i++) {
      start += free * flexes[i] / total + itemGap;
    }
    return start + free * flexes[index] / total / 2;
  }

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
    final currentFlex = _currentFlex(progress.pages);
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < markers.length; i++) ...[
            if (i > 0) const SizedBox(width: itemGap),
            Expanded(
              flex: i == current ? currentFlex : 10,
              child: KeyedSubtree(
                key: ValueKey('progress-item-$i'),
                child: _outlined(
                  i == selected,
                  scheme,
                  markers[i]
                      ? _Dashed(
                          i < current
                              ? colors.done
                              : i == current
                              ? colors.current
                              : colors.todo,
                        )
                      : i != current
                      ? ColoredBox(
                          color: i < current ? colors.done : colors.todo,
                        )
                      : _pages(colors),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _outlined(bool selected, ColorScheme scheme, Widget child) => !selected
      ? child
      : DecoratedBox(
          key: const Key('progress-selected'),
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            border: Border.all(color: scheme.onSurface, width: 2),
          ),
          child: child,
        );

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

/// The page of live mode with the progress bar of the set below it; holding
/// on the bar and dragging along it jumps to another item of the set
/// (#979).
///
/// A tap does nothing: the bar is thin and right below the page-turn zones,
/// and a jump by mistake on stage is worse than none. The touch zone reaches
/// [touchHeight] up into the page, but only takes a long press there, so
/// taps and swipes still turn the page. While scrubbing, the bar grows and a
/// label above the finger names the item under it; releasing jumps there.
/// Releasing on the current item or far above the bar cancels.
class SetProgressScrubber extends StatefulWidget {
  const SetProgressScrubber({
    super.key,
    required this.child,
    required this.showBar,
    required this.enabled,
    required this.markers,
    required this.progress,
    required this.labelOf,
    required this.onJump,
  });

  /// The page above the bar.
  final Widget child;

  /// The live setting "Progress bar of the set"; without the bar there is no
  /// scrubbing.
  final bool showBar;

  /// False while the control bar or the drawing tools cover the bottom of
  /// the page.
  final bool enabled;
  final List<bool> markers;
  final ValueListenable<StageProgress> progress;
  final String Function(int index) labelOf;
  final ValueChanged<int> onJump;

  /// Height of the touch zone, the bar included.
  static const touchHeight = 32.0;

  /// Height of the bar while scrubbing.
  static const scrubHeight = 40.0;

  /// How far above the touch zone the finger cancels.
  static const cancelDistance = 80.0;

  @override
  State<SetProgressScrubber> createState() => _SetProgressScrubberState();
}

class _SetProgressScrubberState extends State<SetProgressScrubber> {
  /// Whether a long press is scrubbing, and the item under the finger
  /// (null: dragged away, cancels).
  bool _scrubbing = false;
  int? _selected;

  void _update(Offset local, double width) {
    final cancelled = local.dy < -SetProgressScrubber.cancelDistance;
    final selected = cancelled || widget.markers.isEmpty
        ? null
        : SetProgressBar.itemAt(
            local.dx,
            width,
            widget.markers.length,
            widget.progress.value,
          );
    if (selected != null && (selected != _selected || !_scrubbing)) {
      HapticFeedback.selectionClick();
    }
    setState(() {
      _scrubbing = true;
      _selected = selected;
    });
  }

  void _end({required bool jump}) {
    final target = _selected;
    setState(() {
      _scrubbing = false;
      _selected = null;
    });
    if (jump && target != null && target != widget.progress.value.index) {
      widget.onJump(target);
    }
  }

  @override
  void didUpdateWidget(SetProgressScrubber old) {
    super.didUpdateWidget(old);
    if (_scrubbing && !(widget.enabled && widget.showBar)) {
      _scrubbing = false;
      _selected = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = Column(
      children: [
        Expanded(child: widget.child),
        if (widget.showBar)
          ValueListenableBuilder(
            valueListenable: widget.progress,
            builder: (context, progress, _) => SetProgressBar(
              key: const Key('live-set-progress'),
              markers: widget.markers,
              progress: progress,
            ),
          ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final scheme = Theme.of(context).colorScheme;
        // Always a stack, so switching the bar keeps the page's state.
        return Stack(
          children: [
            Positioned.fill(child: page),
            if (widget.enabled && widget.showBar)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: SetProgressScrubber.touchHeight,
                // Translucent: taps and swipes still reach the page.
                child: GestureDetector(
                  key: const Key('live-set-progress-touch'),
                  behavior: HitTestBehavior.translucent,
                  onLongPressStart: (d) => _update(d.localPosition, width),
                  onLongPressMoveUpdate: (d) => _update(d.localPosition, width),
                  onLongPressEnd: (_) => _end(jump: true),
                  onLongPressCancel: () => _end(jump: false),
                ),
              ),
            if (_scrubbing) ...[
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: Container(
                    key: const Key('live-set-progress-scrub'),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      border: Border(
                        top: BorderSide(color: scheme.outlineVariant),
                      ),
                    ),
                    padding: const EdgeInsets.only(top: 8),
                    child: SetProgressBar(
                      markers: widget.markers,
                      progress: widget.progress.value,
                      height: SetProgressScrubber.scrubHeight,
                      selected: _selected,
                    ),
                  ),
                ),
              ),
              if (_selected case final selected?)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: SetProgressScrubber.scrubHeight + 16,
                  height: 64,
                  child: IgnorePointer(
                    child: CustomSingleChildLayout(
                      delegate: _LabelLayout(
                        SetProgressBar.centerOf(
                          selected,
                          width,
                          widget.markers.length,
                          widget.progress.value,
                        ),
                      ),
                      child: _ScrubLabel(widget.labelOf(selected)),
                    ),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }
}

/// The name of the item under the finger, in the colours of a tooltip.
class _ScrubLabel extends StatelessWidget {
  const _ScrubLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      key: const Key('live-set-progress-label'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.inverseSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleLarge?.copyWith(
          color: scheme.onInverseSurface,
        ),
      ),
    );
  }
}

/// Centres the label above [center], kept inside the screen.
class _LabelLayout extends SingleChildLayoutDelegate {
  _LabelLayout(this.center);

  final double center;
  static const _margin = 8.0;

  @override
  Size getSize(BoxConstraints constraints) => constraints.biggest;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(
        maxWidth: constraints.maxWidth * 0.8,
        maxHeight: constraints.maxHeight,
      );

  @override
  Offset getPositionForChild(Size size, Size child) => Offset(
    (center - child.width / 2).clamp(
      _margin,
      math.max(_margin, size.width - child.width - _margin),
    ),
    size.height - child.height,
  );

  @override
  bool shouldRelayout(_LabelLayout old) => old.center != center;
}

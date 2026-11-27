import 'package:material_ui/material_ui.dart';

/// The page area of live mode as a place to turn (ADR-0007): taps go to
/// [onTap] (the tap zones), and swipes turn pages like taps, the pages of a
/// song first, then the next or previous song.
class LiveTurnArea extends StatefulWidget {
  const LiveTurnArea({
    super.key,
    required this.onTap,
    required this.onNext,
    required this.onPrevious,
    required this.onWidth,
    required this.child,
  });

  /// A tap at this position of the area.
  final ValueChanged<Offset> onTap;
  final VoidCallback onNext;
  final VoidCallback onPrevious;

  /// The width of the area, told at every layout.
  final ValueChanged<double> onWidth;
  final Widget child;

  @override
  State<LiveTurnArea> createState() => _LiveTurnAreaState();
}

class _LiveTurnAreaState extends State<LiveTurnArea> {
  /// Width of the page area, for the length of a swipe.
  double _width = 0;

  /// Horizontal distance of the current swipe.
  double _swipe = 0;

  /// A swipe to the left turns forward, to the right back: when it is fast
  /// enough or long enough (a fifth of the page width).
  void _onSwipeEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final distance = _swipe;
    _swipe = 0;
    if (velocity.abs() > 300 ? velocity < 0 : distance < -_width * 0.2) {
      widget.onNext();
    } else if (velocity.abs() > 300 ? velocity > 0 : distance > _width * 0.2) {
      widget.onPrevious();
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      _width = constraints.maxWidth;
      widget.onWidth(_width);
      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapUp: (d) => widget.onTap(d.localPosition),
        onHorizontalDragStart: (_) => _swipe = 0,
        onHorizontalDragUpdate: (d) => _swipe += d.primaryDelta ?? 0,
        onHorizontalDragEnd: _onSwipeEnd,
        child: widget.child,
      );
    },
  );
}

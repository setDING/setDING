import 'package:material_ui/material_ui.dart';

/// A [LayoutBuilder] for layouts that depend on a value derived from the
/// constraints, such as the number of columns for the available width.
///
/// [builder] runs again only when [select] gives another value or this
/// widget is replaced (its parent built again). A change of the constraints
/// that keeps the value, e.g. a lower height while the keyboard opens,
/// keeps the widget built before, so its subtree is not built again in each
/// frame of the keyboard animation (#297). That also holds for screens kept
/// in the background, such as the other tabs of the home screen.
class BreakpointBuilder<T> extends StatefulWidget {
  const BreakpointBuilder({
    super.key,
    required this.select,
    required this.builder,
  });

  /// The value the layout depends on, e.g. whether the screen is wide.
  final T Function(BoxConstraints constraints) select;

  final Widget Function(BuildContext context, T value) builder;

  @override
  State<BreakpointBuilder<T>> createState() => _BreakpointBuilderState<T>();
}

class _BreakpointBuilderState<T> extends State<BreakpointBuilder<T>> {
  ({T value, Widget child})? _built;

  @override
  void didUpdateWidget(BreakpointBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _built = null;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final value = widget.select(constraints);
      if (_built case (value: final v, :final child) when v == value) {
        return child;
      }
      final child = widget.builder(context, value);
      _built = (value: value, child: child);
      return child;
    },
  );
}

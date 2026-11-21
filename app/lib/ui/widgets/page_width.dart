import 'package:material_ui/material_ui.dart';

/// Maximum width of the content of a page of tiles or a form on a large
/// screen (docs/development/ui-design.md, "Layout and spacing").
const pageMaxWidth = 720.0;

/// Maximum width of a single-purpose form, e.g. signing in.
const formMaxWidth = 480.0;

/// Limits [child] to [maxWidth], at the top and centred, so tiles do not
/// stretch over a wide tablet or desktop window. On narrower screens it
/// changes nothing.
class PageWidth extends StatelessWidget {
  const PageWidth({
    super.key,
    this.maxWidth = pageMaxWidth,
    this.alignment = Alignment.topCenter,
    required this.child,
  });

  final double maxWidth;
  final AlignmentGeometry alignment;
  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
    alignment: alignment,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}

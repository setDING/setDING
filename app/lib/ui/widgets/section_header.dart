import 'package:material_ui/material_ui.dart';

/// The heading of a section of a list, a panel or a dialog: small title in
/// the primary colour, bold, marked as a heading for screen readers
/// (docs/development/ui-design.md, "Section headers"). Every section of the
/// app uses it, so sections look the same on every screen.
class SectionHeader extends StatelessWidget {
  const SectionHeader(
    this.label, {
    super.key,
    this.icon,
    this.trailing,
    this.padding = listPadding,
  });

  /// Padding in a full-width list: aligned with the text of a [ListTile].
  static const listPadding = EdgeInsetsDirectional.fromSTEB(16, 16, 16, 4);

  /// Padding inside content that is already indented, e.g. a dialog.
  static const insetPadding = EdgeInsetsDirectional.only(top: 16, bottom: 4);

  final String label;

  /// Optional icon before the label, e.g. the scope of a settings group.
  final IconData? icon;

  /// Optional widget at the end, e.g. a small action button.
  final Widget? trailing;

  final EdgeInsetsGeometry padding;

  /// The text style of a section header, for headers that need their own
  /// layout (e.g. a collapsible one).
  static TextStyle? style(BuildContext context) {
    final theme = Theme.of(context);
    return theme.textTheme.titleSmall?.copyWith(
      color: theme.colorScheme.primary,
      fontWeight: FontWeight.w700,
    );
  }

  @override
  Widget build(BuildContext context) {
    final style = SectionHeader.style(context);
    final icon = this.icon;
    final trailing = this.trailing;
    return Semantics(
      header: true,
      child: Padding(
        padding: padding,
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: style?.color),
              const SizedBox(width: 8),
            ],
            Expanded(child: Text(label, style: style)),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

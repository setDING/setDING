import 'package:material_ui/material_ui.dart';

/// An action in a `PopupMenuButton` menu: an icon in front of its label, so
/// the actions of a menu are quick to tell apart
/// (docs/development/ui-design.md, "Actions", issue #835). Every action menu
/// of the app uses it; menus that choose a value mark the chosen one with a
/// check instead.
///
/// A [destructive] action (deleting or removing something) draws its icon
/// and label in the error colour, like the danger zone (#839).
///
/// Without a value, the action runs from `onTap` (an app bar action moved
/// into the menu by `AppBarActions`, #838), whose badge it keeps with
/// `active` and `count`.
class MenuAction<T> extends PopupMenuItem<T> {
  MenuAction({
    super.key,
    super.value,
    required IconData icon,
    required String label,
    bool destructive = false,
    super.enabled,
    super.onTap,
    bool active = false,
    int? count,
  }) : super(
         child: _MenuActionLabel(
           icon: icon,
           label: label,
           destructive: destructive,
           active: active,
           count: count,
         ),
       );
}

class _MenuActionLabel extends StatelessWidget {
  const _MenuActionLabel({
    required this.icon,
    required this.label,
    required this.destructive,
    required this.active,
    required this.count,
  });

  final IconData icon;
  final String label;
  final bool destructive;

  /// A dot on the icon, as on a `BadgedIconButton` (#838).
  final bool active;

  /// Shown in the badge instead of a dot.
  final int? count;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? Theme.of(context).colorScheme.error : null;
    final shown = count ?? 0;
    return Row(
      children: [
        Badge(
          isLabelVisible: active || shown > 0,
          label: shown > 0 ? Text('$shown') : null,
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            style: color == null ? null : TextStyle(color: color),
          ),
        ),
      ],
    );
  }
}

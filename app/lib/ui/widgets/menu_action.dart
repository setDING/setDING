import 'package:material_ui/material_ui.dart';

/// An action in a `PopupMenuButton` menu: an icon in front of its label, so
/// the actions of a menu are quick to tell apart
/// (docs/development/ui-design.md, "Actions", issue #835). Every action menu
/// of the app uses it; menus that choose a value mark the chosen one with a
/// check instead.
///
/// A [destructive] action (deleting or removing something) draws its icon
/// and label in the error colour, like the danger zone (#839).
class MenuAction<T> extends PopupMenuItem<T> {
  MenuAction({
    super.key,
    required T super.value,
    required IconData icon,
    required String label,
    bool destructive = false,
    super.enabled,
  }) : super(
         child: _MenuActionLabel(
           icon: icon,
           label: label,
           destructive: destructive,
         ),
       );
}

class _MenuActionLabel extends StatelessWidget {
  const _MenuActionLabel({
    required this.icon,
    required this.label,
    required this.destructive,
  });

  final IconData icon;
  final String label;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? Theme.of(context).colorScheme.error : null;
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
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

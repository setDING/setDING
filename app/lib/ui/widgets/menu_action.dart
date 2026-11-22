import 'package:material_ui/material_ui.dart';

/// An action in a `PopupMenuButton` menu: an icon in front of its label, so
/// the actions of a menu are quick to tell apart
/// (docs/development/ui-design.md, "Actions", issue #835). Every action menu
/// of the app uses it; menus that choose a value mark the chosen one with a
/// check instead.
class MenuAction<T> extends PopupMenuItem<T> {
  MenuAction({
    super.key,
    required T super.value,
    required IconData icon,
    required String label,
    super.enabled,
  }) : super(
         child: _MenuActionLabel(icon: icon, label: label),
       );
}

class _MenuActionLabel extends StatelessWidget {
  const _MenuActionLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 20),
      const SizedBox(width: 8),
      Flexible(child: Text(label)),
    ],
  );
}

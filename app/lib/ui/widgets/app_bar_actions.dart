import 'package:material_ui/material_ui.dart';

import 'menu_action.dart';
import 'side_panel.dart';

/// An app bar action that [AppBarActions] shows as an icon button, or at the
/// top of the overflow menu when the screen is too narrow for it.
class AppBarAction {
  const AppBarAction({
    required this.id,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.active = false,
    this.count,
  });

  /// The key of the icon button is `Key(id)`, that of its menu entry
  /// `Key('$id-menu')`.
  final String id;
  final IconData icon;

  /// The tooltip of the button and the label of the menu entry.
  final String label;
  final VoidCallback onPressed;

  /// Shows a dot on the icon (e.g. a panel with settings in effect).
  final bool active;

  /// Shown in the badge instead of a dot.
  final int? count;

  bool get hasBadge => active || (count ?? 0) > 0;
}

/// The actions of an app bar with an overflow (⋮) menu
/// (docs/development/ui-design.md, "Actions", issue #838).
///
/// Shows the first [actions] as icon buttons, as many as the screen width
/// leaves room for next to the title, and the others at the top of the
/// overflow menu, above the menu's own items ([itemBuilder]) and a divider.
/// A badge of a hidden action shows in its menu entry and as a dot on the ⋮
/// button. Without own items and with every action shown, there is no menu.
class AppBarActions<T> extends StatelessWidget {
  const AppBarActions({
    super.key,
    required this.actions,
    this.itemBuilder,
    this.onSelected,
    this.otherWidth = 0,
  });

  /// In order of importance: the last ones move into the menu first.
  final List<AppBarAction> actions;
  final PopupMenuItemBuilder<T>? itemBuilder;
  final PopupMenuItemSelected<T>? onSelected;

  /// The width of the app bar's other actions, before and after these.
  final double otherWidth;

  /// The width of an icon button.
  static const actionWidth = 48.0;

  /// The room kept for the back button, the shortest title the app bar
  /// should still show, and the ⋮ button.
  static const reservedWidth = 56.0 + 160 + actionWidth;

  /// How many of [count] actions fit as buttons on a screen [width] wide.
  static int visibleCount(double width, int count, {double otherWidth = 0}) =>
      ((width - reservedWidth - otherWidth) / actionWidth).floor().clamp(
        0,
        count,
      );

  @override
  Widget build(BuildContext context) {
    final shown = visibleCount(
      MediaQuery.sizeOf(context).width,
      actions.length,
      otherWidth: otherWidth,
    );
    final hidden = actions.skip(shown).toList();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final a in actions.take(shown))
          BadgedIconButton(
            key: Key(a.id),
            tooltip: a.label,
            icon: a.icon,
            active: a.active,
            count: a.count,
            onPressed: a.onPressed,
          ),
        if (hidden.isNotEmpty || itemBuilder != null)
          PopupMenuButton<T>(
            key: const Key('app-bar-menu'),
            icon: Badge(
              key: const Key('app-bar-menu-badge'),
              isLabelVisible: hidden.any((a) => a.hasBadge),
              child: const Icon(Icons.more_vert),
            ),
            onSelected: onSelected,
            itemBuilder: (context) {
              final own = itemBuilder?.call(context) ?? const [];
              return [
                for (final a in hidden)
                  // No value: the action runs from onTap, not onSelected.
                  MenuAction<T>(
                    key: Key('${a.id}-menu'),
                    onTap: a.onPressed,
                    icon: a.icon,
                    label: a.label,
                    active: a.active,
                    count: a.count,
                  ),
                if (hidden.isNotEmpty && own.isNotEmpty)
                  const PopupMenuDivider(),
                ...own,
              ];
            },
          ),
      ],
    );
  }
}

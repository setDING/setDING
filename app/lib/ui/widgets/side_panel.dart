import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'docs_link.dart';
import 'scope_info.dart';

/// A panel that slides in from the right (end drawer) with a heading, the
/// scope of its settings and a close button. The screen behind it stays
/// visible, so changes show at once.
class SidePanel extends StatelessWidget {
  const SidePanel({
    super.key,
    required this.icon,
    required this.title,
    this.scope,
    this.docs,
    required this.children,
  });

  final IconData icon;
  final String title;

  /// Whom the settings in the panel apply to; null shows no (?) icon.
  final SettingScope? scope;

  /// The page of the user documentation about the panel, opened by a help
  /// button in its header (#993).
  final DocsPage? docs;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Drawer(
      width: math.min(360, MediaQuery.sizeOf(context).width - 56),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 24),
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(title, style: theme.textTheme.titleMedium),
                      ),
                      if (scope case final scope?) ScopeInfo(scope),
                    ],
                  ),
                ),
                if (docs case final docs?)
                  DocsHelpButton(
                    key: const Key('side-panel-docs'),
                    page: docs,
                    topic: title,
                  ),
                IconButton(
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// An app bar icon button with a dot (or a count) when [active].
class BadgedIconButton extends StatelessWidget {
  const BadgedIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.active = false,
    this.count,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool active;

  /// Shown in the badge instead of a dot.
  final int? count;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    icon: Badge(
      isLabelVisible: active || (count ?? 0) > 0,
      label: count != null && count! > 0 ? Text('$count') : null,
      child: Icon(icon),
    ),
  );
}

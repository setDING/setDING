import 'package:material_ui/material_ui.dart';

// The building blocks of the settings categories (ADR-0050): a category is
// a SettingsSections list of titled SettingsSection groups, separated by
// dividers, and every option in them has a leading icon, so all texts start
// at one column. SettingsSwitch and SettingsChoice require the icon.

/// The sections of a category, with a divider between two of them.
class SettingsSections extends StatelessWidget {
  const SettingsSections(this.sections, {super.key});

  /// The sections; usually [SettingsSection]s, or a widget with its own
  /// heading in the same style (the song display preview).
  final List<Widget> sections;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final (i, section) in sections.indexed) ...[
        if (i > 0) const Divider(height: 24),
        section,
      ],
    ],
  );
}

/// A titled group of options of a settings category.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.title,
    this.hint,
    required this.children,
  });

  final String title;

  /// Explains the whole section, below the title.
  final String? hint;

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 4),
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ),
        if (hint case final hint?)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 4),
            child: Text(
              hint,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ...children,
      ],
    );
  }
}

/// An option that is on or off. [tileKey] is the key of the switch tile.
class SettingsSwitch extends StatelessWidget {
  const SettingsSwitch({
    super.key,
    this.tileKey,
    required this.icon,
    required this.title,
    this.hint,
    required this.value,
    required this.onChanged,
  });

  final Key? tileKey;
  final IconData icon;
  final String title;
  final String? hint;
  final bool value;

  /// Null disables the option.
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile(
    key: tileKey,
    secondary: Icon(icon),
    title: Text(title),
    subtitle: hint == null ? null : Text(hint!),
    value: value,
    onChanged: onChanged,
  );
}

/// An option with a few values, shown as a segmented button below its title
/// and hint. [tileKey] is the key of the tile.
class SettingsChoice<T> extends StatelessWidget {
  const SettingsChoice({
    super.key,
    this.tileKey,
    required this.icon,
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
    this.hint,
  });

  final Key? tileKey;
  final IconData icon;
  final String title;
  final T value;
  final Map<T, String> options;
  final void Function(T) onChanged;
  final String? hint;

  @override
  Widget build(BuildContext context) => ListTile(
    key: tileKey,
    leading: Icon(icon),
    title: Text(title),
    subtitle: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hint != null)
          Padding(padding: const EdgeInsets.only(top: 4), child: Text(hint!)),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: SegmentedButton<T>(
            showSelectedIcon: false,
            segments: [
              for (final e in options.entries)
                ButtonSegment(value: e.key, label: Text(e.value)),
            ],
            selected: {value},
            onSelectionChanged: (v) => onChanged(v.first),
          ),
        ),
      ],
    ),
  );
}

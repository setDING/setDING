import 'package:material_ui/material_ui.dart';

import 'package:flutter/rendering.dart';

import '../widgets/danger_zone.dart';
import '../widgets/section_header.dart';

// The building blocks of the settings categories (ADR-0050): a category is
// a SettingsSections list of titled SettingsSection groups, separated by
// dividers, and every option in them has a leading icon, so all texts start
// at one column. SettingsSwitch and SettingsChoice require the icon.

/// From this width on, the sections of a category flow into two columns
/// (#774); below it they fill the width in one column.
const settingsTwoColumnWidth = 1040.0;

/// The sections of a category, with a divider between two of them. On a
/// wide pane ([settingsTwoColumnWidth]) they flow into two columns of about
/// the same height, in order: the first sections on the left, the rest on
/// the right, and the keyboard moves through them column by column.
class SettingsSections extends StatelessWidget {
  const SettingsSections(this.sections, {super.key, this.twoColumns = true});

  /// The sections; usually [SettingsSection]s, or a widget with its own
  /// heading in the same style (the song display preview).
  final List<Widget> sections;

  /// False keeps one column at every width, for a section that needs the
  /// width itself (the song display preview).
  final bool twoColumns;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (!twoColumns ||
          sections.length < 2 ||
          constraints.maxWidth < settingsTwoColumnWidth) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, section) in sections.indexed) ...[
              if (i > 0) const Divider(height: _dividerHeight),
              section,
            ],
          ],
        );
      }
      return FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: _TwoColumns(
          dividerColor:
              DividerTheme.of(context).color ??
              Theme.of(context).colorScheme.outlineVariant,
          children: [
            for (final (i, section) in sections.indexed)
              FocusTraversalOrder(
                order: NumericFocusOrder(i.toDouble()),
                child: FocusTraversalGroup(child: section),
              ),
          ],
        ),
      );
    },
  );
}

const _dividerHeight = 24.0;
const _columnGap = 16.0;

/// Lays its children out in two columns of equal width, the first ones on
/// the left, split where the columns are closest in height, with a divider
/// between two children of a column.
class _TwoColumns extends MultiChildRenderObjectWidget {
  const _TwoColumns({required this.dividerColor, required super.children});

  final Color dividerColor;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderTwoColumns(dividerColor);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderTwoColumns renderObject,
  ) => renderObject.dividerColor = dividerColor;
}

class _TwoColumnsParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderTwoColumns extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _TwoColumnsParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _TwoColumnsParentData> {
  _RenderTwoColumns(this._dividerColor);

  Color _dividerColor;
  set dividerColor(Color value) {
    if (value == _dividerColor) return;
    _dividerColor = value;
    markNeedsPaint();
  }

  /// The top-left corners of the dividers, each a column wide.
  final _dividers = <Offset>[];
  double _columnWidth = 0;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _TwoColumnsParentData) {
      child.parentData = _TwoColumnsParentData();
    }
  }

  @override
  void performLayout() {
    final width = constraints.maxWidth;
    _columnWidth = (width - _columnGap) / 2;
    final children = getChildrenAsList();
    final heights = [
      for (final child in children)
        (child..layout(
              BoxConstraints.tightFor(width: _columnWidth),
              parentUsesSize: true,
            ))
            .size
            .height,
    ];
    final split = twoColumnSplit(heights, _dividerHeight);
    _dividers.clear();
    var height = 0.0;
    for (final (column, range) in [
      (0, (0, split)),
      (1, (split, heights.length)),
    ]) {
      final x = column * (_columnWidth + _columnGap);
      var y = 0.0;
      for (var i = range.$1; i < range.$2; i++) {
        if (i > range.$1) {
          _dividers.add(Offset(x, y + _dividerHeight / 2));
          y += _dividerHeight;
        }
        (children[i].parentData! as _TwoColumnsParentData).offset = Offset(
          x,
          y,
        );
        y += heights[i];
      }
      if (y > height) height = y;
    }
    size = constraints.constrain(Size(width, height));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final paint = Paint()..color = _dividerColor;
    for (final d in _dividers) {
      context.canvas.drawRect(
        Rect.fromLTWH(offset.dx + d.dx, offset.dy + d.dy, _columnWidth, 1),
        paint,
      );
    }
    defaultPaint(context, offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}

/// The number of [heights] that go into the left column so that the taller
/// of the two columns is as short as possible; on a tie, more go left. Two
/// items of a column have [gap] between them.
@visibleForTesting
int twoColumnSplit(List<double> heights, double gap) {
  double column(int from, int to) {
    if (from >= to) return 0;
    var h = (to - from - 1) * gap;
    for (var i = from; i < to; i++) {
      h += heights[i];
    }
    return h;
  }

  var best = 1;
  var bestHeight = double.infinity;
  for (var split = 1; split < heights.length; split++) {
    final h = column(0, split) > column(split, heights.length)
        ? column(0, split)
        : column(split, heights.length);
    if (h <= bestHeight) {
      best = split;
      bestHeight = h;
    }
  }
  return best;
}

/// A titled group of options of a settings category.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.title,
    this.hint,
    required this.children,
    this.danger = false,
  });

  final String title;

  /// Shows the section as the [DangerZone] tile, for actions that cannot be
  /// undone (ADR-0052).
  final bool danger;

  /// Explains the whole section, below the title.
  final String? hint;

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (danger) {
      return DangerZone(
        title: title,
        children: [
          if (hint case final hint?)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 4),
              child: Text(hint, style: theme.textTheme.bodyMedium),
            ),
          ...children,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The section header of the whole app (ADR-0051), less space above
        // it: the divider between two sections adds its own.
        SectionHeader(
          title,
          padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 4),
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
    this.link,
  });

  final Key? tileKey;
  final IconData icon;
  final String title;
  final T value;
  final Map<T, String> options;
  final void Function(T) onChanged;
  final String? hint;

  /// Shown below the choices, e.g. a [DocsLink] to the documentation.
  final Widget? link;

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
        ?link,
      ],
    ),
  );
}

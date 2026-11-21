import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/marker_icons.dart';
import '../../l10n/generated/app_localizations.dart';
import 'set_item_label.dart';

/// A marker as chosen in [showMarkerDialog]: the catalogue [icon] and the
/// [note] to store (empty when the marker shows its icon's name).
typedef MarkerChoice = ({String icon, String note});

/// The groups of the icon grid, in the order of the catalogue (ADR-0047).
List<(String, List<String>)> _groups(AppLocalizations l10n) => [
  (l10n.markerGroupBreak, const [MarkerIcons.breakIcon, MarkerIcons.drinks]),
  (
    l10n.markerGroupAnnouncement,
    const [MarkerIcons.announcement, MarkerIcons.microphone, MarkerIcons.guest],
  ),
  (
    l10n.markerGroupFlow,
    const [
      MarkerIcons.encore,
      MarkerIcons.transition,
      MarkerIcons.solo,
      MarkerIcons.applause,
    ],
  ),
  (
    l10n.markerGroupStage,
    const [MarkerIcons.instrument, MarkerIcons.tuning, MarkerIcons.click],
  ),
  (
    l10n.markerGroupShow,
    const [MarkerIcons.light, MarkerIcons.effects, MarkerIcons.celebration],
  ),
  (l10n.markerGroupGeneral, const [MarkerIcons.info, MarkerIcons.warning]),
];

/// Asks for a set marker (ADR-0047): an icon from the catalogue and a text,
/// prefilled with the icon's name. Without [icon] a new marker is added
/// (default: break); with it, the marker with [icon] and [note] is edited.
Future<MarkerChoice?> showMarkerDialog(
  BuildContext context, {
  String? icon,
  String? note,
}) => showDialog<MarkerChoice>(
  context: context,
  builder: (context) =>
      MarkerDialog(icon: icon, note: note, editing: icon != null),
);

/// The dialog of [showMarkerDialog].
class MarkerDialog extends StatefulWidget {
  const MarkerDialog({super.key, this.icon, this.note, this.editing = false});

  final String? icon;
  final String? note;
  final bool editing;

  @override
  State<MarkerDialog> createState() => _MarkerDialogState();
}

class _MarkerDialogState extends State<MarkerDialog> {
  late String _icon = widget.icon ?? MarkerIcons.defaultIcon;
  final _controller = TextEditingController();
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // A marker without a text of its own shows its icon's name in the
    // field, in this person's language.
    _controller.text =
        markerNote(_icon, widget.note) ??
        markerIconName(AppLocalizations.of(context), _icon);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _choose(String icon) {
    final l10n = AppLocalizations.of(context);
    setState(() {
      // The name of the previous icon follows the new one; a text of its
      // own stays.
      if (markerNote(_icon, _controller.text) == null) {
        _controller.text = markerIconName(l10n, icon);
      }
      _icon = icon;
    });
  }

  void _submit() => Navigator.pop<MarkerChoice>(context, (
    icon: _icon,
    note: markerNote(_icon, _controller.text) ?? '',
  ));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return AlertDialog(
      title: Text(widget.editing ? l10n.editMarker : l10n.addMarker),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The groups side by side, so the dialog fits a tablet.
              Wrap(
                spacing: 24,
                runSpacing: 8,
                children: [
                  for (final (title, keys) in _groups(l10n))
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: theme.textTheme.labelMedium),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final key in keys)
                              IconButton(
                                key: ValueKey('marker-icon-$key'),
                                tooltip: markerIconName(l10n, key),
                                isSelected: key == _icon,
                                style: IconButton.styleFrom(
                                  backgroundColor: key == _icon
                                      ? scheme.secondaryContainer
                                      : null,
                                  foregroundColor: key == _icon
                                      ? scheme.onSecondaryContainer
                                      : null,
                                ),
                                icon: Icon(markerIconData(key)),
                                onPressed: () => _choose(key),
                              ),
                          ],
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                key: const ValueKey('marker-text'),
                controller: _controller,
                maxLength: MarkerIcons.maxTextLength,
                maxLengthEnforcement: MaxLengthEnforcement.enforced,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: l10n.markerText,
                  hintText: markerIconName(l10n, _icon),
                ),
              ),
              const SizedBox(height: 8),
              Text(l10n.markerPreview, style: theme.textTheme.labelMedium),
              const SizedBox(height: 4),
              ValueListenableBuilder(
                valueListenable: _controller,
                builder: (context, value, _) =>
                    MarkerPreview(icon: _icon, note: value.text),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.save)),
      ],
    );
  }
}

/// A small version of a marker's page in live mode: its icon and title.
class MarkerPreview extends StatelessWidget {
  const MarkerPreview({super.key, required this.icon, required this.note});

  final String icon;
  final String note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            markerIconData(icon),
            size: 36,
            color: theme.colorScheme.secondary,
          ),
          const SizedBox(height: 8),
          Text(
            markerTitle(AppLocalizations.of(context), icon, note),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge,
          ),
        ],
      ),
    );
  }
}

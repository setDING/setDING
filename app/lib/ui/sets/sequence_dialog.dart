import 'package:chordpro/chordpro.dart';
import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../render/song_header.dart';

/// Result of [editSetSequence]; [value] null means "use the song's own
/// sequence".
class SequenceChoice {
  const SequenceChoice(this.value);

  final String? value;
}

/// Edits the song sequence of a set item (layer 2, ADR-0006). [original] is
/// the sequence from the song (`{x_sequence}`), [current] the set-specific
/// one. Returns null when cancelled.
Future<SequenceChoice?> editSetSequence(
  BuildContext context, {
  required String? original,
  required String? current,
}) => showDialog<SequenceChoice>(
  context: context,
  builder: (_) => _SequenceDialog(original: original, current: current),
);

class _SequenceDialog extends StatefulWidget {
  const _SequenceDialog({required this.original, required this.current});

  final String? original;
  final String? current;

  @override
  State<_SequenceDialog> createState() => _SequenceDialogState();
}

class _SequenceDialogState extends State<_SequenceDialog> {
  late final _controller = TextEditingController(
    text: widget.current ?? widget.original ?? '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final value = _controller.text.trim();
    // Same as the song (or empty): no set-specific sequence.
    final same = value.isEmpty || value == widget.original?.trim();
    Navigator.pop(context, SequenceChoice(same ? null : value));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return AlertDialog(
      title: Text(l10n.sequenceEdit),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.original == null
                  ? l10n.sequenceNoneInSong
                  : l10n.sequenceOriginal(widget.original!),
              style: muted,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.sequenceLabel,
                hintText: l10n.sequenceHint,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 12),
            if (parseSequence(_controller.text) case final items
                when items.isNotEmpty)
              SongSequenceView(items),
            const SizedBox(height: 12),
            Text(l10n.sequenceAbbreviations, style: muted),
          ],
        ),
      ),
      actions: [
        if (widget.current != null)
          TextButton(
            onPressed: () => Navigator.pop(context, const SequenceChoice(null)),
            child: Text(l10n.sequenceRestore),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _save, child: Text(l10n.save)),
      ],
    );
  }
}

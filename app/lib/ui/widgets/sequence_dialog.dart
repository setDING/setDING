import 'package:chordpro/chordpro.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/generated/app_localizations.dart';
import '../render/song_header.dart';

/// Result of [editSequence]; [value] null means "no own sequence" (in a set:
/// use the song's sequence; in the editor: remove `{x_sequence}`).
class SequenceChoice {
  const SequenceChoice(this.value);

  final String? value;
}

/// Edits a song sequence by tapping the parts of the song ([parts], see
/// `songParts`). [initial] is the sequence to start with. In a set,
/// [original] is the song's own sequence and [canRestore] offers to go back
/// to it. Returns null when cancelled.
Future<SequenceChoice?> editSequence(
  BuildContext context, {
  required String title,
  required List<SequenceItem> parts,
  String? initial,
  String? original,
  bool showOriginal = false,
  bool canRestore = false,
}) => showDialog<SequenceChoice>(
  context: context,
  builder: (_) => _SequenceDialog(
    title: title,
    parts: parts,
    initial: initial,
    original: original,
    showOriginal: showOriginal,
    canRestore: canRestore,
  ),
);

/// Parts offered when a song has no sections yet.
final _commonParts = parseSequence('I, V, PC, C, B, Solo, O');

/// One entry of the edited sequence: the part as written and how often.
typedef _Entry = ({String code, int repeat});

final _repeatPattern = RegExp(
  r'^(?:(\d+)\s*[x×]\s*)?(.*?)(?:\s*[x×]\s*(\d+)|\s*\((\d+)\s*[x×]\))?$',
);

List<_Entry> _entries(String text) => [
  for (final item in parseSequence(text))
    if (_repeatPattern.firstMatch(item.code) case final m?)
      (
        code: m.group(2)!,
        repeat: int.tryParse(m.group(1) ?? m.group(3) ?? m.group(4) ?? '') ?? 1,
      ),
];

String _text(List<_Entry> entries) => entries
    .map((e) => e.repeat > 1 ? '${e.code} x${e.repeat}' : e.code)
    .join(', ');

class _SequenceDialog extends StatefulWidget {
  const _SequenceDialog({
    required this.title,
    required this.parts,
    required this.initial,
    required this.original,
    required this.showOriginal,
    required this.canRestore,
  });

  final String title;
  final List<SequenceItem> parts;
  final String? initial;
  final String? original;
  final bool showOriginal;
  final bool canRestore;

  @override
  State<_SequenceDialog> createState() => _SequenceDialogState();
}

class _SequenceDialogState extends State<_SequenceDialog> {
  late final _controller = TextEditingController(text: widget.initial ?? '');
  bool _showText = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<_Entry> get _current => _entries(_controller.text);

  void _update(List<_Entry> entries) =>
      setState(() => _controller.text = _text(entries));

  /// Appends [code]; the same part twice in a row becomes a repeat (`C x2`).
  void _add(String code) {
    final entries = _current;
    if (entries.isNotEmpty && entries.last.code == code) {
      entries.last = (code: code, repeat: entries.last.repeat + 1);
    } else {
      entries.add((code: code, repeat: 1));
    }
    _update(entries);
  }

  void _remove(int index) => _update(_current..removeAt(index));

  void _save() {
    final value = _controller.text.trim();
    Navigator.pop(context, SequenceChoice(value.isEmpty ? null : value));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final songHasParts = widget.parts.isNotEmpty;
    final parts = songHasParts ? widget.parts : _commonParts;
    final entries = _current;
    final items = parseSequence(_controller.text);

    Widget chip(
      SequenceItem item, {
      VoidCallback? onTap,
      VoidCallback? onDelete,
    }) {
      final label = Text(
        item.code,
        style: TextStyle(
          color: SongSequenceView.foreground(scheme, item.part),
          fontWeight: FontWeight.w600,
        ),
      );
      final color = SongSequenceView.background(scheme, item.part);
      return Tooltip(
        message: SongSequenceView.partName(l10n, item),
        child: onDelete != null
            ? InputChip(
                key: const ValueKey('sequence-entry'),
                label: label,
                backgroundColor: color,
                side: BorderSide.none,
                onDeleted: onDelete,
                deleteIcon: const Icon(Icons.close, size: 16),
                deleteIconColor: SongSequenceView.foreground(scheme, item.part),
              )
            : ActionChip(
                key: ValueKey('sequence-part-${item.code}'),
                avatar: const Icon(Icons.add, size: 16),
                label: label,
                backgroundColor: color,
                side: BorderSide.none,
                onPressed: onTap,
              ),
      );
    }

    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.showOriginal) ...[
                Text(
                  widget.original == null
                      ? l10n.sequenceNoneInSong
                      : l10n.sequenceOriginal(widget.original!),
                  style: muted,
                ),
                const SizedBox(height: 12),
              ],
              // The sequence being edited.
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 56),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: scheme.outline),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: entries.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(l10n.sequenceEmpty, style: muted),
                      )
                    : Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (var i = 0; i < items.length; i++)
                            chip(items[i], onDelete: () => _remove(i)),
                        ],
                      ),
              ),
              const SizedBox(height: 16),
              Text(
                songHasParts
                    ? l10n.sequenceSongParts
                    : l10n.sequenceCommonParts,
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final part in parts)
                    chip(part, onTap: () => _add(part.code)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: entries.isEmpty ? null : () => _update([]),
                    icon: const Icon(Icons.clear_all),
                    label: Text(l10n.sequenceClear),
                  ),
                  TextButton.icon(
                    onPressed: () => setState(() => _showText = !_showText),
                    icon: Icon(_showText ? Icons.expand_less : Icons.edit_note),
                    label: Text(l10n.sequenceAsText),
                  ),
                ],
              ),
              if (_showText) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    labelText: l10n.sequenceLabel,
                    hintText: l10n.sequenceHint,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _save(),
                ),
                const SizedBox(height: 8),
                Text(l10n.sequenceAbbreviations, style: muted),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (widget.canRestore)
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

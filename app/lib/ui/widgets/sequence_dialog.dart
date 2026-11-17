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
/// `songParts`) or dragging them into place; entries of the sequence can be
/// moved by drag and drop. [initial] is the sequence to start with. In a set,
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

/// What is being dragged in the dialog: an entry of the sequence ([from] is
/// its index) or a part from the palette ([from] is null).
typedef _Drag = ({int? from, _Entry entry});

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

  /// Drops [drag] onto the entry at [index] (or after the last entry when
  /// [index] is the length): a moved entry takes the place of the entry it
  /// is dropped on, a new part is inserted before it.
  void _drop(_Drag drag, int index) {
    final entries = _current;
    final from = drag.from;
    if (from == null) {
      entries.insert(index.clamp(0, entries.length), drag.entry);
    } else {
      if (from == index) return;
      final entry = entries.removeAt(from);
      entries.insert(index.clamp(0, entries.length), entry);
    }
    _update(entries);
  }

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

    Text chipLabel(SequenceItem item) => Text(
      item.code,
      style: TextStyle(
        color: SongSequenceView.foreground(scheme, item.part),
        fontWeight: FontWeight.w600,
      ),
    );

    // What follows the pointer while dragging.
    Widget feedback(SequenceItem item) => Material(
      type: MaterialType.transparency,
      child: Chip(
        label: chipLabel(item),
        backgroundColor: SongSequenceView.background(scheme, item.part),
        side: BorderSide(color: scheme.primary, width: 2),
        elevation: 4,
      ),
    );

    // Shows where a dragged part will land.
    final marker = Container(
      key: const ValueKey('sequence-drop-marker'),
      width: 3,
      height: 32,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(2),
      ),
    );

    // A part of the song: tap appends it, long-press drags it into place.
    Widget part(SequenceItem item) => Tooltip(
      message: SongSequenceView.partName(l10n, item),
      child: LongPressDraggable<_Drag>(
        data: (from: null, entry: (code: item.code, repeat: 1)),
        feedback: feedback(item),
        child: ActionChip(
          key: ValueKey('sequence-part-${item.code}'),
          avatar: const Icon(Icons.add, size: 16),
          label: chipLabel(item),
          backgroundColor: SongSequenceView.background(scheme, item.part),
          side: BorderSide.none,
          onPressed: () => _add(item.code),
        ),
      ),
    );

    // An entry of the sequence: long-press drags it, dropping a part on it
    // moves the part to its position.
    Widget entry(int index) {
      final item = items[index];
      final chip = InputChip(
        key: const ValueKey('sequence-entry'),
        label: chipLabel(item),
        backgroundColor: SongSequenceView.background(scheme, item.part),
        side: BorderSide.none,
        onDeleted: () => _remove(index),
        deleteIcon: const Icon(Icons.close, size: 16),
        deleteIconColor: SongSequenceView.foreground(scheme, item.part),
      );
      return DragTarget<_Drag>(
        // Accepts its own entry too, so dropping it in place does nothing
        // instead of moving it to the end.
        onAcceptWithDetails: (details) => _drop(details.data, index),
        builder: (context, candidates, _) {
          final from = candidates.firstOrNull?.from;
          final hovered = candidates.isNotEmpty && from != index;
          final after = from != null && from < index;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hovered && !after) marker,
              Tooltip(
                message: SongSequenceView.partName(l10n, item),
                child: LongPressDraggable<_Drag>(
                  data: (from: index, entry: entries[index]),
                  feedback: feedback(item),
                  childWhenDragging: Opacity(opacity: 0.3, child: chip),
                  child: chip,
                ),
              ),
              if (hovered && after) marker,
            ],
          );
        },
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
              // The sequence being edited; dropping on the free space
              // appends.
              DragTarget<_Drag>(
                key: const ValueKey('sequence-drop-area'),
                onAcceptWithDetails: (details) =>
                    _drop(details.data, entries.length),
                builder: (context, candidates, _) => Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(minHeight: 56),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: candidates.isEmpty
                          ? scheme.outline
                          : scheme.primary,
                      width: candidates.isEmpty ? 1 : 2,
                    ),
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
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            for (var i = 0; i < items.length; i++) entry(i),
                            if (candidates.isNotEmpty) marker,
                          ],
                        ),
                ),
              ),
              if (entries.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(l10n.sequenceReorderHint, style: muted),
              ],
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
                children: [for (final item in parts) part(item)],
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

import 'package:chordpro/chordpro.dart' as cp;
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/generated/app_localizations.dart';
import '../render/song_header.dart';
import '../widgets/sequence_dialog.dart';

/// Metadata directives edited in the song details form, in form order.
const songDetailFields = [
  'title',
  'artist',
  'key',
  'capo',
  'tempo',
  'time',
  'x_sequence',
];

/// Highest capo fret offered, as in the song view.
const maxCapoFret = 9;

/// Shows a form with the main metadata of [source] (title, artist, key,
/// capo, tempo, time signature, sequence) and returns the source with the changed
/// directives, or null when cancelled. The ChordPro text stays the source of
/// truth (ADR-0003): the form only edits its directives. Keys are shown in
/// [notation] and written in international notation. The sequence is
/// built from [parts] (see `songParts`) in the same dialog as in a set.
Future<String?> editSongDetails(
  BuildContext context,
  String source, {
  cp.ChordNotation notation = cp.ChordNotation.international,
  List<cp.SequenceItem> parts = const [],
}) => showDialog<String>(
  context: context,
  builder: (_) =>
      _SongDetailsDialog(source: source, notation: notation, parts: parts),
);

/// One entry of a dropdown: the value written to the source and its label.
typedef DetailOption = ({String value, String label});

final _plainKey = RegExp(r'^[A-H][#b♯♭]?m?$');

/// Keys offered for [current] (the `{key}` value, empty if none): 12 major
/// and 12 minor keys in conventional spelling, labelled in [notation]. The
/// option matching [current] keeps its spelling (e.g. `A#`) so that an
/// unchanged key is not rewritten; a value that is no key is offered first.
List<DetailOption> keyDetailOptions(String current, cp.ChordNotation notation) {
  // Only a plain key matches an option; `G/D` is kept as written.
  final currentKey = _plainKey.hasMatch(current)
      ? cp.Key.tryParse(current)
      : null;
  var matched = current.isEmpty;
  final options = <DetailOption>[];
  for (final minor in [false, true]) {
    final c = cp.Key.tryParse(minor ? 'Cm' : 'C')!;
    for (var pitch = 0; pitch < 12; pitch++) {
      final key = c.transpose(pitch);
      final same = key == currentKey;
      matched |= same;
      options.add((
        value: same ? current : key.format(cp.ChordNotation.international),
        label: key.format(notation),
      ));
    }
  }
  return [if (!matched) (value: current, label: current), ...options];
}

class _SongDetailsDialog extends StatefulWidget {
  const _SongDetailsDialog({
    required this.source,
    required this.notation,
    required this.parts,
  });

  final String source;
  final cp.ChordNotation notation;
  final List<cp.SequenceItem> parts;

  @override
  State<_SongDetailsDialog> createState() => _SongDetailsDialogState();
}

class _SongDetailsDialogState extends State<_SongDetailsDialog> {
  late final Map<String, String> _values = {
    for (final name in songDetailFields)
      name: cp.sourceMetadata(widget.source, name) ?? '',
  };
  late final Map<String, TextEditingController> _text = {
    for (final name in ['title', 'artist', 'tempo', 'time'])
      name: TextEditingController(text: _values[name]),
  };

  /// The key suggested from the chords while the song has none (#919,
  /// ADR-0056); a person picks it, it is never written on its own.
  late final cp.KeyGuess? _keyGuess = cp.guessKey(
    cp.parseChordPro(widget.source),
  );

  /// Bumped when a suggested key is picked, so the key dropdown shows it.
  int _keyRevision = 0;

  void _pickKey(cp.Key key) => setState(() {
    _values['key'] = key.format(cp.ChordNotation.international);
    _keyRevision++;
  });

  @override
  void dispose() {
    for (final c in _text.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _editSequence() async {
    final l10n = AppLocalizations.of(context);
    final current = _values['x_sequence']!;
    final choice = await editSequence(
      context,
      title: l10n.sequenceLabel,
      parts: widget.parts,
      initial: current.isEmpty ? null : current,
    );
    if (choice == null || !mounted) return;
    setState(
      // A brace or line break would end the directive.
      () => _values['x_sequence'] = (choice.value ?? '').replaceAll(
        RegExp(r'[{}\n]'),
        '',
      ),
    );
  }

  void _apply() {
    for (final MapEntry(key: name, value: c) in _text.entries) {
      _values[name] = c.text;
    }
    var source = widget.source;
    for (final name in songDetailFields) {
      final value = _values[name]!.trim();
      if (value == (cp.sourceMetadata(source, name) ?? '')) continue;
      source = cp.setSourceMetadata(source, name, value);
    }
    Navigator.pop(context, source);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Widget field(
      String name,
      String label, {
      String? hint,
      bool number = false,
      bool autofocus = false,
    }) => TextFormField(
      key: ValueKey('songDetail-$name'),
      controller: _text[name],
      autofocus: autofocus,
      decoration: InputDecoration(labelText: label, hintText: hint),
      keyboardType: number ? TextInputType.number : TextInputType.text,
      inputFormatters: [
        if (number) FilteringTextInputFormatter.digitsOnly,
        // A closing brace would end the directive.
        FilteringTextInputFormatter.deny(RegExp(r'[{}\n]')),
      ],
      textInputAction: TextInputAction.next,
      onFieldSubmitted: name == 'time' ? (_) => _apply() : null,
    );
    Widget dropdown(
      String name,
      String label,
      String noneLabel,
      List<DetailOption> options,
    ) => DropdownButtonFormField<String>(
      key: ValueKey('songDetail-$name'),
      initialValue: _values[name],
      decoration: InputDecoration(labelText: label),
      menuMaxHeight: 640,
      // Long labels (e.g. "Capo: 3 (F#m)") are shortened in the field.
      isExpanded: true,
      items: [
        DropdownMenuItem(
          value: '',
          child: Text(noneLabel, overflow: TextOverflow.ellipsis),
        ),
        for (final o in options)
          DropdownMenuItem(
            value: o.value,
            child: Text(o.label, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (v) => setState(() => _values[name] = v ?? ''),
    );
    Widget pair(Widget a, Widget b) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: a),
        const SizedBox(width: 16),
        Expanded(child: b),
      ],
    );

    final sequence = _values['x_sequence']!;
    final capo = _values['capo']!;
    final frets = [for (var f = 1; f <= maxCapoFret; f++) '$f'];
    // The capo options show the sounding key, as the song header does.
    final key = cp.Key.tryParse(_values['key']!);
    String capoLabel(int fret) => key == null
        ? l10n.capoLabel(fret)
        : l10n.capoLabelWithKey(
            fret,
            key.transpose(fret).format(widget.notation),
          );
    return AlertDialog(
      title: Text(l10n.songDetails),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              field('title', l10n.title, autofocus: true),
              field('artist', l10n.artist),
              pair(
                KeyedSubtree(
                  key: ValueKey(_keyRevision),
                  child: dropdown(
                    'key',
                    l10n.metaKey,
                    l10n.noKey,
                    keyDetailOptions(_values['key']!, widget.notation),
                  ),
                ),
                dropdown('capo', l10n.capo, l10n.noCapo, [
                  if (capo.isNotEmpty && !frets.contains(capo))
                    (value: capo, label: capo),
                  for (final f in frets)
                    (value: f, label: capoLabel(int.parse(f))),
                ]),
              ),
              if (_keyGuess case final guess? when _values['key']!.isEmpty)
                _KeySuggestion(
                  guess: guess,
                  notation: widget.notation,
                  onPick: _pickKey,
                ),
              pair(
                field('tempo', l10n.metaTempo, number: true),
                field('time', l10n.metaTime, hint: l10n.timeHint),
              ),
              const SizedBox(height: 8),
              // The sequence is edited in the dialog of the sets, not typed.
              InkWell(
                key: const ValueKey('songDetail-x_sequence'),
                onTap: _editSequence,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: l10n.sequenceLabel,
                    suffixIcon: Icon(
                      Icons.edit_outlined,
                      semanticLabel: l10n.sequenceChange,
                    ),
                  ),
                  child: sequence.isEmpty
                      ? Text(
                          l10n.noSequence,
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        )
                      : SongSequenceView(cp.parseSequence(sequence)),
                ),
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
        FilledButton(onPressed: _apply, child: Text(l10n.ok)),
      ],
    );
  }
}

/// The keys suggested from the chords, as chips that set the key field.
class _KeySuggestion extends StatelessWidget {
  const _KeySuggestion({
    required this.guess,
    required this.notation,
    required this.onPick,
  });

  final cp.KeyGuess guess;
  final cp.ChordNotation notation;
  final ValueChanged<cp.Key> onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    Widget chip(cp.Key key) {
      final value = key.format(cp.ChordNotation.international);
      return ActionChip(
        key: ValueKey('songDetail-keyGuess-$value'),
        avatar: const Icon(Icons.auto_fix_high, size: 18),
        label: Text(key.format(notation)),
        tooltip: l10n.keyGuessUse(key.format(notation)),
        onPressed: () => onPick(key),
      );
    }

    return Container(
      // Left-aligned like the fields above, not centred in the column.
      width: double.infinity,
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        key: const ValueKey('songDetail-keyGuess'),
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            l10n.keyGuessHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          chip(guess.key),
          if (guess.alternative case final alternative?) chip(alternative),
        ],
      ),
    );
  }
}

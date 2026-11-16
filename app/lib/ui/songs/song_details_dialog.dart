import 'package:chordpro/chordpro.dart' as cp;
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/generated/app_localizations.dart';

/// Metadata directives edited in the song details form, in form order.
const songDetailFields = ['title', 'artist', 'key', 'capo', 'tempo', 'time'];

/// Shows a form with the main metadata of [source] (title, artist, key,
/// capo, tempo, time signature) and returns the source with the changed
/// directives, or null when cancelled. The ChordPro text stays the source of
/// truth (ADR-0003): the form only edits its directives.
Future<String?> editSongDetails(BuildContext context, String source) =>
    showDialog<String>(
      context: context,
      builder: (_) => _SongDetailsDialog(source: source),
    );

class _SongDetailsDialog extends StatefulWidget {
  const _SongDetailsDialog({required this.source});

  final String source;

  @override
  State<_SongDetailsDialog> createState() => _SongDetailsDialogState();
}

class _SongDetailsDialogState extends State<_SongDetailsDialog> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _fields = {
    for (final name in songDetailFields)
      name: TextEditingController(
        text: cp.sourceMetadata(widget.source, name) ?? '',
      ),
  };

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _apply() {
    if (!_form.currentState!.validate()) return;
    var source = widget.source;
    for (final MapEntry(key: name, value: c) in _fields.entries) {
      final value = c.text.trim();
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
      FormFieldValidator<String>? validator,
      bool autofocus = false,
    }) => TextFormField(
      key: ValueKey('songDetail-$name'),
      controller: _fields[name],
      autofocus: autofocus,
      decoration: InputDecoration(labelText: label, hintText: hint),
      keyboardType: number ? TextInputType.number : TextInputType.text,
      inputFormatters: [
        if (number) FilteringTextInputFormatter.digitsOnly,
        // A closing brace would end the directive.
        FilteringTextInputFormatter.deny(RegExp(r'[{}\n]')),
      ],
      textInputAction: TextInputAction.next,
      validator: validator,
      onFieldSubmitted: name == songDetailFields.last ? (_) => _apply() : null,
    );
    Widget pair(Widget a, Widget b) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: a),
        const SizedBox(width: 16),
        Expanded(child: b),
      ],
    );

    return AlertDialog(
      title: Text(l10n.songDetails),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                field('title', l10n.title, autofocus: true),
                field('artist', l10n.artist),
                pair(
                  field(
                    'key',
                    l10n.metaKey,
                    validator: (v) {
                      final text = v?.trim() ?? '';
                      if (text.isEmpty || cp.Key.tryParse(text) != null) {
                        return null;
                      }
                      return l10n.invalidKey;
                    },
                  ),
                  field('capo', l10n.capo, number: true),
                ),
                pair(
                  field('tempo', l10n.metaTempo, number: true),
                  field('time', l10n.metaTime, hint: l10n.timeHint),
                ),
              ],
            ),
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

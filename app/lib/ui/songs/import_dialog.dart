import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/import_export.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../providers.dart';
import '../widgets/dialogs.dart';
import '../widgets/file_actions.dart';

/// Shows the import dialog and imports the chosen files.
Future<void> showImportDialog(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const _ImportDialog());

class _ImportDialog extends ConsumerStatefulWidget {
  const _ImportDialog();

  @override
  ConsumerState<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends ConsumerState<_ImportDialog> {
  bool _german = false;
  bool _busy = false;

  Future<void> _import() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final files = await pickFiles(extensions: [...chordProExtensions, 'zip']);
      if (files.isEmpty) {
        setState(() => _busy = false);
        return;
      }
      final result = await ref
          .read(importExportProvider)
          .importFiles(files, germanNotation: _german);
      final message = [
        l10n.importResult(result.imported),
        if (result.skipped.isNotEmpty)
          l10n.importSkipped(result.skipped.join(', ')),
      ].join('\n');
      if (mounted) Navigator.pop(context);
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showMessage(context, l10n.errorGeneric('$e'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.importTitle),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.importDescription),
            const SizedBox(height: 12),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _german,
              onChanged: _busy
                  ? null
                  : (v) => setState(() => _german = v ?? false),
              title: Text(l10n.importGermanNotation),
              subtitle: Text(l10n.importGermanNotationHint),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton.icon(
          onPressed: _busy ? null : _import,
          icon: _busy
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.file_open_outlined),
          label: Text(l10n.chooseFiles),
        ),
      ],
    );
  }
}

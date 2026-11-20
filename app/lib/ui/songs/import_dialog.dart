import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/backup.dart';
import '../../data/import_export.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../providers.dart';
import '../backup/backup_actions.dart';
import '../widgets/dialogs.dart';
import '../widgets/file_actions.dart';

/// Shows the import dialog and imports the chosen files. [pick] chooses
/// them (the platform's file dialog by default; tests pass their files).
Future<void> showImportDialog(
  BuildContext context, {
  Future<List<ImportFile>> Function({List<String>? extensions}) pick =
      pickFiles,
}) => showDialog<void>(
  context: context,
  builder: (_) => _ImportDialog(pick: pick, parent: context),
);

class _ImportDialog extends ConsumerStatefulWidget {
  const _ImportDialog({required this.pick, required this.parent});

  final Future<List<ImportFile>> Function({List<String>? extensions}) pick;

  /// Where the dialog was opened, for the backup import that replaces it.
  final BuildContext parent;

  @override
  ConsumerState<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends ConsumerState<_ImportDialog> {
  bool _german = false;
  bool _busy = false;

  /// After an import with ChordPro problems (#314): the result to report.
  ImportResult? _result;

  Future<void> _import() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final files = await widget.pick(
        extensions: [...chordProExtensions, 'zip'],
      );
      if (files.isEmpty) {
        setState(() => _busy = false);
        return;
      }
      // A setDING backup is imported as a whole library (ADR-0043).
      if (files.length == 1 &&
          files.single.name.toLowerCase().endsWith('.zip') &&
          await BackupService.isBackup(files.single.bytes)) {
        if (!mounted) return;
        Navigator.pop(context);
        final parent = widget.parent;
        if (parent.mounted) await importBackup(parent, files.single.bytes);
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
      if (result.problems.isNotEmpty) {
        if (mounted) {
          setState(() {
            _busy = false;
            _result = result;
          });
        }
        return;
      }
      if (mounted) Navigator.pop(context);
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showMessage(context, l10n.errorGeneric('$e'));
    }
  }

  /// Fixes what can be fixed automatically and closes the dialog.
  Future<void> _fix(ImportResult result) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final fixed = await ref.read(importExportProvider).fixProblems([
        for (final p in result.problems)
          if (p.fixable) p.songId,
      ]);
      if (mounted) Navigator.pop(context);
      messenger.showSnackBar(SnackBar(content: Text(l10n.songsFixed(fixed))));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showMessage(context, l10n.errorGeneric('$e'));
    }
  }

  /// The import result with the songs whose ChordPro has problems.
  Widget _problemsReport(BuildContext context, ImportResult result) {
    final l10n = AppLocalizations.of(context);
    const shown = 8;
    final problems = result.problems;
    return AlertDialog(
      key: const Key('import-problems'),
      icon: const Icon(Icons.warning_amber_rounded),
      title: Text(l10n.importProblemsTitle),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              [
                l10n.importResult(result.imported),
                if (result.skipped.isNotEmpty)
                  l10n.importSkipped(result.skipped.join(', ')),
              ].join('\n'),
            ),
            const SizedBox(height: 12),
            Text(l10n.importProblemsMessage(problems.length)),
            const SizedBox(height: 8),
            for (final p in problems.take(shown))
              Text('• ${l10n.importProblemItem(p.title, p.count)}'),
            if (problems.length > shown)
              Text(l10n.moreProblems(problems.length - shown)),
            const SizedBox(height: 12),
            Text(
              l10n.importProblemsHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text(l10n.close),
        ),
        if (problems.any((p) => p.fixable))
          FilledButton(
            onPressed: _busy ? null : () => _fix(result),
            child: Text(l10n.fixProblems),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_result case final result?) return _problemsReport(context, result);
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

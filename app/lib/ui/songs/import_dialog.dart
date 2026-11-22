import 'package:chordpro/chordpro.dart' as cp;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/backup.dart';
import '../../data/import_export.dart';
import '../../data/set_archive.dart';
import '../../data/song_archive.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../providers.dart';
import '../../settings/settings.dart';
import '../backup/full_backup.dart';
import '../sets/set_archive_dialogs.dart';
import '../widgets/dialogs.dart';
import '../widgets/file_actions.dart';
import 'song_archive_dialogs.dart';

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

  /// Keys picked in the report so far (#925).
  int _keysSet = 0;

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
        if (parent.mounted) await openBackup(parent, files.single.bytes);
        return;
      }
      // An exported set is imported as a set (ADR-0043 §1b).
      if (files.length == 1 &&
          files.single.name.toLowerCase().endsWith('.zip')) {
        final SetArchive? archive;
        try {
          archive = await SetArchiveService.read(files.single.bytes);
        } on BackupFormatException {
          if (!mounted) return;
          setState(() => _busy = false);
          showMessage(context, l10n.setArchiveNewer);
          return;
        }
        if (archive != null) {
          if (!mounted) return;
          Navigator.pop(context);
          final parent = widget.parent;
          if (parent.mounted) {
            await importSetArchive(
              parent,
              files.single.bytes,
              archive: archive,
              bandId: ref.read(currentBandProvider).id,
            );
          }
          return;
        }
      }
      // Exported songs are imported with their attachments (ADR-0043 §1c).
      if (files.length == 1 &&
          files.single.name.toLowerCase().endsWith('.zip')) {
        final SongArchive? archive;
        try {
          archive = await SongArchiveService.read(files.single.bytes);
        } on BackupFormatException {
          if (!mounted) return;
          setState(() => _busy = false);
          showMessage(context, l10n.songArchiveNewer);
          return;
        }
        if (archive != null) {
          if (!mounted) return;
          Navigator.pop(context);
          final parent = widget.parent;
          if (parent.mounted) {
            await importSongArchive(
              parent,
              files.single.bytes,
              archive: archive,
            );
          }
          return;
        }
      }
      final result = await ref
          .read(importExportProvider)
          .importFiles(files, germanNotation: _german);
      final message = [
        l10n.importResult(result.imported),
        if (result.skipped.isNotEmpty)
          l10n.importSkipped(result.skipped.join(', ')),
      ].join('\n');
      if (result.needsReview) {
        if (mounted) {
          setState(() {
            _busy = false;
            _result = result;
          });
        }
        return;
      }
      if (mounted) Navigator.pop(context);
      showMessageOn(messenger, message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showMessage(context, l10n.errorGeneric('$e'));
    }
  }

  /// Fixes what can be fixed automatically; closes the dialog unless
  /// short-form labels are still to be converted.
  Future<void> _fix(ImportResult result) => _apply(
    (service) => service.fixProblems([
      for (final p in result.problems)
        if (p.fixable) p.songId,
    ]),
    AppLocalizations.of(context).songsFixed,
    result.copyWith(problems: const []),
  );

  /// Converts short-form section labels (#672); closes the dialog unless
  /// problems are still to be fixed.
  Future<void> _convertLabels(ImportResult result) => _apply(
    (service) => service.convertLegacyLabels(result.legacyLabels),
    AppLocalizations.of(context).songsLabelsConverted,
    result.copyWith(legacyLabels: const []),
  );

  Future<void> _apply(
    Future<int> Function(ImportExportService service) action,
    String Function(int count) done,
    ImportResult rest,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final count = await action(ref.read(importExportProvider));
      showMessageOn(messenger, done(count));
      if (!mounted) return;
      if (rest.hasActions) {
        setState(() {
          _busy = false;
          _result = rest;
        });
      } else {
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showMessage(context, l10n.errorGeneric('$e'));
    }
  }

  /// Writes the picked [key] to the song of [suggestion] (#925, ADR-0056);
  /// closes the dialog when nothing is left to do.
  Future<void> _pickKey(
    ImportResult result,
    ImportKeySuggestion suggestion,
    cp.Key key,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      if (await ref.read(importExportProvider).setKey(suggestion.songId, key)) {
        _keysSet++;
      }
      final rest = result.copyWith(
        keySuggestions: [
          for (final s in result.keySuggestions)
            if (s.songId != suggestion.songId) s,
        ],
      );
      if (!mounted) return;
      if (rest.hasActions) {
        setState(() {
          _busy = false;
          _result = rest;
        });
      } else {
        Navigator.pop(context);
        showMessageOn(messenger, l10n.importKeysSet(_keysSet));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showMessage(context, l10n.errorGeneric('$e'));
    }
  }

  /// One imported song without a key and the keys suggested for it.
  Widget _keySuggestionRow(
    ImportResult result,
    ImportKeySuggestion suggestion,
    cp.ChordNotation notation,
  ) {
    final l10n = AppLocalizations.of(context);
    Widget chip(cp.Key key) {
      final name = key.format(notation);
      return ActionChip(
        key: ValueKey(
          'import-key-${suggestion.songId}-'
          '${key.format(cp.ChordNotation.international)}',
        ),
        avatar: const Icon(Icons.auto_fix_high, size: 18),
        label: Text(name),
        tooltip: l10n.keyGuessUse(name),
        onPressed: _busy ? null : () => _pickKey(result, suggestion, key),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(suggestion.title, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          chip(suggestion.guess.key),
          if (suggestion.guess.alternative case final alternative?) ...[
            const SizedBox(width: 8),
            chip(alternative),
          ],
        ],
      ),
    );
  }

  /// The import result with the songs whose ChordPro has problems or
  /// short-form section labels, and the songs without a key.
  Widget _problemsReport(BuildContext context, ImportResult result) {
    final l10n = AppLocalizations.of(context);
    const shown = 8;
    final problems = result.problems;
    final labels = result.legacyLabels;
    final keys = result.keySuggestions;
    final fixable = problems.any((p) => p.fixable);
    final notation = ref.watch(settingsProvider).notation;
    return AlertDialog(
      key: const Key('import-problems'),
      icon: Icon(
        problems.isNotEmpty
            ? Icons.warning_amber_rounded
            : labels.isNotEmpty
            ? Icons.label_outline
            : Icons.auto_fix_high,
      ),
      title: Text(l10n.importProblemsTitle),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
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
              if (problems.isNotEmpty) ...[
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
              if (labels.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  l10n.importLegacyLabelsMessage(labels.length),
                  key: const Key('import-legacy-labels'),
                ),
              ],
              if (keys.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  l10n.importKeySuggestionsMessage(keys.length),
                  key: const Key('import-key-suggestions'),
                ),
                for (final k in keys.take(shown))
                  _keySuggestionRow(result, k, notation),
                if (keys.length > shown) ...[
                  const SizedBox(height: 4),
                  Text(l10n.importKeySuggestionsMore(keys.length - shown)),
                ],
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text(l10n.close),
        ),
        if (labels.isNotEmpty)
          fixable
              ? TextButton(
                  onPressed: _busy ? null : () => _convertLabels(result),
                  child: Text(l10n.convertLabels),
                )
              : FilledButton(
                  onPressed: _busy ? null : () => _convertLabels(result),
                  child: Text(l10n.convertLabels),
                ),
        if (fixable)
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
              controlAffinity: ListTileControlAffinity.leading,
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

import 'dart:async';
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/backup.dart';
import '../../data/band_view.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../providers.dart';
import '../../settings/settings.dart' show sharedPreferencesProvider;
import '../../sync/sync_controller.dart';
import '../songs/song_screen.dart';
import '../widgets/dialogs.dart';
import '../widgets/file_actions.dart';
import 'full_backup.dart' show lastBackupKey;

/// Saves a file; tests replace it.
typedef SaveFile = Future<bool> Function(
  String fileName,
  Uint8List bytes, {
  String mimeType,
});

/// How the backup is saved: the platform's save dialog (a download on web).
final saveFileProvider = Provider<SaveFile>((ref) => saveFile);

/// Exports [library] as a backup archive (ADR-0043). An organization is
/// synced first; the export stops if anything is not on this device yet.
Future<void> exportBackup(
  BuildContext context,
  WidgetRef ref,
  LibraryView library,
) async {
  final l10n = AppLocalizations.of(context);
  final service = ref.read(backupServiceProvider);
  final web = ref.read(webClientProvider);
  final fetcher = ref.read(attachmentFetcherProvider);
  final name = library.isLocal ? l10n.bandLocal : library.name;
  await runBackupExport(
    context,
    ref,
    sync: !library.isLocal,
    check: () => service.blocker(library.id, checkFiles: !web),
    build: () => service.export(
      library.id,
      libraryName: name,
      // The web client loads the files for the export (ADR-0018).
      readFile: web
          ? (a) async => (await fetcher.fetch(a.id))?.readAsBytes()
          : null,
    ),
    fileName: BackupService.fileName(name, DateTime.now()),
    recordLocal: library.isLocal,
  );
}

/// Runs a backup export with a progress dialog: with [sync], a sync first
/// (mandatory, ADR-0043) and [check] after it; then [build] and saving as
/// [fileName]. [recordLocal]: the archive holds the local library, so its
/// backup time is recorded (#639). Problems are shown in a dialog.
Future<void> runBackupExport(
  BuildContext context,
  WidgetRef ref, {
  required bool sync,
  required Future<BackupBlocker?> Function() check,
  required Future<Uint8List> Function() build,
  required String fileName,
  bool recordLocal = false,
}) async {
  final l10n = AppLocalizations.of(context);
  final step = ValueNotifier<String>(
    sync ? l10n.backupSyncing : l10n.backupCollecting,
  );
  final navigator = Navigator.of(context);
  var open = true;
  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          key: const Key('backup-progress'),
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 24),
              Expanded(
                child: ValueListenableBuilder(
                  valueListenable: step,
                  builder: (_, text, _) => Text(text),
                ),
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(() => open = false),
  );

  void close() {
    if (open) navigator.pop();
    open = false;
  }

  Future<void> fail(String message) async {
    close();
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('backup-failed'),
        title: Text(l10n.backupFailedTitle),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.close),
          ),
        ],
      ),
    );
  }

  try {
    if (sync) {
      // Mandatory: the archive must hold what the server has (ADR-0043).
      final report = await ref.read(syncControllerProvider.notifier).syncNow();
      if (report == null) {
        await fail(l10n.backupSyncDeferred);
        return;
      }
      if (report.error != null) {
        await fail(l10n.backupSyncFailed);
        return;
      }
      switch (await check()) {
        case BackupBlocker.pendingChanges:
          await fail(l10n.backupPendingChanges);
          return;
        case BackupBlocker.conflicts:
          await fail(l10n.backupConflicts);
          return;
        case BackupBlocker.missingFiles:
          await fail(l10n.backupMissingFiles);
          return;
        case null:
      }
      step.value = l10n.backupCollecting;
    }
    final Uint8List bytes;
    try {
      bytes = await build();
    } on BackupFileMissingException catch (e) {
      await fail(l10n.backupFileMissing(e.name, e.songTitle));
      return;
    }
    close();
    final saved = await ref.read(saveFileProvider)(
      fileName,
      bytes,
      mimeType: 'application/zip',
    );
    if (!saved) return;
    if (recordLocal) {
      await ref
          .read(sharedPreferencesProvider)
          .setString(lastBackupKey, DateTime.now().toIso8601String());
    }
    if (context.mounted) showMessage(context, l10n.backupSaved);
  } catch (e) {
    await fail(l10n.errorGeneric('$e'));
  } finally {
    close();
    step.dispose();
  }
}

/// Imports a backup archive into the current library (ADR-0043), always as
/// a copy: asks where the sets go and what to do with songs that exist with
/// a different text, then reports the result.
Future<void> importBackup(BuildContext context, Uint8List zip) async {
  final BackupContents contents;
  try {
    contents = await BackupService.read(zip);
  } on BackupFormatException catch (e) {
    if (!context.mounted) return;
    final l10n = AppLocalizations.of(context);
    showMessage(
      context,
      e.newerVersion == null ? l10n.backupInvalid : l10n.backupNewer,
    );
    return;
  }
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (_) => _BackupImportDialog(contents: contents),
  );
}

class _BackupImportDialog extends ConsumerStatefulWidget {
  const _BackupImportDialog({required this.contents});

  final BackupContents contents;

  @override
  ConsumerState<_BackupImportDialog> createState() =>
      _BackupImportDialogState();
}

class _BackupImportDialogState extends ConsumerState<_BackupImportDialog> {
  BackupPreview? _preview;
  BackupImportResult? _result;
  BackupDuplicates _duplicates = BackupDuplicates.keepExisting;

  /// Archive band -> target band (null: skip).
  Map<String, String?>? _bands;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final library = ref.read(currentLibraryProvider);
    ref.read(backupServiceProvider).preview(widget.contents, library.id).then((
      preview,
    ) {
      if (mounted) setState(() => _preview = preview);
    });
  }

  /// Bands of the current library whose sets the person may manage.
  List<BandView> _targets() {
    final library = ref.watch(currentLibraryProvider);
    final bands = ref.watch(bandsProvider).value ?? const <BandView>[];
    return [
      for (final b in bands)
        if (library.isLocal
            ? b.isLocal
            : b.organizationId == library.id && b.canManageSets)
          b,
    ];
  }

  /// Default target of each archive band: a band with the same name, else
  /// the only band, else none.
  Map<String, String?> _defaultBands(List<BandView> targets) => {
    for (final b in widget.contents.bands)
      b['id'] as String:
          targets
              .where(
                (t) =>
                    t.name.trim().toLowerCase() ==
                    (b['name'] as String? ?? '').trim().toLowerCase(),
              )
              .firstOrNull
              ?.id ??
          (targets.length == 1 ? targets.single.id : null),
  };

  Future<void> _import() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      final library = ref.read(currentLibraryProvider);
      final result = await ref
          .read(backupServiceProvider)
          .import(
            widget.contents,
            libraryId: library.id,
            bands: _bands ?? const {},
            duplicates: _duplicates,
          );
      if (mounted) {
        setState(() {
          _busy = false;
          _result = result;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showMessage(context, l10n.errorGeneric('$e'));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_result case final result?) return _report(context, result);
    final l10n = AppLocalizations.of(context);
    final preview = _preview;
    final targets = _targets();
    // Defaults once the bands are loaded; the person's choice is kept.
    final bands = targets.isEmpty
        ? _defaultBands(targets)
        : _bands ??= _defaultBands(targets);
    final setsPerBand = <String, int>{};
    for (final s in widget.contents.sets) {
      final band = s['bandId'] as String? ?? '';
      setsPerBand[band] = (setsPerBand[band] ?? 0) + 1;
    }
    final archiveBands = [
      for (final b in widget.contents.bands)
        if ((setsPerBand[b['id']] ?? 0) > 0) b,
    ];
    return AlertDialog(
      key: const Key('backup-import'),
      title: Text(l10n.backupImportTitle),
      content: SizedBox(
        width: 480,
        child: preview == null
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.backupImportSummary(
                        widget.contents.sourceName,
                        preview.songs,
                        widget.contents.sets.length,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.backupImportCopyHint,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (preview.identical > 0) ...[
                      const SizedBox(height: 12),
                      Text(l10n.backupImportIdentical(preview.identical)),
                    ],
                    if (preview.differing > 0) ...[
                      const SizedBox(height: 12),
                      Text(l10n.backupImportDiffering(preview.differing)),
                      RadioGroup<BackupDuplicates>(
                        groupValue: _duplicates,
                        onChanged: (v) => setState(() => _duplicates = v!),
                        child: Column(
                          children: [
                            RadioListTile(
                              key: const Key('backup-keep-existing'),
                              contentPadding: EdgeInsets.zero,
                              value: BackupDuplicates.keepExisting,
                              title: Text(l10n.backupKeepExisting),
                            ),
                            RadioListTile(
                              key: const Key('backup-add-all'),
                              contentPadding: EdgeInsets.zero,
                              value: BackupDuplicates.addAll,
                              title: Text(l10n.backupAddAll),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (archiveBands.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(l10n.backupImportSetsTo),
                      for (final b in archiveBands)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: DropdownButtonFormField<String?>(
                            key: Key('backup-band-${b['id']}'),
                            initialValue: bands[b['id']],
                            decoration: InputDecoration(
                              labelText: l10n.backupBandSets(
                                b['name'] as String? ?? '',
                                setsPerBand[b['id']] ?? 0,
                              ),
                            ),
                            items: [
                              for (final t in targets)
                                DropdownMenuItem(
                                  value: t.id,
                                  child: Text(
                                    t.isLocal ? l10n.bandLocal : t.name,
                                  ),
                                ),
                              DropdownMenuItem(
                                value: null,
                                child: Text(l10n.backupSkipSets),
                              ),
                            ],
                            onChanged: (v) =>
                                setState(() => bands[b['id'] as String] = v),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const Key('backup-import-start'),
          onPressed: _busy || preview == null ? null : _import,
          child: _busy
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.backupImportStart),
        ),
      ],
    );
  }

  Widget _report(BuildContext context, BackupImportResult result) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      key: const Key('backup-import-result'),
      title: Text(l10n.backupImportDone),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                [
                  l10n.backupResultSongs(result.imported),
                  if (result.identical > 0)
                    l10n.backupResultIdentical(result.identical),
                  if (result.keptExisting > 0)
                    l10n.backupResultKept(result.keptExisting),
                  l10n.backupResultSets(result.sets),
                  if (result.files > 0) l10n.backupResultFiles(result.files),
                ].join('\n'),
              ),
              if (result.additional.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(l10n.backupResultAdditional(result.additional.length)),
                for (final song in result.additional)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: const Icon(Icons.library_music_outlined),
                    title: Text(song.title),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => SongScreen(songId: song.id),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.close),
        ),
      ],
    );
  }
}

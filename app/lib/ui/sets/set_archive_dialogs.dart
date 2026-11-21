import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/backup.dart';
import '../../data/band_view.dart';
import '../../data/database.dart';
import '../../data/import_export.dart';
import '../../data/set_archive.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../providers.dart';
import '../../sync/sync_controller.dart' show attachmentFetcherProvider;
import '../backup/backup_actions.dart' show saveFileProvider;
import '../songs/song_screen.dart';
import '../widgets/dialogs.dart';
import '../widgets/file_actions.dart';
import 'set_screen.dart';

/// Asks what the archive of [set] holds and exports it (ADR-0043 §1b).
Future<void> exportSetArchive(
  BuildContext context,
  WidgetRef ref,
  SetlistEntry set,
) async {
  final options = await showDialog<SetArchiveOptions>(
    context: context,
    builder: (_) => const _ExportDialog(),
  );
  if (options == null || !context.mounted) return;
  final l10n = AppLocalizations.of(context);
  final web = ref.read(webClientProvider);
  final fetcher = ref.read(attachmentFetcherProvider);
  try {
    final bytes = await ref
        .read(setArchiveServiceProvider)
        .export(
          set.id,
          options: options,
          // The web client loads the files for the export (ADR-0018).
          readFile: web
              ? (AttachmentEntry a) async =>
                    (await fetcher.fetch(a.id))?.readAsBytes()
              : null,
        );
    final saved = await ref.read(saveFileProvider)(
      SetArchiveService.fileName(set),
      bytes,
      mimeType: 'application/zip',
    );
    if (saved && context.mounted) showMessage(context, l10n.exported);
  } on BackupFileMissingException catch (e) {
    if (context.mounted) {
      showMessage(context, l10n.backupFileMissing(e.name, e.songTitle));
    }
  } catch (e) {
    if (context.mounted) showMessage(context, l10n.errorGeneric('$e'));
  }
}

/// The options of a set export.
class _ExportDialog extends StatefulWidget {
  const _ExportDialog();

  @override
  State<_ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<_ExportDialog> {
  var _options = const SetArchiveOptions();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      key: const Key('set-export'),
      title: Text(l10n.setExportTitle),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.setExportHint),
              const SizedBox(height: 8),
              ..._optionTiles(
                l10n,
                _options,
                (o) => setState(() => _options = o),
                keyPrefix: 'set-export',
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
        FilledButton(
          key: const Key('set-export-start'),
          onPressed: () => Navigator.pop(context, _options),
          child: Text(l10n.setExportStart),
        ),
      ],
    );
  }
}

/// Checkboxes for [options]; [available] limits them to what an archive
/// holds.
List<Widget> _optionTiles(
  AppLocalizations l10n,
  SetArchiveOptions options,
  ValueChanged<SetArchiveOptions> changed, {
  required String keyPrefix,
  SetArchiveOptions available = const SetArchiveOptions(personal: true),
}) => [
  if (available.arrangements)
    CheckboxListTile(
      key: Key('$keyPrefix-arrangements'),
      contentPadding: EdgeInsets.zero,
      value: options.arrangements,
      title: Text(l10n.setArchiveArrangements),
      onChanged: (v) => changed(options.copyWith(arrangements: v)),
    ),
  if (available.setSettings)
    CheckboxListTile(
      key: Key('$keyPrefix-set-settings'),
      contentPadding: EdgeInsets.zero,
      value: options.setSettings,
      title: Text(l10n.setArchiveSetSettings),
      onChanged: (v) => changed(options.copyWith(setSettings: v)),
    ),
  if (available.attachments)
    CheckboxListTile(
      key: Key('$keyPrefix-attachments'),
      contentPadding: EdgeInsets.zero,
      value: options.attachments,
      title: Text(l10n.setArchiveAttachments),
      onChanged: (v) => changed(options.copyWith(attachments: v)),
    ),
  if (available.personal)
    CheckboxListTile(
      key: Key('$keyPrefix-personal'),
      contentPadding: EdgeInsets.zero,
      value: options.personal,
      title: Text(l10n.setArchivePersonal),
      subtitle: keyPrefix == 'set-export'
          ? Text(l10n.setArchivePersonalHint)
          : null,
      onChanged: (v) => changed(options.copyWith(personal: v)),
    ),
];

/// Lets the person choose a ZIP file and imports it as a set into [bandId]
/// (preselected). [pick] chooses the file (tests pass theirs).
Future<void> pickSetArchive(
  BuildContext context, {
  String? bandId,
  Future<List<ImportFile>> Function({List<String>? extensions}) pick =
      pickFiles,
}) async {
  final files = await pick(extensions: const ['zip']);
  if (files.isEmpty || !context.mounted) return;
  await importSetArchive(context, files.first.bytes, bandId: bandId);
}

/// Imports the set archive [zip] (already read as [archive], if known):
/// a preview first, then the report (ADR-0043 §1b).
Future<void> importSetArchive(
  BuildContext context,
  Uint8List zip, {
  String? bandId,
  SetArchive? archive,
}) async {
  final l10n = AppLocalizations.of(context);
  var read = archive;
  try {
    read ??= await SetArchiveService.read(zip);
  } on BackupFormatException {
    if (context.mounted) showMessage(context, l10n.setArchiveNewer);
    return;
  }
  if (!context.mounted) return;
  if (read == null) {
    showMessage(context, l10n.setArchiveInvalid);
    return;
  }
  await showDialog<void>(
    context: context,
    builder: (_) => _ImportDialog(archive: read!, bandId: bandId),
  );
}

class _ImportDialog extends ConsumerStatefulWidget {
  const _ImportDialog({required this.archive, this.bandId});

  final SetArchive archive;
  final String? bandId;

  @override
  ConsumerState<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends ConsumerState<_ImportDialog> {
  String? _band;
  SetArchivePreview? _preview;
  late SetArchiveOptions _options = widget.archive.holds;
  BackupDuplicates _duplicates = BackupDuplicates.keepExisting;
  bool _replace = true;
  bool _overwrite = false;
  bool _busy = false;
  SetArchiveResult? _result;

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

  bool get _canCreateSongs => ref.read(currentLibraryProvider).canCreateSongs;

  Future<void> _load(String band) async {
    setState(() {
      _band = band;
      _preview = null;
    });
    final preview = await ref
        .read(setArchiveServiceProvider)
        .preview(widget.archive, bandId: band, canCreateSongs: _canCreateSongs);
    if (mounted && _band == band) setState(() => _preview = preview);
  }

  Future<void> _import() async {
    final l10n = AppLocalizations.of(context);
    final band = _band;
    final preview = _preview;
    if (band == null || preview == null) return;
    setState(() => _busy = true);
    try {
      final result = await ref
          .read(setArchiveServiceProvider)
          .import(
            widget.archive,
            bandId: band,
            canCreateSongs: _canCreateSongs,
            missingNote: l10n.setImportMissingNote,
            options: _options,
            duplicates: _duplicates,
            replace: preview.existingSet != null && _replace,
            overwriteArrangements: _overwrite,
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
    final targets = _targets();
    if (_band == null && targets.isNotEmpty) {
      final preferred =
          targets.where((t) => t.id == widget.bandId).firstOrNull ??
          targets.first;
      // After this frame: _load calls setState.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _band == null) _load(preferred.id);
      });
    }
    final preview = _preview;
    final archive = widget.archive;
    return AlertDialog(
      key: const Key('set-import'),
      title: Text(l10n.setImportTitle),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.setImportSummary(
                  archive.name,
                  archive.bandName,
                  archive.contents.songs.length,
                ),
              ),
              const SizedBox(height: 12),
              if (targets.isEmpty)
                Text(l10n.setImportNoBand)
              else
                DropdownButtonFormField<String>(
                  key: const Key('set-import-band'),
                  initialValue: _band,
                  decoration: InputDecoration(labelText: l10n.setImportBand),
                  items: [
                    for (final t in targets)
                      DropdownMenuItem(
                        value: t.id,
                        child: Text(t.isLocal ? l10n.bandLocal : t.name),
                      ),
                  ],
                  onChanged: (v) => v == null ? null : _load(v),
                ),
              if (targets.isNotEmpty && preview == null)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (preview != null) ..._previewParts(l10n, preview),
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
          key: const Key('set-import-start'),
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

  List<Widget> _previewParts(AppLocalizations l10n, SetArchivePreview preview) {
    final holds = widget.archive.holds;
    return [
      if (preview.existingSet case final existing?) ...[
        const SizedBox(height: 12),
        Text(l10n.setImportExisting(existing.name)),
        RadioGroup<bool>(
          groupValue: _replace,
          onChanged: (v) => setState(() => _replace = v!),
          child: Column(
            children: [
              RadioListTile(
                key: const Key('set-import-replace'),
                contentPadding: EdgeInsets.zero,
                value: true,
                title: Text(l10n.setImportReplace),
              ),
              RadioListTile(
                key: const Key('set-import-copy'),
                contentPadding: EdgeInsets.zero,
                value: false,
                title: Text(l10n.setImportCopy),
              ),
            ],
          ),
        ),
      ],
      if (preview.identical > 0) ...[
        const SizedBox(height: 12),
        Text(l10n.backupImportIdentical(preview.identical)),
      ],
      if (preview.added > 0) ...[
        const SizedBox(height: 12),
        Text(l10n.setImportAdded(preview.added)),
      ],
      if (preview.differing > 0 && _canCreateSongs) ...[
        const SizedBox(height: 12),
        Text(l10n.backupImportDiffering(preview.differing)),
        RadioGroup<BackupDuplicates>(
          groupValue: _duplicates,
          onChanged: (v) => setState(() => _duplicates = v!),
          child: Column(
            children: [
              RadioListTile(
                key: const Key('set-import-keep-existing'),
                contentPadding: EdgeInsets.zero,
                value: BackupDuplicates.keepExisting,
                title: Text(l10n.backupKeepExisting),
              ),
              RadioListTile(
                key: const Key('set-import-add-all'),
                contentPadding: EdgeInsets.zero,
                value: BackupDuplicates.addAll,
                title: Text(l10n.backupAddAll),
              ),
            ],
          ),
        ),
      ],
      if (preview.missing.isNotEmpty) ...[
        const SizedBox(height: 12),
        Text(l10n.setImportMissing(preview.missing.length)),
        for (final title in preview.missing)
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 4),
            child: Text('• $title'),
          ),
      ],
      if (holds.arrangements ||
          holds.setSettings ||
          holds.attachments ||
          holds.personal) ...[
        const SizedBox(height: 12),
        Text(l10n.setImportAlso),
        ..._optionTiles(
          l10n,
          _options,
          (o) => setState(() => _options = o),
          keyPrefix: 'set-import',
          available: holds,
        ),
      ],
      if (_options.arrangements && preview.arrangementConflicts > 0)
        CheckboxListTile(
          key: const Key('set-import-overwrite'),
          contentPadding: EdgeInsets.zero,
          value: _overwrite,
          title: Text(
            l10n.setImportOverwriteArrangements(preview.arrangementConflicts),
          ),
          onChanged: (v) => setState(() => _overwrite = v ?? false),
        ),
    ];
  }

  Widget _report(BuildContext context, SetArchiveResult result) {
    final l10n = AppLocalizations.of(context);
    final songs = result.songs;
    return AlertDialog(
      key: const Key('set-import-result'),
      title: Text(l10n.setImportDone),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                [
                  if (result.replaced) l10n.setImportReplaced,
                  l10n.backupResultSongs(songs.imported.length),
                  if (songs.identical > 0)
                    l10n.backupResultIdentical(songs.identical),
                  if (songs.keptExisting > 0)
                    l10n.backupResultKept(songs.keptExisting),
                  if (result.arrangements > 0)
                    l10n.setImportResultArrangements(result.arrangements),
                  if (songs.files > 0) l10n.backupResultFiles(songs.files),
                ].join('\n'),
              ),
              if (result.missing.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(l10n.setImportResultMissing),
                for (final title in result.missing)
                  Padding(
                    padding: const EdgeInsets.only(left: 8, top: 4),
                    child: Text('• $title'),
                  ),
              ],
              if (songs.additional.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(l10n.backupResultAdditional(songs.additional.length)),
                for (final song in songs.additional)
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
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.close),
        ),
        FilledButton(
          key: const Key('set-import-open'),
          onPressed: () {
            final band = _band;
            final navigator = Navigator.of(context);
            navigator.pop();
            // The set belongs to the chosen band: switch to it first.
            if (band != null) {
              ref.read(selectedBandIdProvider.notifier).select(band);
            }
            navigator.push(
              MaterialPageRoute<void>(
                builder: (_) => SetScreen(setId: result.setId),
              ),
            );
          },
          child: Text(l10n.setImportOpen),
        ),
      ],
    );
  }
}

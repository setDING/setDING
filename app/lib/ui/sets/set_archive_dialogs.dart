import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/backup.dart';
import '../../data/backup_providers.dart';
import '../../data/band_providers.dart';
import '../../data/band_view.dart';
import '../../data/database.dart';
import '../../data/import_export.dart';
import '../../data/set_archive.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../platform/web_client.dart';
import '../../sync/sync_controller.dart' show attachmentFetcherProvider;
import '../widgets/dialogs.dart';
import '../widgets/export_file.dart';
import '../widgets/export_format.dart';
import '../widgets/file_actions.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/section_header.dart';
import '../routes.dart';

/// Exports [set]: as the printable set list ([exportPdf], if given) or as a
/// setDING archive with options (ADR-0043 §1b, issue #870).
Future<void> exportSet(
  BuildContext context,
  WidgetRef ref,
  SetlistEntry set, {
  Future<void> Function()? exportPdf,
}) async {
  final formats = [
    if (exportPdf != null) ExportFormat.setListPdf,
    ExportFormat.archive,
  ];
  final choice = await showDialog<(ExportFormat, SetArchiveOptions)>(
    context: context,
    builder: (_) => _ExportDialog(
      formats: formats,
      initial: initialExportFormat(
        formats,
        ref.read(lastSetExportFormatProvider),
      ),
    ),
  );
  if (choice == null || !context.mounted) return;
  final (format, options) = choice;
  ref.read(lastSetExportFormatProvider.notifier).choose(format);
  if (format == ExportFormat.setListPdf) return exportPdf!();
  final web = ref.read(webClientProvider);
  final fetcher = ref.read(attachmentFetcherProvider);
  final service = ref.read(setArchiveServiceProvider);
  await exportFile(
    context,
    ref,
    fileName: SetArchiveService.fileName(set),
    mimeType: 'application/zip',
    build: () => service.export(
      set.id,
      options: options,
      // The web client loads the files for the export (ADR-0018).
      readFile: web
          ? (AttachmentEntry a) async =>
                (await fetcher.fetch(a.id))?.readAsBytes()
          : null,
    ),
  );
}

/// The format and options of a set export.
class _ExportDialog extends StatefulWidget {
  const _ExportDialog({required this.formats, required this.initial});

  final List<ExportFormat> formats;
  final ExportFormat initial;

  @override
  State<_ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<_ExportDialog> {
  late var _format = widget.initial;
  var _options = const SetArchiveOptions();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final archive = _format == ExportFormat.archive;
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
              Text(archive ? l10n.setExportHint : l10n.setExportHintPdf),
              ExportFormatChoice(
                available: widget.formats,
                value: _format,
                onChanged: (f) => setState(() => _format = f),
              ),
              if (archive) ...[
                SectionHeader(
                  l10n.setExportHeadingInclude,
                  padding: SectionHeader.insetPadding,
                ),
                ..._optionTiles(
                  l10n,
                  _options,
                  (o) => setState(() => _options = o),
                  keyPrefix: 'set-export',
                ),
              ],
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
          onPressed: () => Navigator.pop(context, (_format, _options)),
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
    ArchiveOptionTile(
      key: Key('$keyPrefix-arrangements'),
      value: options.arrangements,
      title: l10n.setArchiveArrangements,
      onChanged: (v) => changed(options.copyWith(arrangements: v)),
    ),
  if (available.setSettings)
    ArchiveOptionTile(
      key: Key('$keyPrefix-set-settings'),
      value: options.setSettings,
      title: l10n.setArchiveSetSettings,
      onChanged: (v) => changed(options.copyWith(setSettings: v)),
    ),
  if (available.attachments)
    ArchiveOptionTile(
      key: Key('$keyPrefix-attachments'),
      value: options.attachments,
      title: l10n.setArchiveAttachments,
      onChanged: (v) => changed(options.copyWith(attachments: v)),
    ),
  if (available.personal)
    ArchiveOptionTile(
      key: Key('$keyPrefix-personal'),
      value: options.personal,
      title: l10n.setArchivePersonal,
      subtitle: keyPrefix == 'set-export' ? l10n.setArchivePersonalHint : null,
      onChanged: (v) => changed(options.copyWith(personal: v)),
    ),
];

/// A compact checkbox row of an archive dialog, smaller than the headings.
class ArchiveOptionTile extends StatelessWidget {
  const ArchiveOptionTile({
    super.key,
    required this.value,
    required this.title,
    required this.onChanged,
    this.subtitle,
  });

  final bool value;
  final String title;
  final String? subtitle;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      dense: true,
      visualDensity: VisualDensity.compact,
      value: value,
      title: Text(title, style: theme.textTheme.bodyMedium),
      subtitle: subtitle == null ? null : Text(subtitle!),
      onChanged: onChanged,
    );
  }
}

/// A line of the song balance of an archive import, with an icon.
class ArchiveStatusRow extends StatelessWidget {
  const ArchiveStatusRow(
    this.icon,
    this.text, {
    super.key,
    this.color,
    this.details = const [],
  });

  final IconData icon;
  final String text;
  final Color? color;

  /// Song titles listed below the line.
  final List<String> details;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = this.color ?? theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: theme.textTheme.bodyMedium),
                for (final d in details)
                  Text(
                    d,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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

  /// "Gig (copy)", "Gig (copy 2)", … in the person's language (#719).
  String _copyName(String name, int number) {
    final l10n = AppLocalizations.of(context);
    return number == 1
        ? l10n.setImportCopyName(name)
        : l10n.setImportCopyNameNumbered(name, number);
  }

  Future<void> _load(String band) async {
    setState(() {
      _band = band;
      _preview = null;
    });
    final preview = await ref
        .read(setArchiveServiceProvider)
        .preview(
          widget.archive,
          bandId: band,
          canCreateSongs: _canCreateSongs,
          copyName: _copyName,
          canEditSong: ref.read(currentLibraryProvider).canEditSong,
        );
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
            copyName: _copyName,
            options: _options,
            duplicates: _duplicates,
            replace: preview.existingSet != null && _replace,
            overwriteArrangements: _overwrite,
            canEditSong: ref.read(currentLibraryProvider).canEditSong,
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
    final theme = Theme.of(context);
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
                archive.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                l10n.setImportFrom(
                  archive.bandName,
                  archive.contents.songs.length,
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              SectionHeader(
                l10n.setImportHeadingTarget,
                padding: SectionHeader.insetPadding,
              ),
              if (targets.isEmpty)
                Text(l10n.setImportNoBand)
              else
                DropdownButtonFormField<String>(
                  key: const Key('set-import-band'),
                  initialValue: _band,
                  decoration: InputDecoration(
                    labelText: l10n.setImportBand,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
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
                  child: LoadingIndicator(),
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
    final colors = Theme.of(context).colorScheme;
    final adding = preview.existingSet == null || !_replace;
    return [
      if (preview.existingSet case final existing?) ...[
        SectionHeader(
          l10n.setImportHeadingExisting,
          padding: SectionHeader.insetPadding,
        ),
        Text(l10n.setImportExisting(existing.name)),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<bool>(
            key: const Key('set-import-mode'),
            segments: [
              ButtonSegment(
                value: true,
                label: Text(
                  l10n.setImportReplace,
                  key: const Key('set-import-replace'),
                ),
              ),
              ButtonSegment(
                value: false,
                label: Text(
                  l10n.setImportCopy,
                  key: const Key('set-import-copy'),
                ),
              ),
            ],
            selected: {_replace},
            onSelectionChanged: (v) => setState(() => _replace = v.single),
          ),
        ),
      ],
      if (adding && preview.newName != widget.archive.name.trim())
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            l10n.setImportNewName(preview.newName),
            key: const Key('set-import-new-name'),
          ),
        ),
      SectionHeader(
        l10n.setImportHeadingSongs,
        padding: SectionHeader.insetPadding,
      ),
      if (preview.identical > 0)
        ArchiveStatusRow(
          Icons.check_circle_outline,
          l10n.setImportSongsHere(preview.identical),
          color: colors.primary,
        ),
      if (preview.added > 0)
        ArchiveStatusRow(
          Icons.add_circle_outline,
          l10n.setImportSongsNew(preview.added),
        ),
      if (preview.differing > 0) ...[
        ArchiveStatusRow(
          Icons.difference_outlined,
          l10n.setImportSongsDiffering(preview.differing),
        ),
        if (_canCreateSongs)
          Padding(
            padding: const EdgeInsets.only(left: 32, top: 4, bottom: 4),
            child: SegmentedButton<BackupDuplicates>(
              key: const Key('set-import-duplicates'),
              segments: [
                ButtonSegment(
                  value: BackupDuplicates.keepExisting,
                  label: Text(
                    l10n.setImportKeep,
                    key: const Key('set-import-keep-existing'),
                  ),
                ),
                ButtonSegment(
                  value: BackupDuplicates.addAll,
                  label: Text(
                    l10n.setImportAddAll,
                    key: const Key('set-import-add-all'),
                  ),
                ),
              ],
              selected: {_duplicates},
              onSelectionChanged: (v) => setState(() => _duplicates = v.single),
            ),
          ),
      ],
      if (_options.attachments && preview.attachmentsAdded > 0)
        ArchiveStatusRow(
          Icons.attach_file,
          l10n.archiveImportAttachmentsAdded(preview.attachmentsAdded),
        ),
      if (preview.missing.isNotEmpty)
        ArchiveStatusRow(
          Icons.warning_amber_outlined,
          l10n.setImportSongsMissing(preview.missing.length),
          color: colors.error,
          details: preview.missing,
        ),
      if (holds.arrangements ||
          holds.setSettings ||
          holds.attachments ||
          holds.personal) ...[
        SectionHeader(
          l10n.setImportHeadingInclude,
          padding: SectionHeader.insetPadding,
        ),
        ..._optionTiles(
          l10n,
          _options,
          (o) => setState(() => _options = o),
          keyPrefix: 'set-import',
          available: holds,
        ),
      ],
      if (_options.arrangements && preview.arrangementConflicts > 0)
        Padding(
          padding: const EdgeInsets.only(left: 32),
          child: ArchiveOptionTile(
            key: const Key('set-import-overwrite'),
            value: _overwrite,
            title: l10n.setImportOverwriteArrangements(
              preview.arrangementConflicts,
            ),
            onChanged: (v) => setState(() => _overwrite = v ?? false),
          ),
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
                  if (songs.completed > 0)
                    l10n.archiveResultCompleted(songs.completed),
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
                    onTap: () => context.push<void>(AppPaths.song(song.id)),
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
            final router = GoRouter.of(context);
            Navigator.pop(context);
            // The set belongs to the chosen band: switch to it first.
            if (band != null) {
              ref.read(selectedBandIdProvider.notifier).select(band);
            }
            router.push(AppPaths.set(result.setId));
          },
          child: Text(l10n.setImportOpen),
        ),
      ],
    );
  }
}

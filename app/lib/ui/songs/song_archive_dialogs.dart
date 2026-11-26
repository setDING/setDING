import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/backup.dart';
import '../../data/band_view.dart';
import '../../data/database.dart';
import '../../data/song_archive.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../providers.dart';
import '../../sync/sync_controller.dart' show attachmentFetcherProvider;
import '../sets/set_archive_dialogs.dart';
import '../widgets/dialogs.dart';
import '../widgets/export_file.dart';
import '../widgets/export_format.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/section_header.dart';
import '../routes.dart';

/// Exports [songIds]: as one ChordPro file (a single song, not on web) or
/// as a setDING archive with options (ADR-0043 §1c, issue #870).
Future<void> exportSongs(
  BuildContext context,
  WidgetRef ref,
  List<String> songIds,
) async {
  if (songIds.isEmpty) return;
  final db = ref.read(databaseProvider);
  final byId = {
    for (final s in await (db.select(
      db.songs,
    )..where((s) => s.id.isIn(songIds))).get())
      s.id: s,
  };
  final songs = [for (final id in songIds) ?byId[id]];
  if (songs.isEmpty || !context.mounted) return;
  final web = ref.read(webClientProvider);
  final formats = [
    // Web: no single file export (ADR-0018).
    if (songs.length == 1 &&
        songs.single.chordproSource.trim().isNotEmpty &&
        !web)
      ExportFormat.chordPro,
    ExportFormat.archive,
  ];
  // The arrangements are those of the current band, if the songs are in
  // its library.
  final band = ref.read(currentBandProvider);
  final arrangementsOf = band.libraryId == songs.first.libraryId ? band : null;
  final choice = await showDialog<(ExportFormat, SongArchiveOptions)>(
    context: context,
    builder: (_) => _ExportDialog(
      count: songs.length,
      band: arrangementsOf,
      formats: formats,
      initial: initialExportFormat(
        formats,
        ref.read(lastSongExportFormatProvider),
      ),
    ),
  );
  if (choice == null || !context.mounted) return;
  final (format, options) = choice;
  ref.read(lastSongExportFormatProvider.notifier).choose(format);
  if (format == ExportFormat.chordPro) {
    final service = ref.read(importExportProvider);
    final song = songs.single;
    await exportFile(
      context,
      ref,
      fileName: service.songFileName(song),
      mimeType: 'text/plain',
      build: () async => service.exportSong(song),
    );
    return;
  }
  final fetcher = ref.read(attachmentFetcherProvider);
  final service = ref.read(songArchiveServiceProvider);
  await exportFile(
    context,
    ref,
    fileName: SongArchiveService.fileName(songs),
    mimeType: 'application/zip',
    build: () => service.export(
      [for (final s in songs) s.id],
      options: options,
      bandId: arrangementsOf?.id,
      // The web client loads the files for the export (ADR-0018).
      readFile: web
          ? (AttachmentEntry a) async =>
                (await fetcher.fetch(a.id))?.readAsBytes()
          : null,
    ),
  );
}

/// The format and options of a song export.
class _ExportDialog extends StatefulWidget {
  const _ExportDialog({
    required this.count,
    required this.formats,
    required this.initial,
    this.band,
  });

  final int count;
  final List<ExportFormat> formats;
  final ExportFormat initial;

  /// The band whose arrangements may be exported.
  final BandView? band;

  @override
  State<_ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<_ExportDialog> {
  late var _format = widget.initial;
  var _options = const SongArchiveOptions();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final band = widget.band;
    final archive = _format == ExportFormat.archive;
    return AlertDialog(
      key: const Key('song-export'),
      title: Text(l10n.songExportTitle(widget.count)),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(archive ? l10n.songExportHint : l10n.songExportHintChordPro),
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
                ArchiveOptionTile(
                  key: const Key('song-export-attachments'),
                  value: _options.attachments,
                  title: l10n.setArchiveAttachments,
                  onChanged: (v) => setState(
                    () => _options = _options.copyWith(attachments: v),
                  ),
                ),
                if (band != null)
                  ArchiveOptionTile(
                    key: const Key('song-export-arrangements'),
                    value: _options.arrangements,
                    title: l10n.songExportArrangements(
                      band.isLocal ? l10n.bandLocal : band.name,
                    ),
                    onChanged: (v) => setState(
                      () => _options = _options.copyWith(arrangements: v),
                    ),
                  ),
                ArchiveOptionTile(
                  key: const Key('song-export-personal'),
                  value: _options.personal,
                  title: l10n.setArchivePersonal,
                  subtitle: l10n.setArchivePersonalHint,
                  onChanged: (v) =>
                      setState(() => _options = _options.copyWith(personal: v)),
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
          key: const Key('song-export-start'),
          onPressed: () => Navigator.pop(context, (_format, _options)),
          child: Text(l10n.setExportStart),
        ),
      ],
    );
  }
}

/// Imports the song archive [zip] (already read as [archive], if known)
/// into the current library: a preview first, then the report (ADR-0043
/// §1c).
Future<void> importSongArchive(
  BuildContext context,
  Uint8List zip, {
  SongArchive? archive,
}) async {
  final l10n = AppLocalizations.of(context);
  var read = archive;
  try {
    read ??= await SongArchiveService.read(zip);
  } on BackupFormatException {
    if (context.mounted) showMessage(context, l10n.songArchiveNewer);
    return;
  }
  if (read == null || !context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (_) => SongArchiveImportDialog(archive: read!),
  );
}

/// The preview and report of a song archive import.
class SongArchiveImportDialog extends ConsumerStatefulWidget {
  const SongArchiveImportDialog({super.key, required this.archive});

  final SongArchive archive;

  @override
  ConsumerState<SongArchiveImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends ConsumerState<SongArchiveImportDialog> {
  String? _band;
  SongArchivePreview? _preview;
  late SongArchiveOptions _options = widget.archive.holds;
  BackupDuplicates _duplicates = BackupDuplicates.keepExisting;
  bool _overwrite = false;
  bool _busy = false;
  bool _loading = false;
  SongArchiveResult? _result;

  LibraryView get _library => ref.read(currentLibraryProvider);

  /// Bands of the current library whose arrangements the person may change.
  List<BandView> _targets() {
    final library = ref.watch(currentLibraryProvider);
    final bands = ref.watch(bandsProvider).value ?? const <BandView>[];
    return [
      for (final b in bands)
        if (b.libraryId == library.id && b.canManageSets) b,
    ];
  }

  Future<void> _load(String? band) async {
    setState(() {
      _band = band;
      _loading = true;
    });
    final preview = await ref
        .read(songArchiveServiceProvider)
        .preview(
          widget.archive,
          libraryId: _library.id,
          canEditSong: _library.canEditSong,
          bandId: band,
        );
    if (mounted && _band == band) {
      setState(() {
        _preview = preview;
        _loading = false;
      });
    }
  }

  Future<void> _import() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      final result = await ref
          .read(songArchiveServiceProvider)
          .import(
            widget.archive,
            libraryId: _library.id,
            options: _options,
            duplicates: _duplicates,
            canEditSong: _library.canEditSong,
            bandId: _band,
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
    final archive = widget.archive;
    final holds = archive.holds;
    final targets = holds.arrangements ? _targets() : const <BandView>[];
    if (_preview == null && !_loading) {
      final preferred =
          targets
              .where((t) => t.id == ref.read(currentBandProvider).id)
              .firstOrNull ??
          targets.firstOrNull;
      // After this frame: _load calls setState.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _preview == null && !_loading) _load(preferred?.id);
      });
    }
    final preview = _preview;
    final library = ref.watch(currentLibraryProvider);
    final theme = Theme.of(context);
    return AlertDialog(
      key: const Key('song-import'),
      title: Text(l10n.songImportTitle),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final title in archive.titles.take(5))
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              if (archive.titles.length > 5) const Text('…'),
              Text(
                l10n.songImportFrom(
                  archive.libraryName.isEmpty
                      ? l10n.bandLocal
                      : archive.libraryName,
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
              Text(
                l10n.songImportLibrary(
                  library.isLocal ? l10n.bandLocal : library.name,
                ),
              ),
              if (preview == null)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: LoadingIndicator(),
                )
              else
                ..._previewParts(l10n, preview, targets),
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
          key: const Key('song-import-start'),
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

  List<Widget> _previewParts(
    AppLocalizations l10n,
    SongArchivePreview preview,
    List<BandView> targets,
  ) {
    final holds = widget.archive.holds;
    final colors = Theme.of(context).colorScheme;
    return [
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
        Padding(
          padding: const EdgeInsets.only(left: 32, top: 4, bottom: 4),
          child: SegmentedButton<BackupDuplicates>(
            key: const Key('song-import-duplicates'),
            segments: [
              ButtonSegment(
                value: BackupDuplicates.keepExisting,
                label: Text(l10n.setImportKeep),
              ),
              ButtonSegment(
                value: BackupDuplicates.addAll,
                label: Text(
                  l10n.setImportAddAll,
                  key: const Key('song-import-add-all'),
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
          color: colors.primary,
        ),
      if (holds.attachments || holds.arrangements || holds.personal) ...[
        SectionHeader(
          l10n.setImportHeadingInclude,
          padding: SectionHeader.insetPadding,
        ),
        if (holds.attachments)
          ArchiveOptionTile(
            key: const Key('song-import-attachments'),
            value: _options.attachments,
            title: l10n.setArchiveAttachments,
            onChanged: (v) =>
                setState(() => _options = _options.copyWith(attachments: v)),
          ),
        if (holds.arrangements && targets.isNotEmpty)
          ArchiveOptionTile(
            key: const Key('song-import-arrangements'),
            value: _options.arrangements,
            title: l10n.setArchiveArrangements,
            onChanged: (v) =>
                setState(() => _options = _options.copyWith(arrangements: v)),
          ),
        if (holds.personal)
          ArchiveOptionTile(
            key: const Key('song-import-personal'),
            value: _options.personal,
            title: l10n.setArchivePersonal,
            onChanged: (v) =>
                setState(() => _options = _options.copyWith(personal: v)),
          ),
      ],
      if (holds.arrangements && _options.arrangements) ...[
        if (targets.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(l10n.songImportNoBand),
          )
        else ...[
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            key: const Key('song-import-band'),
            initialValue: _band,
            decoration: InputDecoration(
              labelText: l10n.songImportArrangementsBand,
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
          if (preview.arrangementConflicts > 0)
            Padding(
              padding: const EdgeInsets.only(left: 32),
              child: ArchiveOptionTile(
                key: const Key('song-import-overwrite'),
                value: _overwrite,
                title: l10n.setImportOverwriteArrangements(
                  preview.arrangementConflicts,
                ),
                onChanged: (v) => setState(() => _overwrite = v ?? false),
              ),
            ),
        ],
      ],
    ];
  }

  Widget _report(BuildContext context, SongArchiveResult result) {
    final l10n = AppLocalizations.of(context);
    final songs = result.songs;
    return AlertDialog(
      key: const Key('song-import-result'),
      title: Text(l10n.songImportDone),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                [
                  l10n.backupResultSongs(songs.imported.length),
                  if (songs.identical > 0)
                    l10n.backupResultIdentical(songs.identical),
                  if (songs.keptExisting > 0)
                    l10n.backupResultKept(songs.keptExisting),
                  if (songs.files > 0) l10n.backupResultFiles(songs.files),
                  if (songs.completed > 0)
                    l10n.archiveResultCompleted(songs.completed),
                  if (result.arrangements > 0)
                    l10n.setImportResultArrangements(result.arrangements),
                ].join('\n'),
              ),
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
        FilledButton(
          key: const Key('song-import-close'),
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.close),
        ),
      ],
    );
  }
}

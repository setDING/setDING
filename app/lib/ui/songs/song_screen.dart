import 'dart:math' as math;

import 'package:chordpro/chordpro.dart' hide Key;
import 'package:chordpro/chordpro.dart' as cp show Key;
import 'package:drift/drift.dart' show Value;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../data/attachment_lookup.dart';
import '../../data/attachment_storage.dart';
import '../../data/database.dart';
import '../../data/song_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../providers.dart';
import '../../settings/settings.dart';
import '../live/live_screen.dart';
import '../render/chord_diagram.dart';
import '../render/render_cache.dart';
import '../render/song_header.dart';
import '../render/song_image.dart';
import '../render/song_view.dart';
import '../widgets/dialogs.dart';
import '../widgets/file_actions.dart';
import '../widgets/key_picker.dart';
import '../bands/copy_to_band.dart';
import '../../sync/sync_controller.dart';
import 'conflict_banner.dart';
import 'song_editor_screen.dart';

/// Shows a song with personal adjustments and its PDF attachments.
class SongScreen extends ConsumerStatefulWidget {
  const SongScreen({
    super.key,
    required this.songId,
    this.pickPdfOnOpen = false,
  });

  final String songId;
  final bool pickPdfOnOpen;

  @override
  ConsumerState<SongScreen> createState() => _SongScreenState();
}

class _SongScreenState extends ConsumerState<SongScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.pickPdfOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _addAttachment());
    }
  }

  SongRepository get _repo => ref.read(songRepositoryProvider);

  Future<void> _updateOverlay(SongOverlay Function(SongOverlay) change) async {
    final current = await _repo.getOverlay(widget.songId);
    await _repo.saveOverlay(change(current));
  }

  Future<void> _addAttachment() async {
    final l10n = AppLocalizations.of(context);
    final files = await pickFiles(extensions: ['pdf', ...imageExtensions]);
    for (final file in files) {
      if (file.bytes.length > maxAttachmentBytes) {
        if (mounted) showMessage(context, l10n.attachmentTooLarge);
        continue;
      }
      final extension = p.extension(file.name).replaceFirst('.', '');
      final pdf = isPdfFile(file.name);
      await _repo.addAttachment(
        widget.songId,
        // Images keep their file name so {image: src="…"} finds them.
        name: pdf ? p.basenameWithoutExtension(file.name) : file.name,
        bytes: file.bytes,
        pages: pdf ? await countPdfPages(file.bytes) : null,
        extension: extension,
      );
    }
  }

  Future<void> _editSource(SongEntry song) => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) =>
          SongEditorScreen(songId: song.id, initialSource: song.chordproSource),
    ),
  );

  Future<void> _editTitle(SongEntry song) async {
    final l10n = AppLocalizations.of(context);
    final title = await askText(
      context,
      title: l10n.editTitle,
      initial: song.title,
      label: l10n.title,
    );
    if (title == null || !mounted) return;
    final artist = await askText(
      context,
      title: l10n.artist,
      initial: song.artist ?? '',
      label: l10n.artist,
      allowEmpty: true,
    );
    await _repo.updateTitleArtist(song.id, title, artist ?? song.artist);
  }

  Future<void> _export(SongEntry song) async {
    final service = ref.read(importExportProvider);
    final l10n = AppLocalizations.of(context);
    final saved = await saveFile(
      service.songFileName(song),
      service.exportSong(song),
      mimeType: 'text/plain',
    );
    if (saved && mounted) showMessage(context, l10n.exported);
  }

  Future<void> _delete(SongEntry song) async {
    final l10n = AppLocalizations.of(context);
    final ok = await confirm(
      context,
      title: l10n.deleteSongTitle,
      message: l10n.deleteSongMessage(song.title),
    );
    if (!ok) return;
    await _repo.deleteSong(song.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final songValue = ref.watch(songProvider(widget.songId));
    final overlay =
        ref.watch(overlayProvider(widget.songId)).value ??
        SongRepository.defaultOverlay(widget.songId);
    final attachments =
        ref.watch(attachmentsProvider(widget.songId)).value ?? const [];
    final settings = ref.watch(settingsProvider);

    return AsyncBody(
      value: songValue,
      data: (song) {
        if (song == null) return const Scaffold();
        // Permissions of the song's library, wherever it was opened from.
        final library = ref.watch(libraryProvider(song.libraryId));
        final parsed = parseChordProCached(
          song.chordproSource,
          selectors: ref.watch(selectorsProvider),
        );
        final formatter = ChordFormatter.forSong(
          parsed,
          transpose: overlay.transpose,
          capo: overlay.capoFret,
          notation: settings.notation,
          nashville: overlay.nashville ?? settings.nashville,
        );
        final hasSourceTitle = parsed.title != null;

        return Scaffold(
          appBar: AppBar(
            title: Text(song.title.isEmpty ? l10n.untitled : song.title),
            actions: [
              IconButton(
                tooltip: l10n.playLive,
                icon: const Icon(Icons.play_arrow),
                onPressed: () => LiveScreen.openSong(context, song.id),
              ),
              if (library.canEditSongs) ...[
                // Same icon as "New PDF song" on the songs tab.
                IconButton(
                  key: const Key('song-add-attachment'),
                  tooltip: l10n.addAttachment,
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  onPressed: _addAttachment,
                ),
                IconButton(
                  tooltip: l10n.editSource,
                  icon: const Icon(Icons.edit_note),
                  onPressed: () => _editSource(song),
                ),
              ],
              PopupMenuButton<String>(
                onSelected: (value) => switch (value) {
                  'title' => _editTitle(song),
                  'export' => _export(song),
                  'copyToBand' => copySongsToBand(context, ref, [
                    song.id,
                  ], fromLibraryId: song.libraryId),
                  'delete' => _delete(song),
                  _ => null,
                },
                itemBuilder: (_) => [
                  if (!hasSourceTitle && library.canEditSongs)
                    PopupMenuItem(value: 'title', child: Text(l10n.editTitle)),
                  if (song.chordproSource.trim().isNotEmpty &&
                      !ref.read(webClientProvider))
                    PopupMenuItem(
                      value: 'export',
                      child: Text(l10n.exportSong),
                    ),
                  PopupMenuItem(
                    value: 'copyToBand',
                    child: Text(l10n.copyToBand),
                  ),
                  if (library.canDeleteSongs)
                    PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
                ],
              ),
            ],
          ),
          // The song is fitted to the visible area below the app bar; the
          // header and the adjustments scroll away above it.
          body: LayoutBuilder(
            builder: (context, constraints) => ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                if (ref.watch(songConflictProvider(song.id)).value
                    case final conflict?)
                  ConflictBanner(conflict: conflict),
                SongHeader(
                  title: song.title.isEmpty ? l10n.untitled : song.title,
                  artist: song.artist,
                  song: parsed,
                  formatter: formatter,
                  capo: formatter.effectiveCapo,
                ),
                const SizedBox(height: 12),
                _AdjustmentsBar(
                  songKey: parsed.key,
                  formatter: formatter,
                  songCapo: parsed.capoFret,
                  notation: settings.notation,
                  overlay: overlay,
                  deviceNashville: settings.nashville,
                  hasKey: parsed.key != null,
                  onChanged: _updateOverlay,
                ),
                if (attachments.isNotEmpty || !parsed.hasContent) ...[
                  const SizedBox(height: 12),
                  _AttachmentsCard(
                    attachments: attachments,
                    overlay: overlay,
                    hasChordPro: parsed.hasContent,
                    onAdd: library.canEditSongs ? _addAttachment : null,
                    canRename: library.canEditSongs,
                    canDelete: library.canDeleteSongs,
                    onLiveView: (id) =>
                        _updateOverlay((o) => o.copyWith(liveView: Value(id))),
                  ),
                ],
                const SizedBox(height: 16),
                if (parsed.hasContent)
                  _FittedSongBody(
                    song: parsed,
                    overlay: overlay,
                    formatter: formatter,
                    // The visible area without the list's padding.
                    page: Size(
                      constraints.maxWidth - 32,
                      constraints.maxHeight - 40,
                    ),
                    attachments: attachments,
                    imageLookup: (src) {
                      final image = imageAttachmentFor(attachments, src);
                      return image == null
                          ? null
                          : ref
                                .read(attachmentStorageProvider)
                                .file(image.fileName);
                    },
                  )
                else
                  Card.outlined(
                    child: ListTile(
                      leading: const Icon(Icons.text_snippet_outlined),
                      title: Text(l10n.noContent),
                      trailing: !library.canEditSongs
                          ? null
                          : FilledButton.tonal(
                              onPressed: () => _editSource(song),
                              child: Text(l10n.addChordPro),
                            ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Fits the song to [page] like live mode (ADR-0007): with automatic
/// fitting, font size and columns are chosen so that the whole song fits;
/// the personal font scale applies on top. When it does not fit (or without
/// automatic fitting) the song keeps the base font size and is split into as
/// many columns as needed, up to what the width allows, and scrolls.
class _FittedSongBody extends ConsumerWidget {
  const _FittedSongBody({
    required this.song,
    required this.overlay,
    required this.formatter,
    required this.page,
    required this.attachments,
    required this.imageLookup,
  });

  final Song song;
  final SongOverlay overlay;
  final ChordFormatter formatter;
  final Size page;
  final List<AttachmentEntry> attachments;
  final ImageLookup imageLookup;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final l10n = AppLocalizations.of(context);
    final lyricsOnly = settings.displayMode == DisplayMode.lyricsOnly;
    final resolver = DiagramResolver(
      song,
      formatter,
      diagramInstrumentFor(settings.instrument),
    );
    final diagrams = diagramsPosition(song.diagrams, settings.diagrams);
    final textScaler = MediaQuery.textScalerOf(context);
    final baseStyle = DefaultTextStyle.of(context).style;
    final scale = overlay.fontScale;
    // {columns} in the song wins over the automatic choice.
    final songColumns =
        settings.columns == ColumnMode.auto && song.columns != null
        ? song.columns!.clamp(1, 4)
        : null;
    final maxColumns = songColumns ?? settings.maxColumns;
    // By content: the list is loaded anew on every change.
    final key = (
      song,
      formatter.transpose,
      formatter.capo,
      formatter.notation,
      formatter.nashville,
      lyricsOnly,
      overlay.notes,
      diagrams,
      settings.instrument,
      textScaler,
      baseStyle,
      [for (final a in attachments) '${a.id}/${a.name}/${a.fileName}']
          .join('\n'),
      Localizations.localeOf(context),
    );

    SongRenderOptions options(
      double fontSize,
      int columns,
      bool collapse,
      SongLayout layout,
    ) => SongRenderOptions(
      formatter: formatter,
      lyricsOnly: lyricsOnly,
      fontSize: fontSize,
      columns: columns,
      notes: overlay.notes,
      collapseRecalls: collapse,
      diagramResolver: resolver,
      diagramsPosition: diagrams,
      imageLookup: imageLookup,
      layout: layout,
    );

    if (settings.autoFit && page.width > 0 && page.height > 0) {
      final fit = _fits.get(
        (
          key,
          settings.fontSize,
          songColumns,
          settings.maxColumns,
          settings.chorusRepeat,
          page,
        ),
        () => fitSong(
          song,
          formatter: formatter,
          lyricsOnly: lyricsOnly,
          labeler: sectionLabeler(l10n),
          notes: overlay.notes,
          baseFontSize: settings.fontSize,
          maxFontSize: settings.fontSize * 2,
          minFontSize: AppSettings.minFontSize,
          size: page,
          textScaler: textScaler,
          baseStyle: baseStyle,
          minColumns: songColumns ?? 1,
          maxColumns: maxColumns,
          chorusRepeat: settings.chorusRepeat,
          diagramResolver: resolver,
          diagramsPosition: diagrams,
          imageLookup: imageLookup,
        ),
      );
      if (fit.fits && fit.layout != null) {
        final layout = fit.layout!;
        final font = fit.fontSize * scale;
        // A larger personal scale may need fewer columns: chord lines must
        // fit (breaks in the song keep their columns).
        var columns = fit.columns;
        if (forcedColumns(layout.blocks) == null) {
          final widest = layout.metrics.fold<double>(
            0,
            (w, m) => math.max(w, m.minWidth),
          );
          while (columns > 1 &&
              columnWidth(page.width, columns, font) < widest * font) {
            columns--;
          }
        }
        return SongBody(
          song: song,
          options: options(font, columns, fit.collapseRecalls, layout),
        );
      }
    }

    // Does not fit (or no automatic fitting): base font size, columns.
    final collapse = settings.chorusRepeat == ChorusRepeat.label;
    final layout = _layouts.get(
      (key, collapse),
      () => layoutSong(
        song,
        formatter: formatter,
        lyricsOnly: lyricsOnly,
        labeler: sectionLabeler(l10n),
        notes: overlay.notes,
        collapseRecalls: collapse,
        diagramResolver: resolver,
        diagramsPosition: diagrams,
        textScaler: textScaler,
        baseStyle: baseStyle,
        imageLookup: imageLookup,
      ),
    );
    final font = settings.fontSize * scale;
    return SongBody(
      song: song,
      options: options(
        font,
        scrollColumns(
          layout,
          fontSize: font,
          size: page,
          maxColumns: maxColumns,
        ),
        collapse,
        layout,
      ),
    );
  }
}

/// Results of [fitSong] for the song screen.
final _fits = LruCache<Object, SongFit>(8);

/// Measured songs for the song screen when they do not fit.
final _layouts = LruCache<Object, SongLayout>(8);

/// Transposition, capo, font size, Nashville and notes (layer 3, ADR-0006).
class _AdjustmentsBar extends StatelessWidget {
  const _AdjustmentsBar({
    required this.songKey,
    required this.formatter,
    required this.songCapo,
    required this.notation,
    required this.overlay,
    required this.deviceNashville,
    required this.hasKey,
    required this.onChanged,
  });

  final cp.Key? songKey;

  /// Formatter of the song view; the capo menu previews the header with it.
  final ChordFormatter formatter;

  /// `{capo}` of the song (0 if none).
  final int songCapo;
  final ChordNotation notation;
  final SongOverlay overlay;
  final bool deviceNashville;
  final bool hasKey;
  final Future<void> Function(SongOverlay Function(SongOverlay)) onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final changed =
        overlay.transpose != 0 ||
        overlay.capoFret != null ||
        overlay.fontScale != 1.0 ||
        overlay.nashville != null;
    // A capo menu entry followed by the header it leads to, e.g.
    // "No capo – Key: D" (only with a key).
    String withHeader(String label, int? capo, int fret) => hasKey
        ? '$label – ${keyAndCapoText(l10n, formatter.withCapo(capo), fret)}'
        : label;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        KeyPicker(
          baseKey: songKey,
          transpose: overlay.transpose,
          notation: notation,
          onChanged: (value) => onChanged((o) => o.copyWith(transpose: value)),
        ),
        MenuAnchor(
          builder: (context, controller, _) => ActionChip(
            avatar: const Icon(Icons.straighten, size: 18),
            label: Text(switch (overlay.capoFret) {
              null when songCapo > 0 => l10n.capoAsInSong(songCapo),
              null || 0 => l10n.noCapo,
              final fret => l10n.capoValue(fret),
            }),
            onPressed: () =>
                controller.isOpen ? controller.close() : controller.open(),
          ),
          menuChildren: [
            // null = as written in the song ({capo}), 0 = explicitly none.
            if (songCapo > 0)
              MenuItemButton(
                onPressed: () =>
                    onChanged((o) => o.copyWith(capoFret: const Value(null))),
                child: Text(
                  withHeader(l10n.capoAsInSong(songCapo), null, songCapo),
                ),
              ),
            for (var fret = 0; fret <= 9; fret++)
              MenuItemButton(
                onPressed: () => onChanged(
                  (o) => o.copyWith(
                    capoFret: Value(fret == 0 && songCapo == 0 ? null : fret),
                  ),
                ),
                child: Text(
                  fret == 0
                      ? withHeader(l10n.noCapo, 0, 0)
                      : hasKey
                      // What the header shows with this capo.
                      ? keyAndCapoText(l10n, formatter.withCapo(fret), fret)
                      : l10n.capoValue(fret),
                ),
              ),
          ],
        ),
        _Stepper(
          icon: Icons.format_size,
          label: '${(overlay.fontScale * 100).round()} %',
          downTooltip: l10n.fontSmaller,
          upTooltip: l10n.fontLarger,
          onDown: () => onChanged(
            (o) => o.copyWith(fontScale: (o.fontScale - 0.1).clamp(0.5, 2.5)),
          ),
          onUp: () => onChanged(
            (o) => o.copyWith(fontScale: (o.fontScale + 0.1).clamp(0.5, 2.5)),
          ),
        ),
        Tooltip(
          message: hasKey ? '' : l10n.noKeyForNashville,
          child: FilterChip(
            label: Text(l10n.nashville),
            selected: overlay.nashville ?? deviceNashville,
            onSelected: hasKey
                ? (selected) => onChanged(
                    (o) => o.copyWith(
                      nashville: Value(
                        selected == deviceNashville ? null : selected,
                      ),
                    ),
                  )
                : null,
          ),
        ),
        ActionChip(
          avatar: const Icon(Icons.sticky_note_2_outlined, size: 18),
          label: Text(l10n.notes),
          onPressed: () async {
            final text = await askText(
              context,
              title: l10n.notes,
              initial: overlay.notes ?? '',
              hint: l10n.notesHint,
              multiline: true,
              allowEmpty: true,
            );
            if (text != null) {
              await onChanged(
                (o) => o.copyWith(notes: Value(text.isEmpty ? null : text)),
              );
            }
          },
        ),
        if (changed)
          IconButton(
            tooltip: l10n.resetAdjustments,
            icon: const Icon(Icons.restart_alt),
            onPressed: () => onChanged(
              (o) => o.copyWith(
                transpose: 0,
                capoFret: const Value(null),
                fontScale: 1.0,
                nashville: const Value(null),
              ),
            ),
          ),
      ],
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.icon,
    required this.label,
    required this.downTooltip,
    required this.upTooltip,
    required this.onDown,
    required this.onUp,
  });

  final IconData icon;
  final String label;
  final String downTooltip;
  final String upTooltip;
  final VoidCallback onDown;
  final VoidCallback onUp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: downTooltip,
            icon: const Icon(Icons.remove),
            onPressed: onDown,
          ),
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(label, style: theme.textTheme.labelLarge),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: upTooltip,
            icon: const Icon(Icons.add),
            onPressed: onUp,
          ),
        ],
      ),
    );
  }
}

class _AttachmentsCard extends ConsumerWidget {
  const _AttachmentsCard({
    required this.attachments,
    required this.overlay,
    required this.hasChordPro,
    required this.onAdd,
    required this.onLiveView,
    this.canRename = true,
    this.canDelete = true,
  });

  final List<AttachmentEntry> attachments;
  final SongOverlay overlay;
  final bool hasChordPro;

  /// Null hides the "add" button (no permission, ADR-0005).
  final VoidCallback? onAdd;
  final bool canRename;
  final bool canDelete;
  final void Function(String? attachmentId) onLiveView;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final repo = ref.read(songRepositoryProvider);
    final pdfs = [
      for (final a in attachments)
        if (isPdfFile(a.fileName)) a,
    ];
    final images = [
      for (final a in attachments)
        if (!isPdfFile(a.fileName)) a,
    ];
    final selected =
        overlay.liveView ?? (hasChordPro ? null : pdfs.firstOrNull?.id);

    return Card.outlined(
      child: RadioGroup<String?>(
        groupValue: selected,
        onChanged: onLiveView,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              title: Text(
                l10n.attachments,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              subtitle: pdfs.length > 1 || (hasChordPro && pdfs.isNotEmpty)
                  ? Text(l10n.liveView)
                  : null,
              trailing: onAdd == null
                  ? null
                  : TextButton.icon(
                      onPressed: onAdd,
                      icon: const Icon(Icons.add),
                      label: Text(l10n.addAttachment),
                    ),
            ),
            if (hasChordPro && pdfs.isNotEmpty)
              RadioListTile<String?>(
                value: null,
                title: Text(l10n.liveViewChordPro),
                secondary: const Icon(Icons.text_snippet_outlined),
              ),
            for (final a in pdfs)
              RadioListTile<String?>(
                value: a.id,
                title: Text(a.name),
                subtitle: Text(
                  [
                    if (a.pages != null) l10n.pagesCount(a.pages!),
                    formatBytes(a.sizeBytes),
                  ].join(' · '),
                ),
                secondary: _menu(context, repo, a),
              ),
            for (final a in images)
              ListTile(
                leading: const Icon(Icons.image_outlined),
                title: Text(a.name),
                subtitle: Text(formatBytes(a.sizeBytes)),
                trailing: _menu(context, repo, a),
              ),
          ],
        ),
      ),
    );
  }

  Widget? _menu(BuildContext context, SongRepository repo, AttachmentEntry a) {
    final l10n = AppLocalizations.of(context);
    if (!canRename && !canDelete) return null;
    return PopupMenuButton<String>(
      onSelected: (value) async {
        if (value == 'rename') {
          final name = await askText(
            context,
            title: l10n.rename,
            initial: a.name,
            label: l10n.attachmentName,
          );
          if (name != null) await repo.renameAttachment(a.id, name);
        } else if (value == 'delete') {
          final ok = await confirm(
            context,
            title: l10n.deleteAttachmentTitle,
            message: l10n.deleteAttachmentMessage(a.name),
          );
          if (ok) await repo.deleteAttachment(a);
        }
      },
      itemBuilder: (_) => [
        if (canRename) PopupMenuItem(value: 'rename', child: Text(l10n.rename)),
        if (canDelete) PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
      ],
    );
  }
}

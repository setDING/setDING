import 'package:chordpro/chordpro.dart' hide Key;
import 'package:chordpro/chordpro.dart' as cp show Key;
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
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
import '../render/song_header.dart';
import '../render/song_view.dart';
import '../widgets/dialogs.dart';
import '../widgets/file_actions.dart';
import '../widgets/key_picker.dart';
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
        final parsed = parseChordPro(
          song.chordproSource,
          selectors: settings.selectors,
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
              IconButton(
                tooltip: l10n.editSource,
                icon: const Icon(Icons.edit_note),
                onPressed: () => _editSource(song),
              ),
              PopupMenuButton<String>(
                onSelected: (value) => switch (value) {
                  'title' => _editTitle(song),
                  'pdf' => _addAttachment(),
                  'export' => _export(song),
                  'delete' => _delete(song),
                  _ => null,
                },
                itemBuilder: (_) => [
                  if (!hasSourceTitle)
                    PopupMenuItem(value: 'title', child: Text(l10n.editTitle)),
                  PopupMenuItem(value: 'pdf', child: Text(l10n.addAttachment)),
                  if (song.chordproSource.trim().isNotEmpty)
                    PopupMenuItem(
                      value: 'export',
                      child: Text(l10n.exportSong),
                    ),
                  PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
                ],
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
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
                  onAdd: _addAttachment,
                  onLiveView: (id) =>
                      _updateOverlay((o) => o.copyWith(liveView: Value(id))),
                ),
              ],
              const SizedBox(height: 16),
              if (parsed.hasContent)
                SongBody(
                  song: parsed,
                  options: SongRenderOptions(
                    formatter: formatter,
                    lyricsOnly: settings.displayMode == DisplayMode.lyricsOnly,
                    fontSize: settings.fontSize * overlay.fontScale,
                    notes: overlay.notes,
                    diagramResolver: DiagramResolver(
                      parsed,
                      formatter,
                      diagramInstrumentFor(settings.instrument),
                    ),
                    diagramsPosition: diagramsPosition(
                      parsed.diagrams,
                      settings.diagrams,
                    ),
                    imageLookup: (src) {
                      final image = imageAttachmentFor(attachments, src);
                      return image == null
                          ? null
                          : ref
                                .read(attachmentStorageProvider)
                                .file(image.fileName);
                    },
                  ),
                )
              else
                Card.outlined(
                  child: ListTile(
                    leading: const Icon(Icons.text_snippet_outlined),
                    title: Text(l10n.noContent),
                    trailing: FilledButton.tonal(
                      onPressed: () => _editSource(song),
                      child: Text(l10n.addChordPro),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Transposition, capo, font size, Nashville and notes (layer 3, ADR-0006).
class _AdjustmentsBar extends StatelessWidget {
  const _AdjustmentsBar({
    required this.songKey,
    required this.songCapo,
    required this.notation,
    required this.overlay,
    required this.deviceNashville,
    required this.hasKey,
    required this.onChanged,
  });

  final cp.Key? songKey;

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
                child: Text(l10n.capoAsInSong(songCapo)),
              ),
            for (var fret = 0; fret <= 9; fret++)
              MenuItemButton(
                onPressed: () => onChanged(
                  (o) => o.copyWith(
                    capoFret: Value(fret == 0 && songCapo == 0 ? null : fret),
                  ),
                ),
                child: Text(fret == 0 ? l10n.noCapo : l10n.capoValue(fret)),
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
  });

  final List<AttachmentEntry> attachments;
  final SongOverlay overlay;
  final bool hasChordPro;
  final VoidCallback onAdd;
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
              trailing: TextButton.icon(
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

  Widget _menu(BuildContext context, SongRepository repo, AttachmentEntry a) {
    final l10n = AppLocalizations.of(context);
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
        PopupMenuItem(value: 'rename', child: Text(l10n.rename)),
        PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
      ],
    );
  }
}

import 'dart:convert';

import 'package:chordpro/chordpro.dart' as cp;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/import_export.dart';
import '../../data/set_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../providers.dart';
import '../../settings/settings.dart';
import '../live/live_screen.dart';
import '../render/song_header.dart';
import '../songs/song_screen.dart';
import '../widgets/dialogs.dart';
import '../widgets/file_actions.dart';
import '../widgets/key_picker.dart';
import '../widgets/sequence_dialog.dart';
import 'set_list_pdf.dart';
import 'set_list_text.dart';
import 'sets_screen.dart';
import 'song_picker.dart';

/// A set with its ordered items.
class SetScreen extends ConsumerStatefulWidget {
  const SetScreen({super.key, required this.setId});

  final String setId;

  @override
  ConsumerState<SetScreen> createState() => _SetScreenState();
}

class _SetScreenState extends ConsumerState<SetScreen> {
  /// Local order while dragging, so the list does not jump back.
  List<SetItemView>? _pendingOrder;

  SetRepository get _repo => ref.read(setRepositoryProvider);

  Future<void> _addSongs() async {
    final ids = await pickSongs(context);
    if (ids.isNotEmpty) await _repo.addSongs(widget.setId, ids);
  }

  Future<void> _addMarker(SetItemType type) async {
    final l10n = AppLocalizations.of(context);
    final label = await askText(
      context,
      title: type == SetItemType.pause ? l10n.addPause : l10n.addText,
      initial: type == SetItemType.pause ? l10n.pause : '',
      hint: type == SetItemType.text ? l10n.textItemHint : null,
    );
    if (label != null) await _repo.addMarker(widget.setId, type, label);
  }

  Future<void> _export(SetlistEntry set) async {
    final l10n = AppLocalizations.of(context);
    final service = ref.read(importExportProvider);
    final bytes = await service.exportSet(set);
    final saved = await saveFile(
      service.setFileName(set),
      bytes,
      mimeType: 'application/zip',
    );
    if (saved && mounted) showMessage(context, l10n.exported);
  }

  /// The set list: one row per song with title, key and sequence.
  Future<SetList?> _setList(SetlistEntry set) async {
    final l10n = AppLocalizations.of(context);
    final items = await _repo.getItems(set.id);
    if (!mounted) return null;
    return buildSetList(
      set,
      items,
      notation: ref.read(settingsProvider).notation,
      formatDate: (date) => formatGigDate(context, date),
      untitled: l10n.untitled,
      songMissing: l10n.songMissing,
    );
  }

  Future<void> _exportSetList(SetlistEntry set) async {
    final l10n = AppLocalizations.of(context);
    final list = await _setList(set);
    if (list == null) return;
    final saved = await saveFile(
      '${safeFileName(set.name)}.txt',
      Uint8List.fromList(utf8.encode(setListText(list))),
      mimeType: 'text/plain',
    );
    if (saved && mounted) showMessage(context, l10n.exported);
  }

  Future<void> _copySetList(SetlistEntry set) async {
    final l10n = AppLocalizations.of(context);
    final list = await _setList(set);
    if (list == null) return;
    await Clipboard.setData(ClipboardData(text: setListText(list)));
    if (mounted) showMessage(context, l10n.setListCopied);
  }

  /// Printable set list as PDF (ADR-0013).
  Future<void> _exportSetListPdf(SetlistEntry set) async {
    final l10n = AppLocalizations.of(context);
    final list = await _setList(set);
    if (list == null) return;
    final pdf = await setListPdf(list, await SetListFonts.load());
    final saved = await saveFile(
      '${safeFileName(set.name)}.pdf',
      pdf.bytes,
      mimeType: 'application/pdf',
    );
    if (saved && mounted) showMessage(context, l10n.exported);
  }

  Future<void> _delete(SetlistEntry set) async {
    final l10n = AppLocalizations.of(context);
    final ok = await confirm(
      context,
      title: l10n.deleteSetTitle,
      message: l10n.deleteSetMessage(set.name),
    );
    if (!ok) return;
    await _repo.deleteSet(set.id);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _onReorder(
    List<SetItemView> items,
    int oldIndex,
    int newIndex,
  ) async {
    final list = [...items];
    list.insert(newIndex, list.removeAt(oldIndex));
    setState(() => _pendingOrder = list);
    await _repo.reorder(widget.setId, [for (final v in list) v.item.id]);
    if (mounted) setState(() => _pendingOrder = null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final setValue = ref.watch(setProvider(widget.setId));
    final itemsValue = ref.watch(setItemsProvider(widget.setId));
    final ready = ref.watch(offlineReadyProvider(widget.setId)).value;

    return AsyncBody(
      value: setValue,
      data: (set) {
        if (set == null) return const Scaffold();
        final items =
            _pendingOrder ?? itemsValue.value ?? const <SetItemView>[];
        final details = [
          if (set.gigDate != null) formatGigDate(context, set.gigDate!),
          if (set.venue != null) set.venue!,
        ].join(' · ');

        return Scaffold(
          appBar: AppBar(
            title: Text(set.name),
            actions: [
              IconButton(
                tooltip: l10n.playLive,
                icon: const Icon(Icons.play_arrow),
                onPressed: items.isEmpty
                    ? null
                    : () => LiveScreen.openSet(context, set.id),
              ),
              PopupMenuButton<String>(
                onSelected: (value) => switch (value) {
                  'pause' => _addMarker(SetItemType.pause),
                  'text' => _addMarker(SetItemType.text),
                  'edit' => showSetDialog(context, ref, existing: set),
                  'export' => _export(set),
                  'exportList' => _exportSetList(set),
                  'exportListPdf' => _exportSetListPdf(set),
                  'copyList' => _copySetList(set),
                  'delete' => _delete(set),
                  _ => null,
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'pause', child: Text(l10n.addPause)),
                  PopupMenuItem(value: 'text', child: Text(l10n.addText)),
                  PopupMenuItem(value: 'edit', child: Text(l10n.editSet)),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'copyList',
                    child: Text(l10n.copySetList),
                  ),
                  PopupMenuItem(
                    value: 'exportListPdf',
                    child: Text(l10n.exportSetListPdf),
                  ),
                  PopupMenuItem(
                    value: 'exportList',
                    child: Text(l10n.exportSetList),
                  ),
                  PopupMenuItem(value: 'export', child: Text(l10n.exportSet)),
                  const PopupMenuDivider(),
                  PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
                ],
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            heroTag: null,
            onPressed: _addSongs,
            icon: const Icon(Icons.playlist_add),
            label: Text(l10n.addSongs),
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Wrap(
                  spacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (details.isNotEmpty)
                      Text(
                        details,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    if (ready != null) OfflineBadge(ready: ready),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: items.isEmpty
                    ? EmptyState(
                        icon: Icons.playlist_add,
                        message: l10n.setEmpty,
                      )
                    : ReorderableListView.builder(
                        buildDefaultDragHandles: false,
                        padding: const EdgeInsets.only(bottom: 88),
                        itemCount: items.length,
                        onReorderItem: (o, n) => _onReorder(items, o, n),
                        itemBuilder: (context, i) => _SetItemTile(
                          key: ValueKey(items[i].item.id),
                          index: i,
                          view: items[i],
                          setId: widget.setId,
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

class _SetItemTile extends ConsumerWidget {
  const _SetItemTile({
    super.key,
    required this.index,
    required this.view,
    required this.setId,
  });

  final int index;
  final SetItemView view;
  final String setId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final repo = ref.read(setRepositoryProvider);
    final item = view.item;
    final song = view.song;
    final theme = Theme.of(context);
    final handle = ReorderableDragStartListener(
      index: index,
      child: const Padding(
        padding: EdgeInsets.all(8),
        child: Icon(Icons.drag_handle),
      ),
    );

    if (item.type != SetItemType.song) {
      return ListTile(
        leading: SizedBox(
          width: 32,
          child: Center(
            child: Text('${index + 1}', style: theme.textTheme.titleMedium),
          ),
        ),
        title: Text(
          item.note ?? '',
          style: theme.textTheme.titleMedium?.copyWith(
            fontStyle: FontStyle.italic,
            color: theme.colorScheme.secondary,
          ),
        ),
        subtitle: Text(
          item.type == SetItemType.pause ? l10n.pause : l10n.textItem,
        ),
        onTap: () async {
          final label = await askText(
            context,
            title: l10n.edit,
            initial: item.note ?? '',
          );
          if (label != null) await repo.updateMarker(item.id, label);
        },
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: l10n.removeFromSet,
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: () => repo.removeItem(setId, item.id),
            ),
            handle,
          ],
        ),
      );
    }

    final settings = ref.watch(settingsProvider);
    final originalSequence = song == null
        ? null
        : cp.findSequence(song.chordproSource);
    final sequence = item.sequence ?? originalSequence;
    final songKey = song?.songKey == null
        ? null
        : cp.Key.tryParse(song!.songKey!);

    return ListTile(
      leading: SizedBox(
        width: 32,
        child: Center(
          child: Text('${index + 1}', style: theme.textTheme.titleMedium),
        ),
      ),
      title: Text(
        song == null
            ? l10n.songMissing
            : (song.title.isEmpty ? l10n.untitled : song.title),
      ),
      subtitle: switch ((song?.artist, sequence)) {
        (null, null) => null,
        (final artist, final sequence) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ?artist == null ? null : Text(artist),
            if (sequence != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: SongSequenceView(
                  cp.parseSequence(sequence),
                  compact: true,
                  fromSet: item.sequence != null,
                ),
              ),
          ],
        ),
      },
      onTap: song == null
          ? null
          : () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => SongScreen(songId: song.id),
              ),
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (song != null)
            KeyPicker(
              dense: true,
              baseKey: songKey,
              transpose: item.transpose,
              notation: settings.notation,
              onChanged: (value) => repo.setItemTranspose(item.id, value),
            ),
          if (song != null)
            IconButton(
              tooltip: l10n.sequenceEdit,
              isSelected: item.sequence != null,
              icon: const Icon(Icons.format_list_numbered),
              selectedIcon: const Icon(Icons.playlist_play),
              onPressed: () async {
                final choice = await editSequence(
                  context,
                  title: l10n.sequenceEdit,
                  parts: cp.songParts(cp.parseChordPro(song.chordproSource)),
                  initial: sequence,
                  original: originalSequence,
                  showOriginal: true,
                  canRestore: item.sequence != null,
                );
                if (choice == null) return;
                // The song's own sequence is no set-specific one.
                final value = choice.value;
                await repo.setItemSequence(
                  item.id,
                  value == originalSequence?.trim() ? null : value,
                );
              },
            ),
          IconButton(
            tooltip: l10n.removeFromSet,
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: () => repo.removeItem(setId, item.id),
          ),
          handle,
        ],
      ),
    );
  }
}

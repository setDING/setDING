import 'dart:convert';

import 'package:chordpro/chordpro.dart' as cp;
import 'package:drift/drift.dart' show Value;
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/attachment_lookup.dart';
import '../../data/attachment_storage.dart';
import '../../data/database.dart';
import '../../data/import_export.dart';
import '../../data/set_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../providers.dart';
import '../../settings/settings.dart';
import '../live/live_screen.dart';
import '../render/render_cache.dart';
import '../render/song_header.dart';
import '../songs/song_screen.dart';
import '../bands/copy_to_band.dart';
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
    final arrangements = await ref
        .read(arrangementRepositoryProvider)
        .forBand(set.bandId);
    if (!mounted) return null;
    return buildSetList(
      set,
      items,
      arrangements: arrangements,
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
    final canEdit = ref.watch(currentBandProvider).canManageSets;

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
                  'copyToBand' => copySetToBand(context, ref, set.id),
                  'delete' => _delete(set),
                  _ => null,
                },
                itemBuilder: (_) => [
                  if (canEdit) ...[
                    PopupMenuItem(value: 'pause', child: Text(l10n.addPause)),
                    PopupMenuItem(value: 'text', child: Text(l10n.addText)),
                    PopupMenuItem(value: 'edit', child: Text(l10n.editSet)),
                    const PopupMenuDivider(),
                  ],
                  PopupMenuItem(
                    value: 'copyList',
                    child: Text(l10n.copySetList),
                  ),
                  // Web: no file export, sets are synced (ADR-0018).
                  if (!ref.read(webClientProvider)) ...[
                    PopupMenuItem(
                      value: 'exportListPdf',
                      child: Text(l10n.exportSetListPdf),
                    ),
                    PopupMenuItem(
                      value: 'exportList',
                      child: Text(l10n.exportSetList),
                    ),
                    PopupMenuItem(value: 'export', child: Text(l10n.exportSet)),
                  ],
                  PopupMenuItem(
                    value: 'copyToBand',
                    child: Text(l10n.copyToBand),
                  ),
                  if (canEdit) ...[
                    const PopupMenuDivider(),
                    PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
                  ],
                ],
              ),
            ],
          ),
          floatingActionButton: !canEdit
              ? null
              : FloatingActionButton.extended(
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
                          bandId: set.bandId,
                          canEdit: canEdit,
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
    required this.bandId,
    required this.canEdit,
  });

  final int index;
  final SetItemView view;
  final String setId;

  /// Band of the set, whose arrangements apply (ADR-0025).
  final String bandId;

  /// Edit, transpose, reorder and remove items (admins, ADR-0005).
  final bool canEdit;

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

    Future<void> remove() => repo.removeItem(setId, item.id);
    Future<void> editMarker() async {
      final label = await askText(
        context,
        title: l10n.edit,
        initial: item.note ?? '',
      );
      if (label != null) await repo.updateMarker(item.id, label);
    }

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
        onTap: !canEdit ? null : editMarker,
        trailing: !canEdit
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ItemMenu(
                    itemId: item.id,
                    entries: [
                      (l10n.edit, editMarker),
                      (l10n.removeFromSet, remove),
                    ],
                  ),
                  handle,
                ],
              ),
      );
    }

    final notation = ref.watch(settingsProvider.select((s) => s.notation));
    // The band's arrangement is the reference of the set (ADR-0025): its key
    // and sequence replace the song's, the set item comes on top.
    final band = song == null
        ? null
        : ref.watch(bandArrangementsProvider(bandId)).value?[song.id];
    final originalSequence = song == null
        ? null
        : band?.sequence ?? cp.findSequence(song.chordproSource);
    final sequence = item.sequence ?? originalSequence;
    final songKey = song?.songKey == null
        ? null
        : cp.Key.tryParse(song!.songKey!)?.transpose(band?.transpose ?? 0);
    final parsed = song == null
        ? null
        : parseChordProCached(
            song.chordproSource,
            selectors: ref.watch(selectorsProvider),
          );
    final hasChordPro = parsed?.hasContent ?? false;

    Future<void> changeSequence() async {
      final choice = await editSequence(
        context,
        title: l10n.sequenceEdit,
        parts: cp.songParts(parsed!),
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
    }

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
                  fromBand: item.sequence == null && band?.sequence != null,
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
      // Fixed slots, so the controls line up from row to row.
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 48,
            child: song == null
                ? null
                : _LiveViewButton(song: song, hasChordPro: hasChordPro),
          ),
          SizedBox(
            width: 72,
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              // Transposing a PDF does nothing.
              child: song == null || !hasChordPro
                  ? null
                  : canEdit
                  ? KeyPicker(
                      dense: true,
                      baseKey: songKey,
                      transpose: item.transpose,
                      notation: notation,
                      tooltip: l10n.keyPickerSet,
                      onChanged: (value) =>
                          repo.setItemTranspose(item.id, value),
                    )
                  : _readOnlyKey(context, songKey, item.transpose, notation),
            ),
          ),
          if (canEdit) ...[
            _ItemMenu(
              itemId: item.id,
              entries: [
                if (song != null && hasChordPro)
                  (l10n.sequenceEdit, changeSequence),
                (l10n.removeFromSet, remove),
              ],
            ),
            handle,
          ],
        ],
      ),
    );
  }
}

/// The ⋮ menu of a set item with the actions that are not needed often.
class _ItemMenu extends StatelessWidget {
  const _ItemMenu({required this.itemId, required this.entries});

  final String itemId;
  final List<(String, Future<void> Function())> entries;

  @override
  Widget build(BuildContext context) => PopupMenuButton<int>(
    key: ValueKey('set-item-menu-$itemId'),
    onSelected: (i) => entries[i].$2(),
    itemBuilder: (_) => [
      for (final (i, (label, _)) in entries.indexed)
        PopupMenuItem(value: i, child: Text(label)),
    ],
  );
}

/// What the current user sees for [song] in live mode: its ChordPro text or
/// one of its PDF attachments, switchable right in the set (ADR-0020).
///
/// A small icon shows the current choice (text or PDF) and opens a menu with
/// all of them. The choice is the personal `liveView` adjustment of the
/// song, so it is the same in every set and synced with the account; it is
/// not stored on the set item. Shown only when there is a choice.
class _LiveViewButton extends ConsumerWidget {
  const _LiveViewButton({required this.song, required this.hasChordPro});

  final SongEntry song;
  final bool hasChordPro;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final attachments =
        ref.watch(attachmentsProvider(song.id)).value ??
        const <AttachmentEntry>[];
    final pdfs = [
      for (final a in attachments)
        if (isPdfFile(a.fileName)) a,
    ];
    // No PDF, or a single PDF without ChordPro text: no choice.
    if (pdfs.isEmpty || (!hasChordPro && pdfs.length < 2)) {
      return const SizedBox.shrink();
    }
    final overlay = ref.watch(overlayProvider(song.id)).value;
    final selected = livePdfFor(
      attachments,
      overlay?.liveView,
      hasChordPro: hasChordPro,
    );

    void choose(String? attachmentId) => ref
        .read(songRepositoryProvider)
        .updateOverlay(
          song.id,
          (o) => o.copyWith(liveView: Value(attachmentId)),
        );

    Widget entry(String? id, IconData icon, String name) => MenuItemButton(
      key: ValueKey('live-view-option-${id ?? 'chordpro'}'),
      leadingIcon: Icon(icon),
      trailingIcon: selected?.id == id ? const Icon(Icons.check) : null,
      onPressed: () => choose(id),
      child: Text(name),
    );

    return MenuAnchor(
      menuChildren: [
        // The heading tells what the choice is for, also on touch devices.
        MenuItemButton(
          onPressed: null,
          child: Text(
            l10n.liveView,
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
        if (hasChordPro)
          entry(null, Icons.text_snippet_outlined, l10n.liveViewChordPro),
        for (final a in pdfs)
          entry(a.id, Icons.picture_as_pdf_outlined, a.name),
      ],
      builder: (context, controller, _) => IconButton(
        key: ValueKey('live-view-${song.id}'),
        tooltip:
            '${l10n.liveView}: ${selected?.name ?? l10n.liveViewChordPro}\n'
            '${l10n.scopePersonal}',
        icon: Icon(
          selected == null
              ? Icons.text_snippet_outlined
              : Icons.picture_as_pdf_outlined,
        ),
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}

/// The key of a set item for users who may not change it (members).
Widget? _readOnlyKey(
  BuildContext context,
  cp.Key? songKey,
  int transpose,
  cp.ChordNotation notation,
) {
  if (songKey == null && transpose == 0) return null;
  final theme = Theme.of(context);
  final label = songKey == null
      ? formatSemitones(transpose)
      : songKey.transpose(transpose).format(notation);
  return Text(
    label,
    style: theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w600,
      color: transpose == 0 ? null : theme.colorScheme.primary,
    ),
  );
}

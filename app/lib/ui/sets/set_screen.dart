import 'package:chordpro/chordpro.dart' as cp;
import 'package:drift/drift.dart' show Value;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../sync_hints.dart';
import '../../data/attachment_lookup.dart';
import '../../data/attachment_storage.dart';
import '../../data/database.dart';
import '../../data/marker_icons.dart';
import '../../data/import_export.dart';
import '../../data/set_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../providers.dart';
import '../../settings/settings.dart';
import '../live/live_play_button.dart';
import '../live/live_screen.dart';
import '../render/render_cache.dart';
import '../render/song_header.dart';
import '../songs/chordpro_problems_badge.dart';
import '../songs/play_history_panel.dart' show keyHistoryHint;
import '../songs/song_screen.dart';
import '../bands/copy_to_band.dart';
import '../widgets/dialogs.dart';
import '../widgets/export_file.dart';
import '../widgets/key_picker.dart';
import '../widgets/sequence_dialog.dart';
import 'set_list_pdf.dart';
import '../widgets/app_shortcuts.dart';
import 'set_archive_dialogs.dart';
import 'marker_dialog.dart';
import 'set_item_label.dart';
import 'set_list.dart';
import 'sets_screen.dart';
import 'song_picker.dart';

/// A set with its ordered items.
class SetScreen extends ConsumerStatefulWidget {
  const SetScreen({super.key, required this.setId, this.embedded = false});

  final String setId;

  /// Shown next to the list of sets on wide screens (#266) instead of as a
  /// page of its own: no back button, and deleting the set does not leave
  /// the page.
  final bool embedded;

  @override
  ConsumerState<SetScreen> createState() => _SetScreenState();
}

class _SetScreenState extends ConsumerState<SetScreen> {
  /// Local order while dragging, so the list does not jump back.
  List<SetItemView>? _pendingOrder;

  SetRepository get _repo => ref.read(setRepositoryProvider);

  Future<void> _addSongs() async {
    final set = await _repo.getSet(widget.setId);
    if (!mounted) return;
    final ids = await pickSongs(context, bandId: set?.bandId);
    if (ids.isNotEmpty) await _repo.addSongs(widget.setId, ids);
  }

  /// Adds a marker with an icon and a text (ADR-0047).
  Future<void> _addMarker() async {
    final marker = await showMarkerDialog(context);
    if (marker != null) {
      await _repo.addMarker(widget.setId, marker.icon, marker.note);
    }
  }

  Future<void> _export(SetlistEntry set) => exportSetArchive(context, ref, set);

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
      markerName: (icon) => markerIconName(l10n, icon),
    );
  }

  /// Printable set list as PDF (ADR-0013).
  Future<void> _exportSetListPdf(SetlistEntry set) async {
    final list = await _setList(set);
    if (list == null || !mounted) return;
    await exportFile(
      context,
      ref,
      fileName: '${safeFileName(set.name)}.pdf',
      mimeType: 'application/pdf',
      openable: true,
      build: () async =>
          (await setListPdf(list, await SetListFonts.load())).bytes,
    );
  }

  Future<void> _delete(SetlistEntry set) async {
    final l10n = AppLocalizations.of(context);
    final ok = await confirm(
      context,
      title: l10n.deleteSetTitle,
      message: l10n.deleteSetMessage(set.name),
    );
    if (!ok || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final repo = _repo;
    final deleted = await repo.deleteSet(set.id);
    if (mounted && !widget.embedded) Navigator.pop(context);
    showUndo(
      messenger,
      l10n.setDeleted(set.name),
      undoLabel: l10n.undo,
      onUndo: () => repo.restoreSet(deleted),
    );
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
    // Someone else changed or deleted the set (#691); on wide screens the
    // deleted set stays in its pane, as after deleting it here.
    listenForSyncHints(
      context,
      ref,
      recordId: widget.setId,
      isSet: true,
      onDeleted: widget.embedded ? null : () => closeRoute(context),
    );
    final l10n = AppLocalizations.of(context);
    final setValue = ref.watch(setProvider(widget.setId));
    final itemsValue = ref.watch(setItemsProvider(widget.setId));
    final missing = ref.watch(offlineMissingProvider(widget.setId)).value ?? 0;
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
        // The set's songs in order, for ← and → in the song screen (#729).
        final songs = [
          for (final v in items)
            if (v.song case final song?) song.id,
        ];
        final songPlaces = <int>[];
        var place = 0;
        for (final v in items) {
          songPlaces.add(place);
          if (v.song != null) place++;
        }

        return PageShortcuts(
          bindings: {
            editShortcut: canEdit
                ? () => showSetDialog(context, ref, existing: set)
                : null,
            liveShortcut: items.isEmpty
                ? null
                : () => LiveScreen.openSet(context, set.id),
          },
          child: Scaffold(
            appBar: AppBar(
              automaticallyImplyLeading: !widget.embedded,
              title: Text(set.name),
              actions: [
                if (canEdit) ...[
                  // Editing is a key function: its own button rather than an
                  // overflow menu entry, like editing a song (#713).
                  IconButton(
                    key: const Key('edit-set'),
                    tooltip: l10n.editSet,
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => showSetDialog(context, ref, existing: set),
                  ),
                  const VerticalDivider(
                    key: Key('edit-set-divider'),
                    width: 16,
                    indent: 16,
                    endIndent: 16,
                  ),
                ],
                PopupMenuButton<String>(
                  onSelected: (value) => switch (value) {
                    'marker' => _addMarker(),
                    'export' => _export(set),
                    'exportListPdf' => _exportSetListPdf(set),
                    'copyToBand' => copySetToBand(context, ref, set.id),
                    'delete' => _delete(set),
                    _ => null,
                  },
                  itemBuilder: (_) => [
                    if (canEdit) ...[
                      PopupMenuItem(
                        value: 'marker',
                        child: Text(l10n.addMarker),
                      ),
                      const PopupMenuDivider(),
                    ],
                    // Web: no file export, sets are synced (ADR-0018).
                    if (!ref.read(webClientProvider)) ...[
                      PopupMenuItem(
                        value: 'exportListPdf',
                        child: Text(l10n.exportSetListPdf),
                      ),
                      PopupMenuItem(
                        value: 'export',
                        child: Text(l10n.exportSet),
                      ),
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
                LivePlayButton(
                  onPressed: items.isEmpty
                      ? null
                      : () => LiveScreen.openSet(context, set.id),
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
                if (details.isNotEmpty || missing > 0)
                  Padding(
                    // Right: in line with the drag handles of the rows.
                    padding: const EdgeInsets.fromLTRB(16, 4, 32, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            details,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ),
                        if (missing > 0) OfflineMissingBadge(missing: missing),
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
                            setSongs: songs,
                            songPlace: songPlaces[i],
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

class _SetItemTile extends ConsumerWidget {
  const _SetItemTile({
    super.key,
    required this.index,
    required this.view,
    required this.setId,
    required this.bandId,
    required this.canEdit,
    required this.setSongs,
    required this.songPlace,
  });

  final int index;
  final SetItemView view;

  /// The set's songs and this song's place among them (#729).
  final List<String> setSongs;
  final int songPlace;
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

    // Name of the item in the message after removing it.
    final itemName = switch (item.type) {
      SetItemType.song =>
        song == null
            ? l10n.songMissing
            : (song.title.isEmpty ? l10n.untitled : song.title),
      _ => markerTitle(l10n, item.icon, item.note),
    };
    Future<void> remove() async {
      final messenger = ScaffoldMessenger.of(context);
      final removed = await repo.removeItem(setId, item.id);
      if (removed == null) return;
      showUndo(
        messenger,
        l10n.setItemRemoved(itemName),
        undoLabel: l10n.undo,
        onUndo: () => repo.restoreItem(removed),
      );
    }

    Future<void> editMarker() async {
      final marker = await showMarkerDialog(
        context,
        icon: item.icon ?? MarkerIcons.defaultIcon,
        note: item.note,
      );
      if (marker != null) {
        await repo.updateMarker(item.id, marker.note, icon: marker.icon);
      }
    }

    if (item.type != SetItemType.song) {
      // The marker's icon and its title: its own text, otherwise the icon's
      // name (also a break still named "Pause" or "Break" from any UI
      // language), never both, as in live mode (#268, #289, ADR-0047).
      return ListTile(
        key: ValueKey('marker-${item.id}'),
        leading: SizedBox(
          width: 32,
          child: Center(
            child: Icon(
              markerIconData(item.icon),
              color: theme.colorScheme.secondary,
            ),
          ),
        ),
        title: Text(
          markerTitle(l10n, item.icon, item.note),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            fontStyle: FontStyle.italic,
            color: theme.colorScheme.secondary,
          ),
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
                      ('edit', l10n.edit, editMarker),
                      ('remove', l10n.removeFromSet, remove),
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
    // Who prepares the set or may fix the song sees its ChordPro problems
    // (#314).
    final showProblems =
        song != null &&
        song.chordproProblems > 0 &&
        (canEdit ||
            ref.watch(libraryProvider(song.libraryId)).canEditSong(song));

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
      title: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: song == null
                  ? l10n.songMissing
                  : (song.title.isEmpty ? l10n.untitled : song.title),
            ),
            if (showProblems)
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(start: 8),
                  child: ChordProProblemsBadge(
                    key: const ValueKey('set-item-problems'),
                    size: 20,
                    message: l10n.chordProProblemsTooltip(
                      song.chordproProblems,
                    ),
                  ),
                ),
              ),
          ],
        ),
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
                builder: (_) => SongScreen(
                  songId: song.id,
                  setSongs: setSongs,
                  setIndex: songPlace,
                ),
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
                      hint: keyHistoryHint(
                        l10n,
                        ref
                            .watch(
                              songPlaysProvider((band: bandId, song: song.id)),
                            )
                            .value,
                        notation: notation,
                        formatDate: (d) => formatGigDate(context, d),
                      ),
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
                  ('sequence', l10n.sequenceEdit, changeSequence),
                ('remove', l10n.removeFromSet, remove),
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
///
/// Each entry has an id for its key (`set-item-action-<id>`), a label and
/// its action.
class _ItemMenu extends StatelessWidget {
  const _ItemMenu({required this.itemId, required this.entries});

  final String itemId;
  final List<(String, String, Future<void> Function())> entries;

  @override
  Widget build(BuildContext context) => PopupMenuButton<int>(
    key: ValueKey('set-item-menu-$itemId'),
    onSelected: (i) => entries[i].$3(),
    itemBuilder: (_) => [
      for (final (i, (id, label, _)) in entries.indexed)
        PopupMenuItem(
          key: ValueKey('set-item-action-$id'),
          value: i,
          child: Text(label),
        ),
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

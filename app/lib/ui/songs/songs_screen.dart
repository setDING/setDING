import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/song_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../providers.dart';
import '../bands/copy_to_band.dart';
import '../bands/library_switcher.dart';
import '../widgets/dialogs.dart';
import 'import_dialog.dart';
import 'song_editor_screen.dart';
import 'song_screen.dart';

/// Delay before a changed search text is applied, so that typing does not
/// start a database query per keystroke.
const songSearchDelay = Duration(milliseconds: 250);

/// Song library with search, creation and import.
class SongsScreen extends ConsumerStatefulWidget {
  const SongsScreen({super.key});

  @override
  ConsumerState<SongsScreen> createState() => _SongsScreenState();
}

class _SongsScreenState extends ConsumerState<SongsScreen> {
  final _search = TextEditingController();
  String _query = '';
  Timer? _searchDebounce;

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(songSearchDelay, () {
      if (mounted) setState(() => _query = value);
    });
  }

  /// Selected tag filter, or null for all songs.
  String? _tag;

  /// Songs selected for copying, or null outside selection mode.
  Set<String>? _selected;

  void _toggle(String id) => setState(() {
    final selected = {...?_selected};
    if (!selected.remove(id)) selected.add(id);
    _selected = selected.isEmpty ? null : selected;
  });

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _newPdfSong() async {
    final l10n = AppLocalizations.of(context);
    final title = await askText(
      context,
      title: l10n.newPdfSong,
      label: l10n.title,
    );
    if (title == null || !mounted) return;
    final id = await ref.read(songRepositoryProvider).createSong(title: title);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => SongScreen(songId: id, pickPdfOnOpen: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final songs = ref.watch(songsProvider((query: _query, tag: _tag)));
    final counts = ref.watch(attachmentCountsProvider).value ?? const {};
    final library = ref.watch(currentLibraryProvider);
    final selected = _selected;
    // Leave selection mode when switching libraries.
    ref.listen(currentLibraryProvider, (previous, next) {
      if (previous?.id != next.id) setState(() => _selected = null);
    });

    return Scaffold(
      appBar: AppBar(
        leading: selected == null
            ? null
            : IconButton(
                tooltip: l10n.cancel,
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _selected = null),
              ),
        title: Text(
          selected == null
              ? l10n.navSongs
              : l10n.songsSelected(selected.length),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SearchBar(
              controller: _search,
              hintText: l10n.searchSongs,
              leading: const Icon(Icons.search),
              trailing: [
                if (_search.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchDebounce?.cancel();
                      _search.clear();
                      setState(() => _query = '');
                    },
                  ),
              ],
              onChanged: _onSearchChanged,
            ),
          ),
        ),
        actions: selected != null
            ? [
                IconButton(
                  tooltip: l10n.selectAll,
                  icon: const Icon(Icons.select_all),
                  onPressed: () => setState(
                    () => _selected = {
                      for (final s in songs.value ?? const <SongListEntry>[])
                        s.id,
                    },
                  ),
                ),
                IconButton(
                  key: const Key('songs-copy-to-band'),
                  tooltip: l10n.copyToBand,
                  icon: const Icon(Icons.drive_file_move_outline),
                  onPressed: () async {
                    await copySongsToBand(
                      context,
                      ref,
                      selected.toList(),
                      fromLibraryId: library.id,
                    );
                    if (mounted) setState(() => _selected = null);
                  },
                ),
              ]
            : [
                const LibrarySwitcher(),
                if (library.canCreateSongs) ...[
                  // Also on web: imported songs are synced (ADR-0018).
                  IconButton(
                    key: const Key('songs-import'),
                    tooltip: l10n.importFiles,
                    icon: const Icon(Icons.file_open_outlined),
                    onPressed: () => showImportDialog(context),
                  ),
                  IconButton(
                    tooltip: l10n.newPdfSong,
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    onPressed: _newPdfSong,
                  ),
                ],
                PopupMenuButton<String>(
                  key: const Key('songs-menu'),
                  onSelected: (_) => setState(() => _selected = {}),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'select',
                      child: Text(l10n.selectMode),
                    ),
                  ],
                ),
              ],
      ),
      floatingActionButton: !library.canCreateSongs || selected != null
          ? null
          : FloatingActionButton.extended(
              heroTag: null,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const SongEditorScreen(),
                ),
              ),
              icon: const Icon(Icons.add),
              label: Text(l10n.newSong),
            ),
      body: Column(
        children: [
          _TagFilter(
            selected: _tag,
            onSelected: (tag) => setState(() => _tag = tag),
          ),
          Expanded(
            child: AsyncBody(
              value: songs,
              data: (list) => list.isEmpty
                  ? EmptyState(
                      icon: Icons.library_music_outlined,
                      message: l10n.songsEmpty,
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 88),
                      itemCount: list.length,
                      itemBuilder: (context, i) => SongTile(
                        song: list[i],
                        hasAttachments: (counts[list[i].id] ?? 0) > 0,
                        leading: selected == null
                            ? null
                            : Checkbox(
                                value: selected.contains(list[i].id),
                                onChanged: (_) => _toggle(list[i].id),
                              ),
                        onLongPress: () => _toggle(list[i].id),
                        onTap: selected != null
                            ? () => _toggle(list[i].id)
                            : () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      SongScreen(songId: list[i].id),
                                ),
                              ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Filter chips for the tags used in the library (`{tag}`).
class _TagFilter extends ConsumerWidget {
  const _TagFilter({required this.selected, required this.onSelected});

  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final used = ref.watch(tagsProvider).value ?? const <String>[];
    // A selected tag stays visible (and can be deselected) even when no
    // song uses it any more, e.g. after deleting its last song.
    final tags = [
      ...used,
      if (selected case final tag? when !used.contains(tag)) tag,
    ];
    if (tags.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(l10n.allTags),
              selected: selected == null,
              onSelected: (_) => onSelected(null),
            ),
          ),
          for (final tag in tags)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                avatar: const Icon(Icons.sell_outlined, size: 16),
                label: Text(tag),
                selected: selected == tag,
                onSelected: (on) => onSelected(on ? tag : null),
              ),
            ),
        ],
      ),
    );
  }
}

/// List entry for a song.
class SongTile extends StatelessWidget {
  const SongTile({
    super.key,
    required this.song,
    this.hasAttachments = false,
    this.onTap,
    this.onLongPress,
    this.trailing,
    this.leading,
  });

  final SongListEntry song;
  final bool hasAttachments;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget? trailing;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final subtitle = [
      if (song.artist != null) song.artist!,
      if (song.songKey != null) song.songKey!,
      ...song.tagList.map((t) => '#$t'),
    ].join(' · ');
    return ListTile(
      leading: leading,
      title: Text(song.title.isEmpty ? l10n.untitled : song.title),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      trailing:
          trailing ??
          (hasAttachments
              ? Tooltip(
                  message: l10n.attachmentsTooltip,
                  child: const Icon(Icons.picture_as_pdf_outlined),
                )
              : null),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}

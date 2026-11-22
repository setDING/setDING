import 'dart:async';

import 'package:chordpro/chordpro.dart' as cp;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/play_history.dart' show staleBefore;
import '../../data/song_repository.dart';
import '../../data/set_repository.dart';
import '../../data/text.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../providers.dart';
import '../trash/trash_screen.dart';
import '../../settings/settings.dart';
import '../account/sync_refresh.dart';
import '../backup/backup_actions.dart';
import '../bands/copy_to_band.dart';
import '../bands/library_switcher.dart';
import '../render/song_header.dart';
import '../sets/sets_screen.dart' show formatGigDate;
import '../widgets/app_shortcuts.dart';
import '../widgets/breakpoint_builder.dart';
import '../widgets/dialogs.dart';
import 'chordpro_problems_badge.dart';
import 'import_dialog.dart';
import 'library_usage_screen.dart';
import 'song_archive_dialogs.dart';
import 'song_attention.dart';
import 'song_editor_screen.dart';
import 'song_language.dart';
import 'song_screen.dart';
import '../widgets/section_header.dart';
import '../widgets/menu_action.dart';

/// Delay before a changed search text is applied, so that typing does not
/// start a database query per keystroke.
const songSearchDelay = Duration(milliseconds: 250);

/// Songs of the list in the order [sort], with the hits of the search that
/// found them.
typedef _Results = ({
  List<SongListEntry> songs,
  Map<String, SearchHit> hits,
  SongSort sort,
});

/// Song library with search, creation and import.
class SongsScreen extends ConsumerStatefulWidget {
  const SongsScreen({super.key});

  @override
  ConsumerState<SongsScreen> createState() => _SongsScreenState();
}

class _SongsScreenState extends ConsumerState<SongsScreen> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  String _query = '';
  Timer? _searchDebounce;

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(songSearchDelay, () {
      if (mounted) setState(() => _query = value);
    });
  }

  /// Selected tags: songs with any of them (#816); empty for all songs.
  /// Replaced, never changed in place: [songsProvider] compares it by
  /// identity.
  Set<String> _tags = const {};

  /// Only songs the band never played, or has not played for a while
  /// (ADR-0046); null for all songs.
  PlayedFilter? _played;

  /// Only songs of this language (ADR-0053); null for all songs.
  String? _language;

  /// Songs selected for copying, or null outside selection mode.
  Set<String>? _selected;

  /// The songs last shown, with the hits of the same search. They stay while
  /// the results of a changed search, tag or order load, and are replaced
  /// once the songs and their hits are both there (#297): one rebuild of the
  /// list per search instead of a progress indicator, the songs and then
  /// their highlighting in separate frames.
  _Results? _shown;

  void _toggle(String id) => setState(() {
    final selected = {...?_selected};
    if (!selected.remove(id)) selected.add(id);
    _selected = selected.isEmpty ? null : selected;
  });

  /// Deletes the selected songs after a confirmation; they go to the trash
  /// (ADR-0043) and one undo restores all of them.
  Future<void> _deleteSelected(Set<String> ids) async {
    final l10n = AppLocalizations.of(context);
    final ok = await confirm(
      context,
      title: l10n.deleteSongsTitle(ids.length),
      message: l10n.deleteSongsMessage(ids.length),
    );
    if (!ok || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(songRepositoryProvider);
    final deleted = [for (final id in ids) await repo.deleteSong(id)];
    if (mounted) setState(() => _selected = null);
    showUndo(
      messenger,
      l10n.songsDeleted(deleted.length),
      undoLabel: l10n.undo,
      onUndo: () async {
        for (final song in deleted) {
          await repo.restoreSong(song);
        }
      },
      onGone: () async {
        for (final song in deleted) {
          await repo.purgeFiles(song.attachments);
        }
      },
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _search.dispose();
    _searchFocus.dispose();
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
    final songs = ref.watch(songsProvider((query: _query, tags: _tags)));
    final hits = ref.watch(searchHitsProvider(_query));
    final sort = ref.watch(songSortProvider);
    if (songs.hasValue && !songs.isLoading && !hits.isLoading) {
      _shown = (
        songs: songs.requireValue,
        hits: hits.value ?? const {},
        sort: sort,
      );
    }
    final AsyncValue<_Results> results = switch (_shown) {
      _ when songs.hasError && !songs.isLoading => AsyncError(
        songs.error!,
        songs.stackTrace ?? StackTrace.empty,
      ),
      final shown? => AsyncData(shown),
      null => const AsyncLoading(),
    };
    final counts = ref.watch(attachmentCountsProvider).value ?? const {};
    final library = ref.watch(currentLibraryProvider);
    final notation = ref.watch(settingsProvider.select((s) => s.notation));
    final band = ref.watch(arrangementBandProvider(library.id));
    final arrangements = band == null
        ? const <String, BandArrangement>{}
        : ref.watch(bandArrangementsProvider(band.id)).value ?? const {};
    final conflicts = ref.watch(conflictSongIdsProvider);
    // Only the songs of a line of the overview's To do card (ADR-0045).
    final attention = ref.watch(songAttentionFilterProvider);
    List<SongListEntry> visible(List<SongListEntry> songs) => attention == null
        ? songs
        : [
            for (final s in songs)
              if (needsAttention(
                attention,
                s,
                library: library,
                conflicts: conflicts,
              ))
                s,
          ];
    // The plays of the band that plays from this library (ADR-0046): the
    // band of the arrangements, or the local library's own sets.
    final current = ref.watch(currentBandProvider);
    final historyBand =
        band ??
        (current.isLocal && current.libraryId == library.id ? current : null);
    final lastPlayed = historyBand == null
        ? null
        : ref.watch(lastPlayedProvider(historyBand.id)).value ??
              const <String, DateTime>{};
    final byLastPlayed = sort == SongSort.lastPlayed && lastPlayed != null;
    final played = lastPlayed == null ? null : _played;
    // Language tags and the language filter only for a library with songs
    // in more than one language (ADR-0053).
    final languages =
        ref.watch(songLanguagesProvider).value ?? const <String>{};
    final mixedLanguages = languages.length > 1;
    final works = ref.watch(workCountsProvider).value ?? const <String, int>{};
    final language = _language;
    List<SongListEntry> shownSongs(List<SongListEntry> songs) {
      var list = visible(songs);
      if (language != null) {
        list = [
          for (final s in list)
            if (s.language == language) s,
        ];
      }
      if (played != null) {
        final before = staleBefore(
          DateTime.now(),
          historyBand!.staleAfterMonths,
        );
        list = [
          for (final s in list)
            if (switch (played) {
              PlayedFilter.never => !lastPlayed!.containsKey(s.id),
              PlayedFilter.stale =>
                lastPlayed![s.id]?.isBefore(before) ?? false,
            })
              s,
        ];
      }
      if (byLastPlayed) {
        // Stable: songs played on the same day, and those never played,
        // keep the order by title.
        final order = {for (final (i, s) in list.indexed) s.id: i};
        list = [...list]
          ..sort((a, b) {
            final x = lastPlayed[a.id], y = lastPlayed[b.id];
            final c = x == null
                ? (y == null ? 0 : 1)
                : (y == null ? -1 : y.compareTo(x));
            return c != 0 ? c : order[a.id]!.compareTo(order[b.id]!);
          });
      }
      return list;
    }

    final gigs = ref.watch(upcomingGigsProvider(library.id)).value ?? const {};
    final selected = _selected;
    // Leave selection mode when switching libraries.
    ref.listen(currentLibraryProvider, (previous, next) {
      if (previous?.id != next.id) setState(() => _selected = null);
    });

    return PageShortcuts(
      // / or Ctrl+F: search (#729); Esc closes the selection like the X
      // (#739), also from the search field.
      bindings: {
        for (final a in searchShortcuts) a: _searchFocus.requestFocus,
        closeSelectionShortcut: selected == null
            ? null
            : () => setState(() => _selected = null),
      },
      whileTyping: const {closeSelectionShortcut},
      child: Scaffold(
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
                focusNode: _searchFocus,
                hintText: l10n.searchSongs,
                leading: const Icon(Icons.search),
                trailing: [
                  if (_search.text.isNotEmpty)
                    IconButton(
                      tooltip: l10n.searchClear,
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
                        for (final s in shownSongs(
                          _shown?.songs ?? const <SongListEntry>[],
                        ))
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
                  IconButton(
                    key: const Key('songs-export-selected'),
                    tooltip: l10n.songsExportSelected,
                    icon: const Icon(Icons.ios_share),
                    onPressed: selected.isEmpty
                        ? null
                        : () async {
                            await exportSongArchive(
                              context,
                              ref,
                              selected.toList(),
                            );
                            if (mounted) setState(() => _selected = null);
                          },
                  ),
                  if (library.canDeleteSongs)
                    IconButton(
                      key: const Key('songs-delete-selected'),
                      tooltip: l10n.deleteSelected,
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _deleteSelected(selected),
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
                    onSelected: (value) => switch (value) {
                      'trash' => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              TrashScreen.songs(libraryId: library.id),
                        ),
                      ),
                      'backup' => exportBackup(context, ref, library),
                      'usage' => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => LibraryUsageScreen(library: library),
                        ),
                      ),
                      _ => setState(() => _selected = {}),
                    },
                    itemBuilder: (_) => [
                      MenuAction(
                        value: 'select',
                        icon: Icons.checklist,
                        label: l10n.selectMode,
                      ),
                      // ADR-0043: whoever may delete songs may restore them.
                      if (library.canDeleteSongs)
                        MenuAction(
                          key: const Key('songs-trash'),
                          value: 'trash',
                          icon: Icons.restore_from_trash_outlined,
                          label: l10n.trash,
                        ),
                      // ADR-0046: songs no band of the organization played,
                      // for those who maintain the library.
                      if (!library.isLocal && library.isLibrarian)
                        MenuAction(
                          key: const Key('songs-usage'),
                          value: 'usage',
                          icon: Icons.insights_outlined,
                          label: l10n.libraryUsage,
                        ),
                      // ADR-0043: the whole library as a backup archive.
                      if (library.canExportLibrary)
                        MenuAction(
                          key: const Key('songs-backup'),
                          value: 'backup',
                          icon: Icons.backup_outlined,
                          label: l10n.backupExport,
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
            _Filters(
              tags: _tags,
              onTags: (tags) => setState(() => _tags = tags),
              attention: attention,
              showPlayed: lastPlayed != null,
              played: played,
              onPlayed: (filter) => setState(() => _played = filter),
              languages: languages,
              language: language,
              onLanguage: (l) => setState(() => _language = l),
            ),
            Expanded(
              child: AsyncBody(
                value: results,
                data: (results) {
                  final (songs: all, :hits, :sort) = results;
                  final list = shownSongs(all);
                  if (list.isEmpty) {
                    return SyncRefresh(
                      scrollable: false,
                      child: EmptyState(
                        icon: Icons.library_music_outlined,
                        message:
                            (attention == null &&
                                    played == null &&
                                    language == null) ||
                                all.isEmpty
                            ? l10n.songsEmpty
                            : l10n.songsFilterEmpty,
                      ),
                    );
                  }
                  final sections = _sectionsOf(
                    list,
                    byLastPlayed ? SongSort.lastPlayed : sort,
                    notation,
                    l10n,
                  );
                  Widget tile(int i) => SongTile(
                    song: list[i],
                    hasAttachments: (counts[list[i].id] ?? 0) > 0,
                    arrangement: arrangements[list[i].id],
                    hasConflict: conflicts.contains(list[i].id),
                    showLanguage: mixedLanguages,
                    otherVersions: switch (list[i].workId) {
                      final w? => (works[w] ?? 1) - 1,
                      null => 0,
                    },
                    showProblems: library.canEditSongBy(
                      createdBy: list[i].createdBy,
                      updatedBy: list[i].updatedBy,
                    ),
                    onConvert: () => _convertSong(context, ref, list[i]),
                    nextGig: gigs[list[i].id],
                    hit: hits[list[i].id],
                    bandName: band?.name ?? '',
                    playedNote: !byLastPlayed
                        ? null
                        : switch (lastPlayed[list[i].id]) {
                            final date? => l10n.songLastPlayed(
                              formatGigDate(context, date),
                            ),
                            null => l10n.songNeverPlayed,
                          },
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
                              builder: (_) => SongScreen(songId: list[i].id),
                            ),
                          ),
                  );
                  return SyncRefresh(
                    child: BreakpointBuilder(
                      select: (constraints) =>
                          constraints.maxWidth >= songListTwoColumnWidth
                          ? 2
                          : 1,
                      builder: (context, columns) => _songList(
                        songListRows(sections, columns),
                        columns,
                        tile,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Section headers of the songs (see [songSection]), computed again only
  /// when the songs, their order, the notation or the language change.
  List<String?> _sectionsOf(
    List<SongListEntry> songs,
    SongSort sort,
    cp.ChordNotation notation,
    AppLocalizations l10n,
  ) {
    if (_sections case final c?
        when identical(c.songs, songs) &&
            c.sort == sort &&
            c.notation == notation &&
            identical(c.l10n, l10n)) {
      return c.sections;
    }
    final sections = [
      for (final song in songs)
        songSection(song, sort, notation: notation, l10n: l10n),
    ];
    _sections = (
      songs: songs,
      sort: sort,
      notation: notation,
      l10n: l10n,
      sections: sections,
    );
    return sections;
  }

  ({
    List<SongListEntry> songs,
    SongSort sort,
    cp.ChordNotation notation,
    AppLocalizations l10n,
    List<String?> sections,
  })?
  _sections;

  Widget _songList(
    List<SongListRow> rows,
    int columns,
    Widget Function(int song) tile,
  ) => ListView.builder(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.only(bottom: 88),
    itemCount: rows.length,
    itemBuilder: (context, r) {
      final row = rows[r];
      if (row.header case final header?) return SongSectionHeader(header);
      if (columns == 1) return tile(row.songs.single);
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var c = 0; c < columns; c++)
            Expanded(
              child: c < row.songs.length
                  ? tile(row.songs[c])
                  : const SizedBox.shrink(),
            ),
        ],
      );
    },
  );
}

/// Songs the band never played, or has not played for a while (ADR-0046).
enum PlayedFilter { never, stale }

/// Chips above the list: the order (a menu, see [SongSort]) and the
/// filters, among them the tags used in the library (`{tag}`, a menu with
/// several choices, #816) and, last, the band's plays (a menu).
class _Filters extends ConsumerWidget {
  const _Filters({
    required this.tags,
    required this.onTags,
    required this.attention,
    required this.showPlayed,
    required this.played,
    required this.onPlayed,
    required this.languages,
    required this.language,
    required this.onLanguage,
  });

  /// The selected tags; songs with any of them are shown.
  final Set<String> tags;
  final ValueChanged<Set<String>> onTags;

  /// Offer the order and filters by the band's plays (ADR-0046).
  final bool showPlayed;
  final PlayedFilter? played;
  final ValueChanged<PlayedFilter?> onPlayed;

  /// The languages of the library's songs and the one filtered by
  /// (ADR-0053); offered when the library has more than one.
  final Set<String> languages;
  final String? language;
  final ValueChanged<String?> onLanguage;

  /// The filter chosen on the overview (ADR-0045), shown first and
  /// removable.
  final SongAttention? attention;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final used = ref.watch(tagsProvider).value ?? const <String>[];
    final sort = ref.watch(songSortProvider);
    final counts = ref.watch(songAttentionCountsProvider);
    // A selected tag stays visible (and can be deselected) even when no
    // song uses it any more, e.g. after deleting its last song.
    final offered = [
      ...used,
      for (final t in tags)
        if (!used.contains(t)) t,
    ];
    final chosen = [
      for (final t in offered)
        if (tags.contains(t)) t,
    ];
    final orders = [
      (SongSort.title, l10n.sortByTitle),
      (SongSort.artist, l10n.sortByArtist),
      (SongSort.key, l10n.sortByKey),
      (SongSort.recent, l10n.sortByRecent),
      if (showPlayed) (SongSort.lastPlayed, l10n.sortByLastPlayed),
    ];
    // By title while no band's plays are at hand.
    final current =
        (orders.where((o) => o.$1 == sort).firstOrNull ?? orders.first).$2;
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        children: [
          // The filters of the overview's To do card (ADR-0045), for
          // the kinds with songs the person may edit, and the one chosen.
          for (final kind in SongAttention.values)
            if (kind == attention || (counts?[kind] ?? 0) > 0)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  key: ValueKey('songs-attention-${kind.name}'),
                  avatar: kind == attention
                      ? null
                      : songAttentionIcon(context, kind, size: 16),
                  label: Text(songAttentionLabel(l10n, kind)),
                  selected: kind == attention,
                  onSelected: (on) => ref
                      .read(songAttentionFilterProvider.notifier)
                      .select(on ? kind : null),
                ),
              ),
          if (attention == SongAttention.conversions)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                key: const Key('songs-convert-all'),
                avatar: const Icon(chordProConversionsIcon, size: 18),
                label: Text(l10n.convertAllSongs),
                onPressed: () => _convertAll(context, ref),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: MenuAnchor(
              menuChildren: [
                for (final (value, label) in orders)
                  MenuItemButton(
                    onPressed: () =>
                        ref.read(songSortProvider.notifier).select(value),
                    leadingIcon: value == sort
                        ? const Icon(Icons.check, size: 18)
                        : const SizedBox.square(dimension: 18),
                    child: Text(label),
                  ),
              ],
              builder: (context, menu, _) => Tooltip(
                message: l10n.sortSongs,
                child: ActionChip(
                  key: const Key('songs-sort'),
                  avatar: const Icon(Icons.sort, size: 18),
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(current),
                      const Icon(Icons.arrow_drop_down, size: 18),
                    ],
                  ),
                  onPressed: () => menu.isOpen ? menu.close() : menu.open(),
                ),
              ),
            ),
          ),
          if (languages.length > 1 || language != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: MenuAnchor(
                menuChildren: [
                  for (final l in [
                    null,
                    ...orderedSongLanguages({...languages, ?language}),
                  ])
                    MenuItemButton(
                      key: ValueKey('songs-language-${l ?? 'all'}'),
                      onPressed: () => onLanguage(l),
                      leadingIcon: l == language
                          ? const Icon(Icons.check, size: 18)
                          : const SizedBox.square(dimension: 18),
                      child: Text(
                        l == null
                            ? l10n.allLanguages
                            : songLanguageName(l10n, l),
                      ),
                    ),
                ],
                builder: (context, menu, _) => Tooltip(
                  message: l10n.filterByLanguage,
                  child: FilterChip(
                    key: const Key('songs-language'),
                    avatar: language == null
                        ? const Icon(Icons.translate, size: 16)
                        : null,
                    selected: language != null,
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          language == null
                              ? l10n.allLanguages
                              : songLanguageName(l10n, language!),
                        ),
                        const Icon(Icons.arrow_drop_down, size: 18),
                      ],
                    ),
                    onSelected: (_) => menu.isOpen ? menu.close() : menu.open(),
                  ),
                ),
              ),
            ),
          if (offered.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: MenuAnchor(
                menuChildren: [
                  MenuItemButton(
                    key: const Key('songs-tags-all'),
                    onPressed: () => onTags(const {}),
                    leadingIcon: tags.isEmpty
                        ? const Icon(Icons.check, size: 18)
                        : const SizedBox.square(dimension: 18),
                    child: Text(l10n.allTags),
                  ),
                  const Divider(height: 1),
                  // Several tags can be ticked: the menu stays open.
                  for (final t in offered)
                    CheckboxMenuButton(
                      key: ValueKey('songs-tag-$t'),
                      value: tags.contains(t),
                      closeOnActivate: false,
                      onChanged: (on) => onTags({
                        for (final s in tags)
                          if (s != t) s,
                        if (on ?? false) t,
                      }),
                      child: Text(t),
                    ),
                ],
                builder: (context, menu, _) => Tooltip(
                  message: l10n.filterByTags,
                  child: FilterChip(
                    key: const Key('songs-tags'),
                    avatar: chosen.isEmpty
                        ? const Icon(Icons.sell_outlined, size: 16)
                        : null,
                    selected: chosen.isNotEmpty,
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(switch (chosen) {
                          [] => l10n.tagsFilter,
                          [final t] => t,
                          [final t, ...] => l10n.tagsFilterMore(
                            t,
                            chosen.length - 1,
                          ),
                        }),
                        const Icon(Icons.arrow_drop_down, size: 18),
                      ],
                    ),
                    onSelected: (_) => menu.isOpen ? menu.close() : menu.open(),
                  ),
                ),
              ),
            ),
          if (showPlayed)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: MenuAnchor(
                menuChildren: [
                  for (final (filter, label) in [
                    (null, l10n.playedAll),
                    (PlayedFilter.never, l10n.repertoireNeverPlayed),
                    (PlayedFilter.stale, l10n.repertoireStale),
                  ]) ...[
                    MenuItemButton(
                      key: ValueKey('songs-played-${filter?.name ?? 'all'}'),
                      onPressed: () => onPlayed(filter),
                      leadingIcon: filter == played
                          ? const Icon(Icons.check, size: 18)
                          : const SizedBox.square(dimension: 18),
                      child: Text(label),
                    ),
                    if (filter == null) const Divider(height: 1),
                  ],
                ],
                builder: (context, menu, _) => Tooltip(
                  message: l10n.filterByPlayed,
                  child: FilterChip(
                    key: const Key('songs-played'),
                    avatar: played == null
                        ? const Icon(Icons.history, size: 16)
                        : null,
                    selected: played != null,
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(switch (played) {
                          null => l10n.playedFilter,
                          PlayedFilter.never => l10n.repertoireNeverPlayed,
                          PlayedFilter.stale => l10n.repertoireStale,
                        }),
                        const Icon(Icons.arrow_drop_down, size: 18),
                      ],
                    ),
                    onSelected: (_) => menu.isOpen ? menu.close() : menu.open(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Converts every song of the library the person may edit that has
/// possible conversions (#798), after asking: the songs are shared.
Future<void> _convertAll(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  // All songs of the library, also while a search narrows the list.
  final songs = await ref.read(songRepositoryProvider).watchSongList().first;
  if (!context.mounted) return;
  final library = ref.read(currentLibraryProvider);
  final conflicts = ref.read(conflictSongIdsProvider);
  final ids = [
    for (final s in songs)
      if (needsAttention(
        SongAttention.conversions,
        s,
        library: library,
        conflicts: conflicts,
      ))
        s.id,
  ];
  if (ids.isEmpty) return;
  final messenger = ScaffoldMessenger.of(context);
  if (!await confirm(
    context,
    title: l10n.convertAllSongsTitle,
    message: l10n.convertAllSongsMessage(ids.length),
    action: l10n.convert,
    destructive: false,
  )) {
    return;
  }
  final count = await ref.read(importExportProvider).convertAll(ids);
  showMessageOn(messenger, l10n.songsConverted(count));
}

/// Converts [song] at once (#800), with Undo: a tap on its magic wand.
Future<void> _convertSong(
  BuildContext context,
  WidgetRef ref,
  SongListEntry song,
) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final repo = ref.read(songRepositoryProvider);
  final before = (await repo.getSong(song.id))?.chordproSource;
  if (before == null) return;
  final after = cp.applyChordProConversions(before);
  if (after == before) return;
  await repo.updateSource(song.id, after);
  showUndo(
    messenger,
    l10n.songConverted(song.title),
    undoLabel: l10n.undo,
    onUndo: () => repo.updateSource(song.id, before),
  );
}

/// [marked] (see [SearchHit]) as text spans, the hits in [hitStyle].
List<TextSpan> highlightedSpans(String marked, TextStyle hitStyle) {
  final spans = <TextSpan>[];
  var rest = marked;
  while (rest.isNotEmpty) {
    final start = rest.indexOf(hitStart);
    if (start < 0) {
      spans.add(TextSpan(text: rest));
      break;
    }
    if (start > 0) spans.add(TextSpan(text: rest.substring(0, start)));
    final end = rest.indexOf(hitEnd, start);
    final stop = end < 0 ? rest.length : end;
    spans.add(TextSpan(text: rest.substring(start + 1, stop), style: hitStyle));
    rest = end < 0 ? '' : rest.substring(end + 1);
  }
  return spans;
}

/// From this width the song list has two columns (#251).
const songListTwoColumnWidth = 900.0;

/// A row of the song list: a section [header], or the indexes of up to
/// `columns` [songs].
typedef SongListRow = ({String? header, List<int> songs});

/// The rows of a song list whose songs belong to [sections] (see
/// [songSection]; null = no sections): a header row where a section starts,
/// then the songs of the section, [columns] per row. A section starts a new
/// row, so its header spans all columns.
List<SongListRow> songListRows(List<String?> sections, int columns) {
  final rows = <SongListRow>[];
  var current = <int>[];
  void flush() {
    if (current.isEmpty) return;
    rows.add((header: null, songs: current));
    current = <int>[];
  }

  for (final (i, section) in sections.indexed) {
    if (section != null && (i == 0 || sections[i - 1] != section)) {
      flush();
      rows.add((header: section, songs: const <int>[]));
    }
    current.add(i);
    if (current.length == columns) flush();
  }
  flush();
  return rows;
}

/// Section header of [song] in the list sorted by [sort]: the first letter
/// of the title (without accents; `#` for anything else), the artist, or the
/// key in [notation]. Null when sorted by last edit (no sections).
String? songSection(
  SongListEntry song,
  SongSort sort, {
  required cp.ChordNotation notation,
  required AppLocalizations l10n,
}) => switch (sort) {
  SongSort.title => _initial(song.sortTitle ?? song.title),
  SongSort.artist => song.artist ?? l10n.noArtist,
  SongSort.key =>
    song.songKey == null
        ? l10n.noKey
        : cp.Key.tryParse(song.songKey!)?.format(notation) ?? l10n.noKey,
  SongSort.recent || SongSort.lastPlayed => null,
};

String _initial(String title) {
  final folded = foldForSort(title.trim());
  final c = folded.isEmpty ? '' : folded[0].toUpperCase();
  return RegExp(r'^[A-Z]$').hasMatch(c) ? c : '#';
}

/// Header of a section in the song list.
class SongSectionHeader extends StatelessWidget {
  const SongSectionHeader(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) =>
      SectionHeader(label, key: const ValueKey('song-section-header'));
}

/// What the band's arrangement changes against the song (ADR-0025): its
/// key, tempo and sequence, marked with a band icon. Only a hint; the song
/// entry itself stays as written (#227, #245).
class BandArrangementHint extends StatelessWidget {
  const BandArrangementHint({
    super.key,
    required this.arrangement,
    required this.songKey,
    required this.notation,
    required this.bandName,
  });

  final BandArrangement arrangement;
  final cp.Key? songKey;
  final cp.ChordNotation notation;
  final String bandName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final transpose = arrangement.transpose;
    final details = [
      if (transpose != 0)
        l10n.arrangementKey(
          songKey?.transpose(transpose).format(notation) ??
              formatSemitones(transpose),
        ),
      if (arrangement.tempo case final tempo?) l10n.bpm(tempo),
    ].join(' · ');
    final sequence = arrangement.sequence == null
        ? const <cp.SequenceItem>[]
        : cp.parseSequence(arrangement.sequence!);
    final label = l10n.arrangementOf(bandName);
    return Wrap(
      key: const ValueKey('band-arrangement-hint'),
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Tooltip(
          message: label,
          child: Icon(
            Icons.groups_outlined,
            size: 18,
            color: scheme.primary,
            semanticLabel: label,
          ),
        ),
        if (details.isNotEmpty)
          Text(
            details,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        if (sequence.isNotEmpty) SongSequenceView(sequence, compact: true),
      ],
    );
  }
}

/// List entry for a song: the key as a badge in front, artist and tags
/// below the title, and the song sequence as compact chips.
class SongTile extends ConsumerWidget {
  const SongTile({
    super.key,
    required this.song,
    this.hasAttachments = false,
    this.onTap,
    this.onLongPress,
    this.trailing,
    this.leading,
    this.arrangement,
    this.bandName = '',
    this.hasConflict = false,
    this.showLanguage = false,
    this.otherVersions = 0,
    this.showProblems = false,
    this.onConvert,
    this.nextGig,
    this.hit,
    this.playedNote,
  });

  final SongListEntry song;
  final bool hasAttachments;

  /// The song waits for a decision on a sync conflict (ADR-0004).
  final bool hasConflict;

  /// Show the song's language after the title (ADR-0053): in a library
  /// with songs in more than one language.
  final bool showLanguage;

  /// How many other language versions the song has (ADR-0053), shown as an
  /// icon.
  final int otherVersions;

  /// Show a warning if the ChordPro source has problems (#314): only to
  /// people who may edit the song.
  final bool showProblems;

  /// Converts the song (#800); its magic wand becomes a button, shown
  /// with [showProblems] when the song has possible conversions.
  final VoidCallback? onConvert;

  /// The next set of the band the song is played in.
  final UpcomingGig? nextGig;

  /// Where the current search matched the song, shown highlighted.
  final SearchHit? hit;

  /// When the band last played the song, e.g. in the song picker of a set
  /// (ADR-0046).
  final String? playedNote;

  /// Arrangement of the band chosen on the sets tab (ADR-0025), shown as a
  /// hint below the song, which itself stays as written.
  final BandArrangement? arrangement;

  /// Name of the band of [arrangement].
  final String bandName;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget? trailing;
  final Widget? leading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final notation = ref.watch(settingsProvider.select((s) => s.notation));
    final theme = Theme.of(context);
    final hitStyle = TextStyle(
      fontWeight: FontWeight.w700,
      backgroundColor: theme.colorScheme.tertiaryContainer,
      color: theme.colorScheme.onTertiaryContainer,
    );
    final rest = [
      if (song.tempo case final tempo?) l10n.bpm(tempo),
      ...song.tagList.map((t) => '#$t'),
    ].join(' · ');
    final artist = hit?.artist ?? song.artist;
    final details = [?artist, if (rest.isNotEmpty) rest].join(' · ');
    final lyrics = hit?.lyrics;
    final sequence = song.sequence == null
        ? const <cp.SequenceItem>[]
        : cp.parseSequence(song.sequence!);
    final parsedKey = song.songKey == null
        ? null
        : cp.Key.tryParse(song.songKey!);
    final key = parsedKey?.format(notation) ?? song.songKey;
    final band = arrangement;
    return ListTile(
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ?leading,
          SongKeyBadge(keyName: key),
        ],
      ),
      title: Text.rich(
        TextSpan(
          children: [
            if (song.title.isEmpty)
              TextSpan(text: l10n.untitled)
            else
              ...highlightedSpans(hit?.title ?? song.title, hitStyle),
            if (showLanguage && song.language != null) ...[
              const TextSpan(text: ' '),
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: SongLanguageTag(
                  language: song.language!,
                  byHand: song.languageByHand,
                ),
              ),
            ],
          ],
        ),
      ),
      subtitle:
          details.isEmpty &&
              sequence.isEmpty &&
              band == null &&
              lyrics == null &&
              playedNote == null
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (details.isNotEmpty)
                  Text.rich(
                    TextSpan(children: highlightedSpans(details, hitStyle)),
                  ),
                if (lyrics != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      key: const ValueKey('song-lyrics-hit'),
                      children: [
                        Icon(
                          Icons.lyrics_outlined,
                          size: 16,
                          semanticLabel: l10n.foundInLyrics,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              children: highlightedSpans(lyrics, hitStyle),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontStyle: FontStyle.italic),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (sequence.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: SongSequenceView(sequence, compact: true),
                  ),
                if (band != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: BandArrangementHint(
                      arrangement: band,
                      songKey: parsedKey,
                      notation: notation,
                      bandName: bandName,
                    ),
                  ),
                if (playedNote case final note?)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      key: const ValueKey('song-played-note'),
                      children: [
                        Icon(
                          Icons.history,
                          size: 16,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(note)),
                      ],
                    ),
                  ),
              ],
            ),
      trailing: trailing ?? _status(context, l10n),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }

  /// Status icons: conflict, next gig, sheet music only or attachments.
  Widget? _status(BuildContext context, AppLocalizations l10n) {
    final scheme = Theme.of(context).colorScheme;
    Widget icon(Key key, String message, IconData data, [Color? color]) =>
        Tooltip(
          key: key,
          message: message,
          child: Icon(data, color: color, semanticLabel: message),
        );
    final icons = [
      if (hasConflict)
        icon(
          const ValueKey('song-status-conflict'),
          l10n.songConflictTooltip,
          Icons.sync_problem,
          scheme.error,
        ),
      if (showProblems && song.problems > 0)
        ChordProProblemsBadge(
          key: const ValueKey('song-status-problems'),
          message: l10n.chordProProblemsTooltip(song.problems),
        ),
      if (showProblems && song.conversions > 0)
        if (onConvert case final convert?)
          IconButton(
            key: const ValueKey('song-status-conversions'),
            tooltip: l10n.chordProConversionsTooltip(song.conversions),
            icon: const Icon(chordProConversionsIcon),
            onPressed: convert,
          )
        else
          icon(
            const ValueKey('song-status-conversions'),
            l10n.chordProConversionsTooltip(song.conversions),
            chordProConversionsIcon,
          ),
      if (otherVersions > 0)
        icon(
          const ValueKey('song-status-versions'),
          l10n.otherLanguageVersionsTooltip(otherVersions),
          Icons.translate,
        ),
      if (nextGig case final gig?)
        icon(
          const ValueKey('song-status-gig'),
          l10n.upcomingGigTooltip(
            gig.setName,
            formatGigDate(context, gig.date),
          ),
          Icons.event_outlined,
          scheme.primary,
        ),
      if (!song.hasChords)
        icon(
          const ValueKey('song-status-pdf-only'),
          l10n.pdfOnlyTooltip,
          Icons.picture_as_pdf,
        )
      else if (hasAttachments)
        icon(
          const ValueKey('song-status-attachments'),
          l10n.attachmentsTooltip,
          Icons.picture_as_pdf_outlined,
        ),
    ];
    if (icons.isEmpty) return null;
    return Row(mainAxisSize: MainAxisSize.min, spacing: 8, children: icons);
  }
}

/// The key of a song in a list, as an outlined badge of fixed width so that
/// the keys form a column; empty (but as wide) for songs without a key.
class SongKeyBadge extends StatelessWidget {
  const SongKeyBadge({super.key, required this.keyName});

  /// Formatted key, or null.
  final String? keyName;

  static const width = 48.0;

  @override
  Widget build(BuildContext context) {
    final name = keyName;
    if (name == null) return const SizedBox(width: width);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      label: AppLocalizations.of(context).keyLabel(name),
      excludeSemantics: true,
      child: Container(
        key: const ValueKey('song-key-badge'),
        constraints: const BoxConstraints(minWidth: width, minHeight: 36),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          border: Border.all(color: scheme.primary, width: 1.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          name,
          maxLines: 1,
          style: theme.textTheme.titleMedium?.copyWith(
            color: scheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

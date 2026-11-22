import 'dart:async';

import 'package:chordpro/chordpro.dart' as cp;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/song_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../providers.dart';
import '../trash/trash_screen.dart';
import '../../settings/settings.dart';
import '../account/sync_refresh.dart';
import '../backup/backup_actions.dart';
import '../bands/copy_to_band.dart';
import '../bands/library_switcher.dart';
import '../sets/sets_screen.dart' show formatGigDate;
import '../widgets/app_shortcuts.dart';
import '../widgets/dialogs.dart';
import 'import_dialog.dart';
import 'library_usage_screen.dart';
import 'song_archive_dialogs.dart';
import 'song_attention.dart';
import 'song_editor_screen.dart';
import 'song_language.dart';
import 'song_screen.dart';
import '../widgets/menu_action.dart';

import 'song_list.dart';

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
  final _searchFocus = FocusNode();
  String _query = '';

  /// The chosen filters, shared in kind with the song picker of a set
  /// (#886).
  SongListFilter _filter = const SongListFilter();

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
    final songs = ref.watch(songsProvider((query: _query, tags: _filter.tags)));
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
    final filter = lastPlayed == null ? _filter.withPlayed(null) : _filter;
    // Language tags and the language filter only for a library with songs
    // in more than one language (ADR-0053).
    final usedLanguages =
        ref.watch(songLanguagesProvider).value ?? const <String>{};
    final languages = usedLanguages.difference(const {noSongLanguage});
    final mixedLanguages = languages.length > 1;
    final works = ref.watch(workCountsProvider).value ?? const <String, int>{};
    List<SongListEntry> shownSongs(List<SongListEntry> songs) => filter.apply(
      visible(songs),
      lastPlayed: lastPlayed,
      staleAfterMonths: historyBand?.staleAfterMonths ?? 0,
      byLastPlayed: byLastPlayed,
    );

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
              child: SongSearchBar(
                focusNode: _searchFocus,
                onQuery: (query) => setState(() => _query = query),
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
                    tooltip: l10n.exportSong,
                    icon: const Icon(Icons.file_download_outlined),
                    onPressed: selected.isEmpty
                        ? null
                        : () async {
                            await exportSongs(context, ref, selected.toList());
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
            SongFilters(
              filter: filter,
              onChanged: (filter) => setState(() => _filter = filter),
              usedTags: ref.watch(tagsProvider).value ?? const [],
              attention: attention,
              showPlayed: lastPlayed != null,
              usedLanguages: usedLanguages,
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
                            (attention == null && !filter.narrows) ||
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
                    child: SongListView(sections: sections, tile: tile),
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

import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/song_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../providers.dart';
import '../../settings/settings.dart';
import '../songs/song_language.dart';
import '../songs/songs_screen.dart';
import 'sets_screen.dart' show formatGigDate;
import '../widgets/dialogs.dart';

/// Lets the user select several songs. Returns their IDs in selection order.
/// With [bandId], each song says when that band last played it (ADR-0046).
Future<List<String>> pickSongs(BuildContext context, {String? bandId}) async =>
    await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _SongPicker(bandId: bandId),
      ),
    ) ??
    const [];

/// Lets the user select one song, e.g. for a preview; null when the picker
/// was closed without a choice.
Future<String?> pickSong(BuildContext context, {required String title}) async {
  final ids = await Navigator.push<List<String>>(
    context,
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _SongPicker(single: true, title: title),
    ),
  );
  return ids == null || ids.isEmpty ? null : ids.first;
}

/// The songs of the band's library, built like the song list (#884): the
/// same search, order, filters, sections and columns.
class _SongPicker extends ConsumerStatefulWidget {
  const _SongPicker({this.single = false, this.title, this.bandId});

  /// One song: a tap chooses it and closes the picker.
  final bool single;
  final String? title;

  /// The band of the set the songs are for, whose plays are shown.
  final String? bandId;

  @override
  ConsumerState<_SongPicker> createState() => _SongPickerState();
}

class _SongPickerState extends ConsumerState<_SongPicker> {
  final _selected = <String>[];
  final _search = TextEditingController();
  String _query = '';
  Timer? _searchDebounce;

  /// Selected tags (see [SongFilters]); replaced, never changed in place.
  Set<String> _tags = const {};
  PlayedFilter? _played;
  String? _language;

  /// The songs last shown, kept while a changed search loads (as on the
  /// song list, #297).
  ({List<SongListEntry> songs, Map<String, SearchHit> hits, SongSort sort})?
  _shown;

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(songSearchDelay, () {
      if (mounted) setState(() => _query = value);
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final songs = ref.watch(bandSongsProvider((query: _query, tags: _tags)));
    final hits = ref.watch(bandSearchHitsProvider(_query));
    final sort = ref.watch(songSortProvider);
    if (songs.hasValue && !songs.isLoading && !hits.isLoading) {
      _shown = (
        songs: songs.requireValue,
        hits: hits.value ?? const {},
        sort: sort,
      );
    }
    final AsyncValue<
      ({List<SongListEntry> songs, Map<String, SearchHit> hits, SongSort sort})
    >
    results = switch (_shown) {
      _ when songs.hasError && !songs.isLoading => AsyncError(
        songs.error!,
        songs.stackTrace ?? StackTrace.empty,
      ),
      final shown? => AsyncData(shown),
      null => const AsyncLoading(),
    };
    final notation = ref.watch(settingsProvider.select((s) => s.notation));
    final currentBand = ref.watch(currentBandProvider);
    final band = ref.watch(arrangementBandProvider(currentBand.libraryId));
    final arrangements = band == null
        ? const <String, BandArrangement>{}
        : ref.watch(bandArrangementsProvider(band.id)).value ?? const {};
    final lastPlayed = widget.bandId == null
        ? null
        : ref.watch(lastPlayedProvider(widget.bandId!)).value ??
              const <String, DateTime>{};
    final byLastPlayed = sort == SongSort.lastPlayed && lastPlayed != null;
    final played = lastPlayed == null ? null : _played;
    final usedLanguages =
        ref.watch(bandSongLanguagesProvider).value ?? const <String>{};
    final languages = usedLanguages.difference(const {noSongLanguage});
    final language = _language;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? l10n.selectSongs),
        actions: [
          if (!widget.single) ...[
            Center(child: Text(l10n.selectedCount(_selected.length))),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton(
                key: const Key('song-picker-add'),
                onPressed: _selected.isEmpty
                    ? null
                    : () => Navigator.pop(context, _selected),
                child: Text(l10n.add),
              ),
            ),
          ],
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SearchBar(
              controller: _search,
              hintText: l10n.searchSongs,
              leading: const Icon(Icons.search),
              autoFocus: false,
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
      ),
      body: Column(
        children: [
          SongFilters(
            usedTags: ref.watch(bandTagsProvider).value ?? const [],
            attentionFilters: false,
            tags: _tags,
            onTags: (tags) => setState(() => _tags = tags),
            attention: null,
            showPlayed: lastPlayed != null,
            played: played,
            onPlayed: (filter) => setState(() => _played = filter),
            languages: languages,
            withoutLanguage: usedLanguages.contains(noSongLanguage),
            language: language,
            onLanguage: (l) => setState(() => _language = l),
          ),
          Expanded(
            child: AsyncBody(
              value: results,
              data: (results) {
                final (songs: all, :hits, :sort) = results;
                final list = filterSongList(
                  all,
                  language: language,
                  played: played,
                  lastPlayed: lastPlayed,
                  staleAfterMonths: currentBand.id == widget.bandId
                      ? currentBand.staleAfterMonths
                      : 0,
                  byLastPlayed: byLastPlayed,
                );
                if (list.isEmpty) {
                  return EmptyState(
                    icon: Icons.library_music_outlined,
                    message: (played == null && language == null) || all.isEmpty
                        ? l10n.songsEmpty
                        : l10n.songsFilterEmpty,
                  );
                }
                final sections = [
                  for (final song in list)
                    songSection(
                      song,
                      byLastPlayed ? SongSort.lastPlayed : sort,
                      notation: notation,
                      l10n: l10n,
                    ),
                ];
                Widget tile(int i) {
                  final song = list[i];
                  final index = _selected.indexOf(song.id);
                  return SongTile(
                    song: song,
                    arrangement: arrangements[song.id],
                    bandName: band?.name ?? '',
                    showLanguage: languages.length > 1,
                    hit: hits[song.id],
                    playedNote: lastPlayed == null
                        ? null
                        : switch (lastPlayed[song.id]) {
                            final date? => l10n.songLastPlayed(
                              formatGigDate(context, date),
                            ),
                            null => l10n.songNeverPlayed,
                          },
                    leading: widget.single
                        ? null
                        : Checkbox(
                            value: index >= 0,
                            onChanged: (_) => _toggle(song.id),
                          ),
                    trailing: index >= 0
                        ? CircleAvatar(radius: 14, child: Text('${index + 1}'))
                        : const SizedBox.shrink(),
                    onTap: widget.single
                        ? () => Navigator.pop(context, [song.id])
                        : () => _toggle(song.id),
                  );
                }

                return SongListView(
                  sections: sections,
                  tile: tile,
                  bottomPadding: 16,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _toggle(String id) => setState(() {
    if (!_selected.remove(id)) _selected.add(id);
  });
}

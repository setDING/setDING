// The song list as the songs tab and the song picker of a set show it
// (#884, #886): the search field, the filters, the filtering, sections,
// columns and the song tile. Both screens use only these parts for their
// list, so a change here reaches both; song_list_parity_test.dart checks
// that they offer the same filters and show the same songs.

import 'dart:async';

import 'package:chordpro/chordpro.dart' as cp;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/backup_providers.dart';
import '../../data/band_providers.dart';
import '../../data/database.dart';
import '../../data/play_history.dart' show staleBefore;
import '../../data/song_repository.dart';
import '../../data/set_repository.dart';
import '../../data/song_providers.dart';
import '../../data/text.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../settings/settings.dart';
import '../render/song_header.dart';
import '../sets/sets_screen.dart' show formatGigDate;
import '../widgets/breakpoint_builder.dart';
import '../widgets/dialogs.dart';
import 'chordpro_problems_badge.dart';
import 'song_attention.dart';
import 'song_language.dart';
import '../widgets/section_header.dart';

/// Delay before a changed search text is applied, so that typing does not
/// start a database query per keystroke.
const songSearchDelay = Duration(milliseconds: 250);

/// The songs of a list in their [sections] (see [songSection]), one
/// column, or two from [songListTwoColumnWidth] (#251): the song list and
/// the song picker of a set (#884).
class SongListView extends StatelessWidget {
  const SongListView({
    super.key,
    required this.sections,
    required this.tile,
    this.bottomPadding = 88,
  });

  /// The section of each song, null for none.
  final List<String?> sections;

  /// The tile of the song at an index.
  final Widget Function(int song) tile;

  /// Room below the last song, e.g. for a floating action button.
  final double bottomPadding;

  @override
  Widget build(BuildContext context) => BreakpointBuilder(
    select: (constraints) =>
        constraints.maxWidth >= songListTwoColumnWidth ? 2 : 1,
    builder: (context, columns) {
      final rows = songListRows(sections, columns);
      return ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(bottom: bottomPadding),
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
    },
  );
}

/// Songs the band never played, or has not played for a while (ADR-0046).
enum PlayedFilter { never, stale }

/// The filters of a song list, chosen with [SongFilters] and applied with
/// [apply] (the tags already by the database query). One value for the
/// song list and the song picker of a set (#886): a new filter is added
/// here, in [SongFilters] and in [filterSongList], and both get it.
@immutable
class SongListFilter {
  const SongListFilter({this.tags = const {}, this.played, this.language});

  /// Songs with any of these tags (#816); empty for all songs. Replaced,
  /// never changed in place: the song providers compare it by identity.
  final Set<String> tags;

  /// Only songs the band never played, or has not played for a while
  /// (ADR-0046); null for all songs.
  final PlayedFilter? played;

  /// Only songs of this language (ADR-0053), [noSongLanguage] for songs
  /// without one; null for all songs.
  final String? language;

  /// Whether a filter besides the tags is chosen.
  bool get narrows => played != null || language != null;

  SongListFilter withTags(Set<String> tags) =>
      SongListFilter(tags: tags, played: played, language: language);

  SongListFilter withPlayed(PlayedFilter? played) =>
      SongListFilter(tags: tags, played: played, language: language);

  SongListFilter withLanguage(String? language) =>
      SongListFilter(tags: tags, played: played, language: language);

  /// [songs] with the language and plays filters (see [filterSongList]).
  List<SongListEntry> apply(
    List<SongListEntry> songs, {
    Map<String, DateTime>? lastPlayed,
    int staleAfterMonths = 0,
    bool byLastPlayed = false,
  }) => filterSongList(
    songs,
    language: language,
    played: played,
    lastPlayed: lastPlayed,
    staleAfterMonths: staleAfterMonths,
    byLastPlayed: byLastPlayed,
  );
}

/// The search field above a song list (#886): applies the text after
/// [songSearchDelay] and has a button to clear it.
class SongSearchBar extends StatefulWidget {
  const SongSearchBar({super.key, required this.onQuery, this.focusNode});

  /// Called with the search text once typing pauses, at once when cleared.
  final ValueChanged<String> onQuery;
  final FocusNode? focusNode;

  @override
  State<SongSearchBar> createState() => _SongSearchBarState();
}

class _SongSearchBarState extends State<SongSearchBar> {
  final _search = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SearchBar(
      controller: _search,
      focusNode: widget.focusNode,
      hintText: l10n.searchSongs,
      leading: const Icon(Icons.search),
      autoFocus: false,
      trailing: [
        if (_search.text.isNotEmpty)
          IconButton(
            tooltip: l10n.searchClear,
            icon: const Icon(Icons.clear),
            onPressed: () {
              _debounce?.cancel();
              _search.clear();
              setState(() {});
              widget.onQuery('');
            },
          ),
      ],
      onChanged: (value) {
        setState(() {});
        _debounce?.cancel();
        _debounce = Timer(songSearchDelay, () {
          if (mounted) widget.onQuery(value);
        });
      },
    );
  }
}

/// [songs] of the [language] ([noSongLanguage] for songs without one, null
/// for all) and the [played] filter by the band's plays [lastPlayed]
/// (songs not played for [staleAfterMonths] are stale), the most recently
/// played first with [byLastPlayed] (ADR-0046, ADR-0053). Shared by the
/// song list and the song picker of a set (#884).
List<SongListEntry> filterSongList(
  List<SongListEntry> songs, {
  String? language,
  PlayedFilter? played,
  Map<String, DateTime>? lastPlayed,
  int staleAfterMonths = 0,
  bool byLastPlayed = false,
  DateTime? now,
}) {
  var list = songs;
  if (language != null) {
    list = [
      for (final s in list)
        if ((s.language ?? noSongLanguage) == language) s,
    ];
  }
  if (played != null && lastPlayed != null) {
    final before = staleBefore(now ?? DateTime.now(), staleAfterMonths);
    list = [
      for (final s in list)
        if (switch (played) {
          PlayedFilter.never => !lastPlayed.containsKey(s.id),
          PlayedFilter.stale => lastPlayed[s.id]?.isBefore(before) ?? false,
        })
          s,
    ];
  }
  if (byLastPlayed && lastPlayed != null) {
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

/// Chips above the list: the order (a menu, see [SongSort]) and the
/// filters, among them the tags used in the library (`{tag}`, a menu with
/// several choices, #816) and, last, the band's plays (a menu). The song
/// list and the song picker of a set (#884).
class SongFilters extends ConsumerWidget {
  const SongFilters({
    super.key,
    required this.filter,
    required this.onChanged,
    required this.usedTags,
    this.attentionFilters = true,
    this.attention,
    required this.showPlayed,
    required this.usedLanguages,
  });

  /// The chosen filters.
  final SongListFilter filter;
  final ValueChanged<SongListFilter> onChanged;

  /// The tags used in the library.
  final List<String> usedTags;

  /// Offer the filters of the overview's To do card (ADR-0045): not in
  /// the song picker, which is for choosing songs, not for fixing them.
  final bool attentionFilters;

  /// Offer the order and filters by the band's plays (ADR-0046).
  final bool showPlayed;

  /// The languages of the library's songs, [noSongLanguage] for songs
  /// without one (ADR-0053); the filter is offered when the library has
  /// more than one, *No language* only when songs have none (#843).
  final Set<String> usedLanguages;

  /// The filter chosen on the overview (ADR-0045), shown first and
  /// removable.
  final SongAttention? attention;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tags = filter.tags;
    final played = showPlayed ? filter.played : null;
    final language = filter.language;
    final languages = usedLanguages.difference(const {noSongLanguage});
    final withoutLanguage = usedLanguages.contains(noSongLanguage);
    void onTags(Set<String> tags) => onChanged(filter.withTags(tags));
    void onPlayed(PlayedFilter? played) => onChanged(filter.withPlayed(played));
    void onLanguage(String? language) =>
        onChanged(filter.withLanguage(language));
    final used = usedTags;
    final sort = ref.watch(songSortProvider);
    final counts = attentionFilters
        ? ref.watch(songAttentionCountsProvider)
        : null;
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
    String languageLabel(String? l) => switch (l) {
      null => l10n.allLanguages,
      noSongLanguage => l10n.noLanguage,
      _ => songLanguageName(l10n, l),
    };
    Widget item(String? l) => MenuItemButton(
      key: ValueKey(
        'songs-language-${l == noSongLanguage ? 'none' : l ?? 'all'}',
      ),
      onPressed: () => onLanguage(l),
      leadingIcon: l == language
          ? const Icon(Icons.check, size: 18)
          : const SizedBox.square(dimension: 18),
      child: Text(languageLabel(l)),
    );
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
            if (attentionFilters &&
                (kind == attention || (counts?[kind] ?? 0) > 0))
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
          if (attention == SongAttention.toReview)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                key: const Key('songs-approve-all'),
                avatar: const Icon(Icons.done_all, size: 18),
                label: Text(l10n.approveAllSongs),
                onPressed: () => _approveAll(context, ref),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: MenuAnchor(
              menuChildren: [
                for (final (value, label) in orders)
                  MenuItemButton(
                    key: ValueKey('songs-sort-${value.name}'),
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
                  item(null),
                  // Offered like the languages: only when songs have none,
                  // or while it is selected (#843).
                  if (withoutLanguage || language == noSongLanguage)
                    item(noSongLanguage),
                  const Divider(height: 1),
                  for (final l in orderedSongLanguages({
                    ...languages,
                    ?language,
                  }))
                    item(l),
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
                        Text(languageLabel(language)),
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

/// Approves every song of the library the person may approve that waits
/// for a check (ADR-0060), after asking, with Undo.
Future<void> _approveAll(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  final songs = await ref.read(songRepositoryProvider).watchSongList().first;
  if (!context.mounted) return;
  final library = ref.read(currentLibraryProvider);
  final ids = [
    for (final s in songs)
      if (needsAttention(
        SongAttention.toReview,
        s,
        library: library,
        conflicts: const {},
      ))
        s.id,
  ];
  if (ids.isEmpty) return;
  final messenger = ScaffoldMessenger.of(context);
  if (!await confirm(
    context,
    title: l10n.approveAllSongsTitle,
    message: l10n.approveAllSongsMessage(ids.length),
    action: l10n.approveSong,
    destructive: false,
  )) {
    return;
  }
  final review = ref.read(songReviewRepositoryProvider);
  final before = await review.approveAll(ids);
  showUndo(
    messenger,
    l10n.songsApproved(before.length),
    undoLabel: l10n.undo,
    onUndo: () => review.restoreReview(before),
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
    this.reported = false,
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

  /// The song has open mistake reports (ADR-0060); shown to everyone, like
  /// a song that waits for a check.
  final bool reported;

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
      // Shown to everyone (ADR-0060): not checked yet, or maybe wrong.
      if (reported)
        icon(
          const ValueKey('song-status-reported'),
          l10n.songReportedTooltip,
          songReportedIcon,
          scheme.error,
        )
      else if (song.toReview)
        icon(
          const ValueKey('song-status-to-review'),
          l10n.songToReviewTooltip,
          songToReviewIcon,
          scheme.onSurfaceVariant,
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

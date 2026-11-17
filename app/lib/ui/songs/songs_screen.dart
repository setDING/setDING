import 'dart:async';

import 'package:chordpro/chordpro.dart' as cp;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/song_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../providers.dart';
import '../../settings/settings.dart';
import '../bands/copy_to_band.dart';
import '../bands/library_switcher.dart';
import '../render/song_header.dart';
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
    final band = ref.watch(arrangementBandProvider(library.id));
    final arrangements = band == null
        ? const <String, BandArrangement>{}
        : ref.watch(bandArrangementsProvider(band.id)).value ?? const {};
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
                        arrangement: arrangements[list[i].id],
                        bandName: band?.name ?? '',
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
      spacing: 6,
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
  });

  final SongListEntry song;
  final bool hasAttachments;

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
    final details = [
      if (song.artist != null) song.artist!,
      if (song.tempo case final tempo?) l10n.bpm(tempo),
      ...song.tagList.map((t) => '#$t'),
    ].join(' · ');
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
      title: Text(song.title.isEmpty ? l10n.untitled : song.title),
      subtitle: details.isEmpty && sequence.isEmpty && band == null
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (details.isNotEmpty) Text(details),
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
              ],
            ),
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
        padding: const EdgeInsets.symmetric(horizontal: 6),
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

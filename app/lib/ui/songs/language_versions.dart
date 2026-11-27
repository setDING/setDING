import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/band_providers.dart';
import '../../data/database.dart';
import '../../data/song_providers.dart';
import '../../data/song_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../widgets/breakpoint_builder.dart';
import '../widgets/dialogs.dart';
import '../widgets/page_width.dart';
import '../widgets/section_header.dart';
import 'song_language.dart';
import 'song_list.dart';
import '../routes.dart';

/// The language versions of the work of a song, the song included and not
/// in the trash (ADR-0053); empty while it has no group.
final languageVersionsProvider = StreamProvider.autoDispose
    .family<List<SongEntry>, String>(
      (ref, songId) =>
          ref.watch(songRepositoryProvider).watchLanguageVersions(songId),
    );

/// The language of a song: set by hand, else detected.
String? _languageOf(SongEntry song) => song.language ?? song.detectedLanguage;

/// [versions] in the order of the version chips: the language of the UI
/// ([uiLanguage]) first, then by language code, songs without a language
/// last, each by title.
List<SongEntry> orderedLanguageVersions(
  List<SongEntry> versions,
  String uiLanguage,
) {
  int rank(SongEntry s) => switch (_languageOf(s)) {
    final l? when l == uiLanguage => 0,
    null => 2,
    _ => 1,
  };
  return [...versions]..sort((a, b) {
    final r = rank(a).compareTo(rank(b));
    if (r != 0) return r;
    final c = (_languageOf(a) ?? '').compareTo(_languageOf(b) ?? '');
    return c != 0 ? c : a.title.compareTo(b.title);
  });
}

/// The name of the language version [version] among [versions]: its
/// language, or its title while the language is unknown, *other* or shared
/// with another version.
String languageVersionLabel(
  AppLocalizations l10n,
  SongEntry version,
  List<SongEntry> versions,
) {
  final language = _languageOf(version);
  final unique =
      language != null &&
      language != 'other' &&
      versions.where((v) => _languageOf(v) == language).length == 1;
  if (!unique) return version.title.isEmpty ? l10n.untitled : version.title;
  return songLanguageName(l10n, language);
}

/// The language versions of [song] below its header (ADR-0053): one chip per
/// version, named by its language (by its title while the language is
/// unknown or shared with another version); a tap opens that version.
/// Nothing while the song has no other versions.
class LanguageVersionChips extends ConsumerWidget {
  const LanguageVersionChips({super.key, required this.song});

  final SongEntry song;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final versions =
        ref.watch(languageVersionsProvider(song.id)).value ?? const [];
    if (versions.length < 2) return const SizedBox.shrink();
    final ordered = orderedLanguageVersions(
      versions,
      Localizations.localeOf(context).languageCode,
    );
    String label(SongEntry v) => languageVersionLabel(l10n, v, versions);

    return Semantics(
      container: true,
      label: l10n.languageVersions,
      child: Padding(
        key: const Key('language-versions'),
        padding: const EdgeInsets.only(top: 8),
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Icon(
              Icons.translate,
              size: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            for (final v in ordered)
              ChoiceChip(
                key: ValueKey('language-version-${v.id}'),
                label: Text(label(v)),
                tooltip: v.title,
                selected: v.id == song.id,
                // The current version stays selected (not disabled).
                onSelected: (_) => v.id == song.id
                    ? null
                    : context.pushReplacement(AppPaths.song(v.id)),
              ),
          ],
        ),
      ),
    );
  }
}

/// How alike [a] and [b] look: one point each for the same artist, key,
/// tempo and sequence. Candidates for a language version come first.
int languageVersionLikeness(SongListEntry a, SongListEntry b) {
  bool same(String? x, String? y) =>
      x != null &&
      y != null &&
      x.trim().toLowerCase() == y.trim().toLowerCase();
  return [
    same(a.artist, b.artist),
    same(a.songKey, b.songKey),
    a.tempo != null && a.tempo == b.tempo,
    same(a.sequence, b.sequence),
  ].where((x) => x).length;
}

/// Lets the person choose the language versions of [song] in a two-pane
/// dialog (ADR-0053, #851): the songs of the library with a search on one
/// side, the chosen versions on the other, where they can be removed again.
/// Saving links the added songs and removes the others from the group, with
/// Undo. Only songs the person may edit are offered or can be removed.
Future<void> linkLanguageVersion(
  BuildContext context,
  WidgetRef ref,
  SongEntry song,
) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final change = await Navigator.push<_VersionChange>(
    context,
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _LanguageVersionPicker(song: song),
    ),
  );
  if (change == null || (change.add.isEmpty && change.remove.isEmpty)) return;
  final library = ref.read(currentLibraryProvider);
  final repo = ref.read(songRepositoryProvider);
  final result = await repo.updateLanguageVersions(
    song.id,
    add: change.add,
    remove: change.remove,
    mayEdit: library.canEditSong,
  );
  final notLinked = result.notLinked.length;
  showUndo(
    messenger,
    notLinked == 0
        ? l10n.languageVersionsSaved
        : l10n.languageVersionsNotAllowed(notLinked),
    undoLabel: l10n.undo,
    onUndo: () async {
      for (final MapEntry(:key, :value) in result.before.entries) {
        await repo.setWorkId(key, value);
      }
    },
  );
}

/// Removes [song] from its language versions, with Undo (ADR-0053).
Future<void> unlinkLanguageVersion(
  BuildContext context,
  WidgetRef ref,
  SongEntry song,
) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final repo = ref.read(songRepositoryProvider);
  final work = song.workId;
  await repo.unlinkLanguageVersion(song.id);
  showUndo(
    messenger,
    l10n.languageVersionUnlinked,
    undoLabel: l10n.undo,
    onUndo: () => repo.setWorkId(song.id, work),
  );
}

/// The songs to link to and to remove from a group of language versions.
typedef _VersionChange = ({Set<String> add, Set<String> remove});

/// From this width the picker shows the library and the chosen versions
/// side by side; below it, the chosen versions are chips above the list.
const _twoPaneWidth = 840.0;

class _LanguageVersionPicker extends ConsumerStatefulWidget {
  const _LanguageVersionPicker({required this.song});

  final SongEntry song;

  @override
  ConsumerState<_LanguageVersionPicker> createState() =>
      _LanguageVersionPickerState();
}

class _LanguageVersionPickerState
    extends ConsumerState<_LanguageVersionPicker> {
  String _query = '';

  /// The versions of the song when the picker opened, without the song.
  Set<String>? _initial;

  /// The versions chosen now, in the order they were chosen.
  final _selected = <String>{};

  void _toggle(String id) => setState(
    () => _selected.contains(id) ? _selected.remove(id) : _selected.add(id),
  );

  bool get _changed =>
      _initial != null &&
      (_initial!.length != _selected.length ||
          !_initial!.containsAll(_selected));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final song = widget.song;
    final library = ref.watch(currentLibraryProvider);
    final everything = ref.watch(songsProvider((query: '', tags: const {})));
    final found = ref.watch(songsProvider((query: _query, tags: const {})));
    final all = everything.value ?? const <SongListEntry>[];
    final byId = {for (final s in all) s.id: s};
    final work = song.workId;
    if (_initial == null && everything.hasValue) {
      _initial = {
        for (final s in all)
          if (work != null && s.workId == work && s.id != song.id) s.id,
      };
      _selected.addAll(_initial!);
    }
    bool mayEdit(SongListEntry s) =>
        library.canEditSongBy(createdBy: s.createdBy, updatedBy: s.updatedBy);
    // A version of the song the person may not edit stays.
    bool locked(SongListEntry s) => _initial!.contains(s.id) && !mayEdit(s);
    int otherVersions(SongListEntry s) => s.workId == null || s.workId == work
        ? 0
        : all.where((o) => o.workId == s.workId).length - 1;

    final self = byId[song.id];
    final candidates = [
      for (final s in found.value ?? const <SongListEntry>[])
        if (s.id != song.id && (mayEdit(s) || _selected.contains(s.id))) s,
    ];
    if (self != null) {
      final order = {for (final (i, s) in candidates.indexed) s.id: i};
      candidates.sort((a, b) {
        final c = languageVersionLikeness(
          self,
          b,
        ).compareTo(languageVersionLikeness(self, a));
        return c != 0 ? c : order[a.id]!.compareTo(order[b.id]!);
      });
    }
    final chosen = [for (final id in _selected) ?byId[id]];

    // Wide, the chosen songs are listed on the right only: a tap on the
    // left adds a song (#860). Narrow, tick boxes show what is chosen.
    Widget libraryPane({required bool wide}) {
      final shown = wide
          ? [
              for (final s in candidates)
                if (!_selected.contains(s.id)) s,
            ]
          : candidates;
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SearchBar(
              key: const Key('language-version-search'),
              hintText: l10n.searchSongs,
              leading: const Icon(Icons.search),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: AsyncBody(
              value: found,
              data: (_) => shown.isEmpty
                  ? EmptyState(
                      icon: Icons.translate,
                      message: l10n.languageVersionPickerEmpty,
                    )
                  : ListView.builder(
                      itemCount: shown.length,
                      itemBuilder: (context, i) {
                        final s = shown[i];
                        final fixed = locked(s);
                        return SongTile(
                          key: ValueKey('language-version-candidate-${s.id}'),
                          song: s,
                          showLanguage: true,
                          otherVersions: otherVersions(s),
                          leading: wide
                              ? null
                              : Checkbox(
                                  value: _selected.contains(s.id),
                                  onChanged: fixed
                                      ? null
                                      : (_) => _toggle(s.id),
                                ),
                          onTap: fixed ? null : () => _toggle(s.id),
                        );
                      },
                    ),
            ),
          ),
        ],
      );
    }

    Widget removeButton(SongListEntry s) => IconButton(
      key: ValueKey('language-version-remove-${s.id}'),
      tooltip: l10n.remove,
      icon: const Icon(Icons.close),
      onPressed: () => _toggle(s.id),
    );

    final header = SectionHeader(
      l10n.languageVersionsChosen(chosen.length),
      icon: Icons.translate,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.languageVersionsOf(
            song.title.isEmpty ? l10n.untitled : song.title,
          ),
        ),
        actions: [
          TextButton(
            key: const Key('language-versions-save'),
            onPressed: _changed
                ? () => Navigator.pop<_VersionChange>(context, (
                    add: _selected.difference(_initial!),
                    remove: _initial!.difference(_selected),
                  ))
                : null,
            child: Text(l10n.save),
          ),
        ],
      ),
      body: BreakpointBuilder<bool>(
        select: (c) => c.maxWidth >= _twoPaneWidth,
        builder: (context, wide) => wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: libraryPane(wide: true)),
                  const VerticalDivider(width: 1),
                  SizedBox(
                    width: 360,
                    child: Column(
                      key: const Key('language-versions-chosen'),
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        header,
                        Expanded(
                          child: chosen.isEmpty
                              ? EmptyState(
                                  icon: Icons.translate,
                                  message: l10n.languageVersionsChosenEmpty,
                                )
                              : ListView(
                                  children: [
                                    for (final s in chosen)
                                      SongTile(
                                        key: ValueKey(
                                          'language-version-chosen-${s.id}',
                                        ),
                                        song: s,
                                        showLanguage: true,
                                        trailing: locked(s)
                                            ? null
                                            : removeButton(s),
                                      ),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : PageWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    header,
                    Padding(
                      key: const Key('language-versions-chosen'),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: chosen.isEmpty
                          ? Text(l10n.languageVersionsChosenEmpty)
                          : Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                for (final s in chosen)
                                  InputChip(
                                    key: ValueKey(
                                      'language-version-chosen-${s.id}',
                                    ),
                                    label: Text(
                                      s.title.isEmpty ? l10n.untitled : s.title,
                                    ),
                                    onDeleted: locked(s)
                                        ? null
                                        : () => _toggle(s.id),
                                    deleteButtonTooltipMessage: l10n.remove,
                                  ),
                              ],
                            ),
                    ),
                    const Divider(height: 24),
                    Expanded(child: libraryPane(wide: false)),
                  ],
                ),
              ),
      ),
    );
  }
}

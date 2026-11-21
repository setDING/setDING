import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/song_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../providers.dart';
import '../widgets/dialogs.dart';
import '../widgets/page_width.dart';
import 'song_language.dart';
import 'song_screen.dart';
import 'songs_screen.dart';

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
                    : Navigator.pushReplacement(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => SongScreen(songId: v.id),
                        ),
                      ),
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

/// Lets the person pick another song of the library to link [song] with as
/// a language version, and links them (ADR-0053). Songs already in the
/// group and songs the person may not edit are not offered.
Future<void> linkLanguageVersion(
  BuildContext context,
  WidgetRef ref,
  SongEntry song,
) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final other = await Navigator.push<String>(
    context,
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _LanguageVersionPicker(song: song),
    ),
  );
  if (other == null) return;
  final library = ref.read(currentLibraryProvider);
  final linked = await ref
      .read(songRepositoryProvider)
      .linkLanguageVersions(song.id, other, mayEdit: library.canEditSong);
  showMessageOn(
    messenger,
    linked ? l10n.languageVersionLinked : l10n.languageVersionNotAllowed,
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final song = widget.song;
    final library = ref.watch(currentLibraryProvider);
    final songs = ref.watch(songsProvider((query: _query, tag: null)));
    final all = songs.value ?? const <SongListEntry>[];
    final self = [
      for (final s in all)
        if (s.id == song.id) s,
    ].firstOrNull;
    final candidates = [
      for (final s in all)
        if (s.id != song.id &&
            (song.workId == null || s.workId != song.workId) &&
            library.canEditSongBy(
              createdBy: s.createdBy,
              updatedBy: s.updatedBy,
            ))
          s,
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
    return Scaffold(
      appBar: AppBar(title: Text(l10n.languageVersionPickerTitle)),
      body: PageWidth(
        child: Column(
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
                value: songs,
                data: (_) => candidates.isEmpty
                    ? EmptyState(
                        icon: Icons.translate,
                        message: l10n.languageVersionPickerEmpty,
                      )
                    : ListView.builder(
                        itemCount: candidates.length,
                        itemBuilder: (context, i) => SongTile(
                          key: ValueKey(
                            'language-version-candidate-'
                            '${candidates[i].id}',
                          ),
                          song: candidates[i],
                          showLanguage: true,
                          onTap: () => Navigator.pop(context, candidates[i].id),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

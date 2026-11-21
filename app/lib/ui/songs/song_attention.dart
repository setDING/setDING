import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/band_view.dart';
import '../../data/database.dart' show SongConflict;
import '../../data/song_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../providers.dart';
import '../../sync/sync_controller.dart';
import 'chordpro_problems_badge.dart';

/// What makes a song need attention by someone who may edit it: the
/// lines of the overview's *To do* card (ADR-0045) and the filters of the
/// song list they open.
enum SongAttention {
  /// ChordPro that probably does not show as intended
  /// (`songs.chordpro_problems`, #314).
  problems,

  /// Places the editor offers to convert, e.g. CCLI directives or
  /// short-form section labels (`songs.chordpro_conversions`, #798). The
  /// song shows as intended; converting only tidies the source.
  conversions,

  /// Changed here and on the server, waiting for a decision (ADR-0004).
  conflicts,

  /// Sheet music (PDF) only, no ChordPro text.
  sheetMusicOnly,
}

/// Short name of [kind], e.g. for the filter chip of the song list.
String songAttentionLabel(AppLocalizations l10n, SongAttention kind) =>
    switch (kind) {
      SongAttention.problems => l10n.attentionProblems,
      SongAttention.conversions => l10n.attentionConversions,
      SongAttention.conflicts => l10n.attentionConflicts,
      SongAttention.sheetMusicOnly => l10n.attentionSheetMusicOnly,
    };

/// Icon of [kind], the same on the overview and in the song list.
Widget songAttentionIcon(
  BuildContext context,
  SongAttention kind, {
  double? size,
}) => switch (kind) {
  SongAttention.problems => Icon(
    Icons.warning_amber_rounded,
    size: size,
    color: chordProProblemColor(context),
  ),
  SongAttention.conversions => Icon(chordProConversionsIcon, size: size),
  SongAttention.conflicts => Icon(
    Icons.sync_problem,
    size: size,
    color: Theme.of(context).colorScheme.error,
  ),
  SongAttention.sheetMusicOnly => Icon(Icons.picture_as_pdf, size: size),
};

/// Whether [song] of [library] needs [kind] of attention by the signed-in
/// person. Only for people who may edit the song, the same check as the
/// song list's warning icon (ADR-0023); presentation only, the server
/// enforces every write.
bool needsAttention(
  SongAttention kind,
  SongListEntry song, {
  required LibraryView library,
  required Set<String> conflicts,
}) =>
    library.canEditSongBy(
      createdBy: song.createdBy,
      updatedBy: song.updatedBy,
    ) &&
    switch (kind) {
      SongAttention.problems => song.problems > 0,
      SongAttention.conversions => song.conversions > 0,
      SongAttention.conflicts => conflicts.contains(song.id),
      SongAttention.sheetMusicOnly => !song.hasChords,
    };

/// The songs with an open sync conflict.
final conflictSongIdsProvider = Provider<Set<String>>(
  (ref) => {
    for (final c
        in ref.watch(conflictsProvider).value ?? const <SongConflict>[])
      c.songId,
  },
);

/// The number of songs of the song list's library per [SongAttention] that
/// the signed-in person may edit; null while the songs load. Updates live,
/// e.g. during a sync.
final songAttentionCountsProvider =
    Provider.autoDispose<Map<SongAttention, int>?>((ref) {
      final songs = ref.watch(songsProvider((query: '', tag: null))).value;
      if (songs == null) return null;
      final library = ref.watch(currentLibraryProvider);
      final conflicts = ref.watch(conflictSongIdsProvider);
      return {
        for (final kind in SongAttention.values)
          kind: songs
              .where(
                (s) => needsAttention(
                  kind,
                  s,
                  library: library,
                  conflicts: conflicts,
                ),
              )
              .length,
      };
    });

/// The filter of the song list chosen on the overview, or null for all
/// songs. Kept outside the song list, so the overview can set it before
/// switching to the songs tab.
class SongAttentionFilterNotifier extends Notifier<SongAttention?> {
  @override
  SongAttention? build() => null;

  void select(SongAttention? kind) => state = kind;
}

final songAttentionFilterProvider =
    NotifierProvider<SongAttentionFilterNotifier, SongAttention?>(
      SongAttentionFilterNotifier.new,
    );

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../providers.dart';
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
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final songs = ref.watch(bandSongsProvider(_query));
    final currentBand = ref.watch(currentBandProvider);
    final band = ref.watch(arrangementBandProvider(currentBand.libraryId));
    final arrangements = band == null
        ? const <String, BandArrangement>{}
        : ref.watch(bandArrangementsProvider(band.id)).value ?? const {};
    final lastPlayed = widget.bandId == null
        ? null
        : ref.watch(lastPlayedProvider(widget.bandId!)).value;
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
              hintText: l10n.searchSongs,
              leading: const Icon(Icons.search),
              autoFocus: false,
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
        ),
      ),
      body: AsyncBody(
        value: songs,
        data: (list) => list.isEmpty
            ? EmptyState(
                icon: Icons.library_music_outlined,
                message: l10n.songsEmpty,
              )
            : ListView.builder(
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final song = list[i];
                  final index = _selected.indexOf(song.id);
                  return SongTile(
                    song: song,
                    arrangement: arrangements[song.id],
                    bandName: band?.name ?? '',
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
                },
              ),
      ),
    );
  }

  void _toggle(String id) => setState(() {
    if (!_selected.remove(id)) _selected.add(id);
  });
}

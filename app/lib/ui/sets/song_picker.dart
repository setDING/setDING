import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../providers.dart';
import '../songs/songs_screen.dart';
import '../widgets/dialogs.dart';

/// Lets the user select several songs. Returns their IDs in selection order.
Future<List<String>> pickSongs(BuildContext context) async =>
    await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const _SongPicker(),
      ),
    ) ??
    const [];

class _SongPicker extends ConsumerStatefulWidget {
  const _SongPicker();

  @override
  ConsumerState<_SongPicker> createState() => _SongPickerState();
}

class _SongPickerState extends ConsumerState<_SongPicker> {
  final _selected = <String>[];
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final songs = ref.watch(songsProvider((query: _query, tag: null)));
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.selectSongs),
        actions: [
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
                    leading: Checkbox(
                      value: index >= 0,
                      onChanged: (_) => _toggle(song.id),
                    ),
                    trailing: index >= 0
                        ? CircleAvatar(radius: 14, child: Text('${index + 1}'))
                        : const SizedBox.shrink(),
                    onTap: () => _toggle(song.id),
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../providers.dart';
import '../widgets/dialogs.dart';
import 'import_dialog.dart';
import 'song_editor_screen.dart';
import 'song_screen.dart';

/// Song library with search, creation and import.
class SongsScreen extends ConsumerStatefulWidget {
  const SongsScreen({super.key});

  @override
  ConsumerState<SongsScreen> createState() => _SongsScreenState();
}

class _SongsScreenState extends ConsumerState<SongsScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
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
    final songs = ref.watch(songsProvider(_query));
    final counts = ref.watch(attachmentCountsProvider).value ?? const {};

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navSongs),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SearchBar(
              controller: _search,
              hintText: l10n.searchSongs,
              leading: const Icon(Icons.search),
              trailing: [
                if (_query.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _search.clear();
                      setState(() => _query = '');
                    },
                  ),
              ],
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
        ),
        actions: [
          IconButton(
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
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => const SongEditorScreen()),
        ),
        icon: const Icon(Icons.add),
        label: Text(l10n.newSong),
      ),
      body: AsyncBody(
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
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => SongScreen(songId: list[i].id),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

/// List entry for a song.
class SongTile extends StatelessWidget {
  const SongTile({
    super.key,
    required this.song,
    this.hasAttachments = false,
    this.onTap,
    this.trailing,
    this.leading,
  });

  final SongEntry song;
  final bool hasAttachments;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final subtitle = [
      if (song.artist != null) song.artist!,
      if (song.songKey != null) song.songKey!,
    ].join(' · ');
    return ListTile(
      leading: leading,
      title: Text(song.title.isEmpty ? l10n.untitled : song.title),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      trailing:
          trailing ??
          (hasAttachments
              ? Tooltip(
                  message: l10n.attachmentsTooltip,
                  child: const Icon(Icons.picture_as_pdf_outlined),
                )
              : null),
      onTap: onTap,
    );
  }
}

import 'package:chordpro/chordpro.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../providers.dart';
import '../../settings/settings.dart';
import '../render/song_header.dart';
import '../render/song_view.dart';
import '../widgets/dialogs.dart';

const newSongTemplate = '''{title: }
{artist: }
{key: }

{start_of_verse}
[C]
{end_of_verse}

{start_of_chorus}
[F]
{end_of_chorus}
''';

/// Text editor for the ChordPro source with live preview (ADR-0003).
class SongEditorScreen extends ConsumerStatefulWidget {
  const SongEditorScreen({super.key, this.songId, this.initialSource});

  /// Null for a new song.
  final String? songId;
  final String? initialSource;

  @override
  ConsumerState<SongEditorScreen> createState() => _SongEditorScreenState();
}

class _SongEditorScreenState extends ConsumerState<SongEditorScreen> {
  late final TextEditingController _controller;
  late final String _original;
  late Song _preview;

  @override
  void initState() {
    super.initState();
    _original =
        widget.initialSource ?? (widget.songId == null ? newSongTemplate : '');
    _controller = TextEditingController(text: _original);
    _preview = parseChordPro(_original);
    _controller.addListener(
      () => setState(() => _preview = parseChordPro(_controller.text)),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _dirty => _controller.text != _original;

  Future<void> _save() async {
    final repo = ref.read(songRepositoryProvider);
    final source = _controller.text;
    if (widget.songId == null) {
      final id = await repo.createSong(
        source: source,
        title: AppLocalizations.of(context).untitled,
      );
      if (mounted) Navigator.pop(context, id);
    } else {
      await repo.updateSource(widget.songId!, source);
      if (mounted) Navigator.pop(context, widget.songId);
    }
  }

  void _insert(String before, [String after = '']) {
    final text = _controller.text;
    final sel = _controller.selection;
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    final selected = text.substring(start, end);
    final replacement = '$before$selected$after';
    _controller.value = TextEditingValue(
      text: text.replaceRange(start, end, replacement),
      selection: TextSelection.collapsed(
        offset: start + before.length + selected.length,
      ),
    );
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    final l10n = AppLocalizations.of(context);
    return confirm(
      context,
      title: l10n.discardChangesTitle,
      message: l10n.discardChangesMessage,
      action: l10n.discard,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 900;

    final editor = Column(
      children: [
        _Toolbar(onInsert: _insert),
        const Divider(height: 1),
        Expanded(
          child: TextField(
            controller: _controller,
            expands: true,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            textAlignVertical: TextAlignVertical.top,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 15,
              height: 1.4,
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(16),
            ),
          ),
        ),
      ],
    );
    final preview = _Preview(song: _preview);

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) Navigator.pop(context);
      },
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              widget.songId == null
                  ? l10n.editorTitleNew
                  : l10n.editorTitleEdit,
            ),
            actions: [
              IconButton(
                tooltip: l10n.save,
                icon: const Icon(Icons.check),
                onPressed: _save,
              ),
            ],
            bottom: wide
                ? null
                : TabBar(
                    tabs: [
                      Tab(text: l10n.editorTab),
                      Tab(text: l10n.previewTab),
                    ],
                  ),
          ),
          body: wide
              ? Row(
                  children: [
                    Expanded(child: editor),
                    const VerticalDivider(width: 1),
                    Expanded(child: preview),
                  ],
                )
              : TabBarView(
                  physics: const NeverScrollableScrollPhysics(),
                  children: [editor, preview],
                ),
        ),
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.onInsert});

  final void Function(String before, [String after]) onInsert;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Widget button(String label, VoidCallback onPressed) => Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(label: Text(label), onPressed: onPressed),
    );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          button('[ ]  ${l10n.insertChord}', () => onInsert('[', ']')),
          button(
            l10n.insertVerse,
            () => onInsert('{start_of_verse}\n', '\n{end_of_verse}\n'),
          ),
          button(
            l10n.insertChorus,
            () => onInsert('{start_of_chorus}\n', '\n{end_of_chorus}\n'),
          ),
          button(
            l10n.insertBridge,
            () => onInsert('{start_of_bridge}\n', '\n{end_of_bridge}\n'),
          ),
          button(l10n.insertComment, () => onInsert('{comment: ', '}\n')),
        ],
      ),
    );
  }
}

class _Preview extends ConsumerWidget {
  const _Preview({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final formatter = ChordFormatter.forSong(song, notation: settings.notation);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SongHeader(
            title: song.title ?? AppLocalizations.of(context).untitled,
            artist: song.artist,
            song: song,
            formatter: formatter,
          ),
          const SizedBox(height: 16),
          SongBody(
            song: song,
            options: SongRenderOptions(
              formatter: formatter,
              fontSize: settings.fontSize,
            ),
          ),
        ],
      ),
    );
  }
}

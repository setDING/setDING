import 'dart:async';

import 'package:chordpro/chordpro.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../providers.dart';
import '../../settings/settings.dart';
import '../render/song_header.dart';
import '../render/song_view.dart';
import '../widgets/dialogs.dart';
import '../widgets/sequence_dialog.dart';
import 'chordpro_editing_controller.dart';
import 'editor_autocomplete.dart';
import 'editor_toolbar.dart';
import 'line_number_gutter.dart';
import 'song_details_dialog.dart';

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

/// Font of the ChordPro editor and its line numbers.
const editorTextStyle = TextStyle(
  fontFamily: 'monospace',
  fontSize: 15,
  height: 1.4,
);

/// Text editor for the ChordPro source with live preview (ADR-0003).
/// Delay before the preview follows the text.
const editorPreviewDelay = Duration(milliseconds: 200);

class SongEditorScreen extends ConsumerStatefulWidget {
  const SongEditorScreen({super.key, this.songId, this.initialSource});

  /// Null for a new song.
  final String? songId;
  final String? initialSource;

  @override
  ConsumerState<SongEditorScreen> createState() => _SongEditorScreenState();
}

class _SongEditorScreenState extends ConsumerState<SongEditorScreen> {
  late final ChordProEditingController _controller;
  late final String _original;
  late Song _preview;
  final _focus = FocusNode();
  final _fieldKey = GlobalKey();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _original =
        widget.initialSource ?? (widget.songId == null ? newSongTemplate : '');
    _controller = ChordProEditingController(text: _original);
    _preview = _parse(_original);
    _previewSource = _original;
    _controller.addListener(_onChanged);
  }

  /// Source of [_preview].
  late String _previewSource;
  Timer? _previewDebounce;

  /// The controller also notifies on cursor and selection moves; the
  /// preview is parsed again only when the text changed, shortly after the
  /// last keystroke.
  void _onChanged() {
    if (_controller.text == _previewSource) {
      _previewDebounce?.cancel();
      return;
    }
    _previewDebounce?.cancel();
    _previewDebounce = Timer(editorPreviewDelay, () {
      if (!mounted) return;
      final source = _controller.text;
      setState(() {
        _previewSource = source;
        _preview = _parse(source);
      });
    });
  }

  Song _parse(String source) =>
      parseChordPro(source, selectors: ref.read(settingsProvider).selectors);

  @override
  void dispose() {
    _previewDebounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  bool get _dirty => _controller.text != _original;

  Future<void> _save() async {
    final repo = ref.read(songRepositoryProvider);
    final source = _controller.text;
    final problems = validateChordPro(source, tokens: _controller.tokens);
    if (problems.isNotEmpty && !await _confirmProblems(problems)) return;
    if (!mounted) return;
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

  /// Warns about problems in the source (#109). Returns whether to save
  /// anyway; otherwise the first problem is selected in the editor.
  Future<bool> _confirmProblems(List<ChordProProblem> problems) async {
    final l10n = AppLocalizations.of(context);
    const shown = 5;
    String describe(ChordProProblem p) => switch (p.kind) {
      ChordProProblemKind.unclosedDirective => l10n.problemUnclosedDirective(
        p.line,
      ),
      ChordProProblemKind.unclosedChord => l10n.problemUnclosedChord(p.line),
      ChordProProblemKind.unclosedEnvironment =>
        l10n.problemUnclosedEnvironment(p.line),
    };
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_amber),
        title: Text(l10n.invalidChordProTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.invalidChordProMessage),
            const SizedBox(height: 8),
            for (final p in problems.take(shown)) Text('• ${describe(p)}'),
            if (problems.length > shown)
              Text(l10n.moreProblems(problems.length - shown)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.saveAnyway),
          ),
          FilledButton(
            autofocus: true,
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.keepEditing),
          ),
        ],
      ),
    );
    if (save ?? false) return true;
    if (mounted) {
      final first = problems.first;
      _controller.selection = TextSelection(
        baseOffset: first.start,
        extentOffset: first.end,
      );
      _focus.requestFocus();
    }
    return false;
  }

  /// Inserts [snippet] around the selection. A metadata directive that
  /// already exists is selected instead of being inserted again.
  void _insert(EditorSnippet snippet) {
    if (snippet.meta == 'x_sequence') {
      _editSequence();
      return;
    }
    final text = _controller.text;
    if (snippet.meta case final name?) {
      final existing = RegExp(
        '^\\{\\s*${RegExp.escape(name)}\\s*:\\s*([^}]*)\\}',
        multiLine: true,
      ).firstMatch(text);
      if (existing != null) {
        final valueStart = existing.end - 1 - existing.group(1)!.length;
        _controller.selection = TextSelection(
          baseOffset: valueStart,
          extentOffset: existing.end - 1,
        );
        _focus.requestFocus();
        return;
      }
      _insertMeta(snippet.before, snippet.after);
      _focus.requestFocus();
      return;
    }
    final sel = _controller.selection;
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    final selected = text.substring(start, end);
    var before = snippet.before;
    var after = snippet.after;
    if (snippet.block) {
      // Blocks start on a line of their own.
      if (start > 0 && text[start - 1] != '\n') before = '\n$before';
      if (selected.endsWith('\n') && after.startsWith('\n')) {
        after = after.substring(1);
      }
      // No empty line after the block when a line break follows anyway.
      if (after.endsWith('\n') && end < text.length && text[end] == '\n') {
        after = after.substring(0, after.length - 1);
      } else if (after.isEmpty &&
          before.endsWith('\n') &&
          end < text.length &&
          text[end] == '\n') {
        before = before.substring(0, before.length - 1);
      }
    }
    _controller.value = TextEditingValue(
      text: text.replaceRange(start, end, '$before$selected$after'),
      selection: TextSelection.collapsed(
        offset: start + before.length + selected.length,
      ),
    );
    _focus.requestFocus();
  }

  /// Inserts a metadata directive at the end of the header (the directive
  /// lines at the top of the file), independent of the cursor; the cursor
  /// ends up after [before].
  void _insertMeta(String before, String after) {
    final text = _controller.text;
    final pos = metadataHeaderEnd(text);
    final prefix = pos > 0 && text[pos - 1] != '\n' ? '\n' : '';
    _controller.value = TextEditingValue(
      text: text.replaceRange(pos, pos, '$prefix$before$after'),
      selection: TextSelection.collapsed(
        offset: pos + prefix.length + before.length,
      ),
    );
  }

  /// Edits title, key, tempo and more in a form instead of the text (#189).
  Future<void> _editDetails() async {
    final before = _controller.text;
    final source = await editSongDetails(
      context,
      before,
      notation: ref.read(settingsProvider).notation,
    );
    if (source == null || !mounted) return;
    if (source != before && _controller.text == before) {
      final sel = _controller.selection;
      final offset = sel.isValid ? sel.baseOffset : source.length;
      _controller.value = TextEditingValue(
        text: source,
        selection: TextSelection.collapsed(
          offset: offset.clamp(0, source.length),
        ),
      );
    }
    _focus.requestFocus();
  }

  static final _sequenceLine = RegExp(
    r'^[ \t]*\{[ \t]*x_sequence[ \t]*:[^}\n]*\}[ \t]*(\n|$)',
    multiLine: true,
  );

  /// Builds `{x_sequence}` from the parts of the song by tapping them.
  Future<void> _editSequence() async {
    final l10n = AppLocalizations.of(context);
    final choice = await editSequence(
      context,
      title: l10n.sequenceLabel,
      parts: songParts(_preview),
      initial: findSequence(_controller.text),
    );
    if (choice == null) return;
    final text = _controller.text;
    final value = choice.value;
    final existing = _sequenceLine.firstMatch(text);
    if (existing != null) {
      final line = value == null ? '' : '{x_sequence: $value}\n';
      _controller.value = TextEditingValue(
        text: text.replaceRange(existing.start, existing.end, line),
        selection: TextSelection.collapsed(
          offset: existing.start + line.length,
        ),
      );
    } else if (value != null) {
      _insertMeta('{x_sequence: $value', '}\n');
    }
    _focus.requestFocus();
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
    final snippets = EditorSnippets(l10n);

    final editor = Column(
      children: [
        EditorToolbar(
          snippets: snippets,
          onInsert: _insert,
          onDetails: _editDetails,
        ),
        const Divider(height: 1),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LineNumberGutter(
                fieldKey: _fieldKey,
                controller: _controller,
                scrollController: _scroll,
                style: editorTextStyle,
              ),
              Expanded(
                child: EditorAutocomplete(
                  controller: _controller,
                  focusNode: _focus,
                  fieldKey: _fieldKey,
                  child: TextField(
                    key: _fieldKey,
                    focusNode: _focus,
                    controller: _controller,
                    scrollController: _scroll,
                    expands: true,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    textAlignVertical: TextAlignVertical.top,
                    style: editorTextStyle,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.fromLTRB(4, 16, 16, 16),
                    ),
                  ),
                ),
              ),
            ],
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
      child: CallbackShortcuts(
        bindings: {
          saveShortcut: _save,
          for (final snippet in snippets.withShortcut)
            snippet.shortcut!: () => _insert(snippet),
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
                    crossAxisAlignment: CrossAxisAlignment.stretch,
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
      ),
    );
  }
}

class _Preview extends ConsumerWidget {
  const _Preview({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (notation, fontSize) = ref.watch(
      settingsProvider.select((s) => (s.notation, s.fontSize)),
    );
    final formatter = ChordFormatter.forSong(song, notation: notation);
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
              fontSize: fontSize,
            ),
          ),
        ],
      ),
    );
  }
}

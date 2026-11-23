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
import '../widgets/docs_link.dart';
import '../widgets/sequence_dialog.dart';
import 'auto_close_formatter.dart';
import 'chordpro_editing_controller.dart';
import 'editor_autocomplete.dart';
import 'editor_search.dart';
import 'editor_toolbar.dart';
import 'line_number_gutter.dart';
import 'section_backgrounds.dart';
import 'selection_drag.dart';
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

/// Choice in the dialog about problems in the source.
enum _ProblemAction { save, fix, edit }

class SongEditorScreen extends ConsumerStatefulWidget {
  const SongEditorScreen({
    super.key,
    this.songId,
    this.initialSource,
    this.selectFirstProblem = false,
  });

  /// From this width on, the editor and the preview are side by side.
  static const sideBySideWidth = 900.0;

  /// Null for a new song.
  final String? songId;
  final String? initialSource;

  /// Select the first ChordPro problem when the editor opens (#314).
  final bool selectFirstProblem;

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
  final _undo = UndoHistoryController();

  @override
  void initState() {
    super.initState();
    _original =
        widget.initialSource ?? (widget.songId == null ? newSongTemplate : '');
    _controller = ChordProEditingController(text: _original);
    _preview = _parse(_original);
    _previewSource = _original;
    _controller.addListener(_onChanged);
    if (widget.selectFirstProblem) {
      final first = validateChordPro(_original).firstOrNull;
      if (first != null) {
        _controller.selection = TextSelection(
          baseOffset: first.start,
          extentOffset: first.end,
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _focus.requestFocus();
        });
      }
    }
  }

  /// Source of [_preview].
  late String _previewSource;
  Timer? _previewDebounce;

  /// The controller also notifies on cursor and selection moves; the
  /// preview is parsed again only when the text changed, shortly after the
  /// last keystroke.
  void _onChanged() {
    _unsaved.value = _dirty;
    _checkPaste();
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

  /// Text before the last change, to recognise pasted text.
  late String _lastText = _original;

  /// Offers to convert pasted chords-over-lyrics text to ChordPro (#362).
  void _checkPaste() {
    final before = _lastText;
    final after = _controller.text;
    if (after == before) return;
    _lastText = after;
    if (after.length - before.length < 8) return;
    var prefix = 0;
    final shorter = before.length;
    while (prefix < shorter && before[prefix] == after[prefix]) {
      prefix++;
    }
    var suffix = 0;
    while (suffix < shorter - prefix &&
        before[before.length - 1 - suffix] ==
            after[after.length - 1 - suffix]) {
      suffix++;
    }
    final inserted = after.substring(prefix, after.length - suffix);
    if (!inserted.contains('\n') || !looksLikeChordsOverLyrics(inserted)) {
      return;
    }
    final start = prefix;
    final end = after.length - suffix;
    final l10n = AppLocalizations.of(context);
    showMessageWithAction(
      context,
      l10n.pastedChordsOverLyrics,
      actionLabel: l10n.convert,
      onAction: () {
        // Only if the text is still as pasted.
        if (!mounted || _controller.text != after) return;
        final edit = convertChordsOverLyricsIn(after, start, end);
        if (edit == null) return;
        _controller.value = TextEditingValue(
          text: edit.text,
          selection: TextSelection(
            baseOffset: edit.base,
            extentOffset: edit.extent,
          ),
        );
      },
    );
  }

  Song _parse(String source) =>
      parseChordPro(source, selectors: ref.read(settingsProvider).selectors);

  @override
  void dispose() {
    _previewDebounce?.cancel();
    _controller.dispose();
    _unsaved.dispose();
    _focus.dispose();
    _scroll.dispose();
    _undo.dispose();
    super.dispose();
  }

  bool get _dirty => _controller.text != _original;

  /// [_dirty] for the save button; notifies only when it flips, not on
  /// every controller notification (cursor, search matches).
  final _unsaved = ValueNotifier(false);

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
      ChordProProblemKind.textAfterDirective => l10n.problemTextAfterDirective(
        p.line,
      ),
      ChordProProblemKind.invalidKey => l10n.problemInvalidKey(p.line),
    };
    final fixable = problems.any(canFixChordProProblem);
    final action = await showDialog<_ProblemAction>(
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
            onPressed: () => Navigator.pop(context, _ProblemAction.save),
            child: Text(l10n.saveAnyway),
          ),
          if (fixable)
            TextButton(
              onPressed: () => Navigator.pop(context, _ProblemAction.fix),
              child: Text(l10n.fixProblems),
            ),
          FilledButton(
            autofocus: true,
            onPressed: () => Navigator.pop(context, _ProblemAction.edit),
            child: Text(l10n.keepEditing),
          ),
        ],
      ),
    );
    if (action == _ProblemAction.save) return true;
    if (action == _ProblemAction.fix && mounted) {
      // Fixes what can be fixed and stays in the editor, so the author
      // sees the result in the text and the preview before saving (#309).
      final text = _controller.text;
      final fixed = fixChordProProblems(text);
      final first = problems.firstWhere(canFixChordProProblem);
      final lineStart = text.lastIndexOf('\n', first.start) + 1;
      _controller.value = TextEditingValue(
        text: fixed,
        selection: TextSelection.collapsed(offset: lineStart),
      );
      _focus.requestFocus();
      return false;
    }
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
    var start = sel.isValid ? sel.start : text.length;
    var end = sel.isValid ? sel.end : text.length;
    // A section wraps the whole lines the selection touches (#756).
    if (snippet.block &&
        end > start &&
        snippet.before.startsWith('{start_of_')) {
      if (text[end - 1] == '\n') end--;
      start = start == 0 ? 0 : text.lastIndexOf('\n', start - 1) + 1;
      final nl = text.indexOf('\n', end);
      end = end > start ? (nl < 0 ? text.length : nl) : end;
    }
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

  bool _searching = false;
  bool _replacing = false;
  bool _caseSensitive = false;

  /// Recreates the search bar, so Ctrl+F in an open bar takes the new
  /// selection and focuses the field again.
  int _searchGeneration = 0;

  /// Opens the search bar (#368), with the selected text of one line as
  /// the search text.
  void _openSearch({bool replace = false}) {
    setState(() {
      _searching = true;
      _replacing = replace;
      _searchGeneration++;
    });
  }

  void _closeSearch() {
    _controller.setSearchMatches(const [], null);
    setState(() => _searching = false);
    _focus.requestFocus();
  }

  String get _selectedQuery {
    final sel = _controller.selection;
    if (!sel.isValid || sel.isCollapsed) return '';
    final selected = sel.textInside(_controller.text);
    return selected.contains('\n') ? '' : selected;
  }

  /// Moves the cursor to the source of [tap] in the preview (#372): its
  /// line and, where known, the tapped character (#381). The preview may
  /// lag a moment behind the text; the position is then clamped.
  void _jumpToSource(SourceTap tap) {
    final line = sourceLineOf(tap.element);
    if (line == null) return;
    final text = _controller.text;
    var offset = 0;
    for (var i = 0; i < line; i++) {
      final nl = text.indexOf('\n', offset);
      if (nl < 0) break;
      offset = nl + 1;
    }
    if (tap.textIndex case final index?) {
      final lineEnd = text.indexOf('\n', offset);
      final source = text.substring(
        offset,
        lineEnd < 0 ? text.length : lineEnd,
      );
      offset += sourceColumn(source, index, atChord: tap.onChord);
    }
    // After the next frame, when on narrow screens the editor tab is
    // built again; with the focus, the editor scrolls to the cursor.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focus.requestFocus();
      _controller.selection = TextSelection.collapsed(
        offset: offset.clamp(0, _controller.text.length),
      );
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  /// Runs a line or chord command on the selection (#361).
  void _command(EditorCommand command) {
    final text = _controller.text;
    final sel = _controller.selection;
    final base = sel.isValid ? sel.baseOffset : text.length;
    final extent = sel.isValid ? sel.extentOffset : text.length;
    final edit = switch (command) {
      EditorCommand.moveLinesUp => moveLines(text, base, extent, up: true),
      EditorCommand.moveLinesDown => moveLines(text, base, extent, up: false),
      EditorCommand.moveChordLeft => moveChords(
        text,
        base,
        extent,
        right: false,
        tokens: _controller.tokens,
      ),
      EditorCommand.moveChordRight => moveChords(
        text,
        base,
        extent,
        right: true,
        tokens: _controller.tokens,
      ),
      EditorCommand.duplicateLines => duplicateLines(text, base, extent),
      EditorCommand.deleteLines => deleteLines(text, base, extent),
      EditorCommand.toggleComment => toggleComment(text, base, extent),
      EditorCommand.convertChordsOverLyrics => convertChordsOverLyricsIn(
        text,
        base,
        extent,
      ),
      EditorCommand.convertCcliGrids => convertCcliGridsIn(text, base, extent),
      EditorCommand.convertCommentHeadings => convertCommentHeadingsIn(
        text,
        base,
        extent,
      ),
    };
    if (edit != null) {
      _controller.value = TextEditingValue(
        text: edit.text,
        selection: TextSelection(
          baseOffset: edit.base,
          extentOffset: edit.extent,
        ),
      );
    }
    _focus.requestFocus();
  }

  /// Hint on CCLI bar lines hidden by the author for this editor (#481).
  bool _ccliHintHidden = false;

  /// Converts all CCLI bar lines to grid sections (#481).
  void _convertCcliGrids() {
    final text = _controller.text;
    final edit = convertCcliGridsIn(text, 0, 0);
    if (edit == null) return;
    _controller.value = TextEditingValue(
      text: edit.text,
      selection: TextSelection.collapsed(offset: edit.base),
    );
    _focus.requestFocus();
  }

  /// Hint on comment headings hidden by the author for this editor (#963).
  bool _headingHintHidden = false;

  /// Converts all comment headings to section environments (#963); the
  /// cursor moves to the first converted section.
  void _convertCommentHeadings() {
    final edit = convertCommentHeadingsIn(_controller.text, 0, 0);
    if (edit == null) return;
    _controller.value = TextEditingValue(
      text: edit.text,
      selection: TextSelection.collapsed(offset: edit.base),
    );
    _focus.requestFocus();
  }

  /// Hint on the CCLI footer hidden by the author for this editor (#785).
  bool _footerHintHidden = false;

  /// Removes the CCLI footers and keeps song number and copyright as
  /// metadata (#785);
  /// the cursor stays where it was, as far as the text allows.
  void _removeCcliFooters() {
    final text = _controller.text;
    final cleaned = removeCcliFooters(text);
    if (cleaned == text) return;
    final sel = _controller.selection;
    final offset = sel.isValid ? sel.baseOffset : 0;
    _controller.value = TextEditingValue(
      text: cleaned,
      selection: TextSelection.collapsed(
        offset: offset.clamp(0, cleaned.length),
      ),
    );
    _focus.requestFocus();
  }

  /// Hint on short-form section labels hidden by the author (#672).
  bool _labelHintHidden = false;

  /// Converts all section labels to the attribute form (#672); the cursor
  /// stays on its line.
  void _convertLegacyLabels() {
    final text = _controller.text;
    final converted = convertLegacySectionLabels(text);
    if (converted == text) return;
    final sel = _controller.selection;
    final offset = sel.isValid ? sel.baseOffset : 0;
    final lineStart = offset <= 0 ? 0 : text.lastIndexOf('\n', offset - 1) + 1;
    _controller.value = TextEditingValue(
      text: converted,
      selection: TextSelection.collapsed(
        offset: lineStart.clamp(0, converted.length),
      ),
    );
    _focus.requestFocus();
  }

  /// Hint on SongSelect directives hidden by the author (#777).
  bool _songSelectHintHidden = false;

  /// Makes the SongSelect directives standard-conforming (#777); the
  /// cursor stays on its line.
  void _convertSongSelectDirectives() {
    final text = _controller.text;
    final converted = normalizeSongSelectDirectives(text);
    if (converted == text) return;
    final sel = _controller.selection;
    final offset = sel.isValid ? sel.baseOffset : 0;
    final lineStart = offset <= 0 ? 0 : text.lastIndexOf('\n', offset - 1) + 1;
    _controller.value = TextEditingValue(
      text: converted,
      selection: TextSelection.collapsed(
        offset: lineStart.clamp(0, converted.length),
      ),
    );
    _focus.requestFocus();
  }

  /// Edits title, key, tempo and more in a form instead of the text (#189).
  Future<void> _editDetails() async {
    final before = _controller.text;
    final source = await editSongDetails(
      context,
      before,
      notation: ref.read(settingsProvider).notation,
      parts: songParts(_parse(before)),
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
    final wide =
        MediaQuery.sizeOf(context).width >= SongEditorScreen.sideBySideWidth;
    final snippets = EditorSnippets(l10n);
    final typingAids = ref.watch(
      settingsProvider.select((s) => s.editorTypingAids),
    );

    final editor = Column(
      children: [
        EditorToolbar(
          snippets: snippets,
          onInsert: _insert,
          onDetails: _editDetails,
          onCommand: _command,
          undoController: _undo,
          onSearch: _openSearch,
        ),
        const Divider(height: 1),
        if (_searching) ...[
          EditorSearchBar(
            key: ValueKey(_searchGeneration),
            controller: _controller,
            fieldKey: _fieldKey,
            scrollController: _scroll,
            initialQuery: _selectedQuery,
            replace: _replacing,
            caseSensitive: _caseSensitive,
            onCaseSensitiveChanged: (value) => _caseSensitive = value,
            onClose: _closeSearch,
          ),
          const Divider(height: 1),
        ],
        if (!_ccliHintHidden)
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              final count = _controller.ccliGrids.length;
              if (count == 0) return const SizedBox.shrink();
              return CcliGridHint(
                count: count,
                onConvert: () => _convertCcliGrids(),
                onHide: () => setState(() => _ccliHintHidden = true),
              );
            },
          ),
        if (!_footerHintHidden)
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              if (_controller.ccliFooters.isEmpty) {
                return const SizedBox.shrink();
              }
              return CcliFooterHint(
                onRemove: _removeCcliFooters,
                onHide: () => setState(() => _footerHintHidden = true),
              );
            },
          ),
        if (!_headingHintHidden)
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              final count = _controller.commentHeadings.length;
              if (count == 0) return const SizedBox.shrink();
              return CommentHeadingHint(
                count: count,
                onConvert: _convertCommentHeadings,
                onHide: () => setState(() => _headingHintHidden = true),
              );
            },
          ),
        if (!_labelHintHidden)
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              final count = _controller.legacyLabels.length;
              if (count == 0) return const SizedBox.shrink();
              return LegacyLabelHint(
                count: count,
                onConvert: _convertLegacyLabels,
                onHide: () => setState(() => _labelHintHidden = true),
              );
            },
          ),
        if (!_songSelectHintHidden)
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              final count = _controller.songSelectDirectives;
              if (count == 0) return const SizedBox.shrink();
              return SongSelectDirectiveHint(
                count: count,
                onConvert: _convertSongSelectDirectives,
                onHide: () => setState(() => _songSelectHintHidden = true),
              );
            },
          ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LineNumberGutter(
                fieldKey: _fieldKey,
                controller: _controller,
                scrollController: _scroll,
                style: editorTextStyle,
                focusNode: _focus,
              ),
              Expanded(
                child: EditorAutocomplete(
                  typingAids: typingAids,
                  controller: _controller,
                  focusNode: _focus,
                  fieldKey: _fieldKey,
                  child: SectionBackgrounds(
                    fieldKey: _fieldKey,
                    controller: _controller,
                    scrollController: _scroll,
                    child: SelectionDragDrop(
                      fieldKey: _fieldKey,
                      controller: _controller,
                      scrollController: _scroll,
                      focusNode: _focus,
                      child: TextField(
                        key: _fieldKey,
                        focusNode: _focus,
                        controller: _controller,
                        scrollController: _scroll,
                        undoController: _undo,
                        expands: true,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        inputFormatters: [
                          if (typingAids) const AutoCloseFormatter(),
                        ],
                        textAlignVertical: TextAlignVertical.top,
                        style: editorTextStyle,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.fromLTRB(4, 16, 16, 16),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
    final preview = _Preview(song: _preview, onTap: _jumpToSource);

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) Navigator.pop(context);
      },
      child: CallbackShortcuts(
        bindings: {
          saveShortcut: _save,
          searchShortcut: _openSearch,
          replaceShortcut: () => _openSearch(replace: true),
          for (final snippet in snippets.withShortcut)
            snippet.shortcut!: () => _insert(snippet),
          for (final command in EditorCommand.values)
            ?command.activator: () => _command(command),
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
                // The ChordPro syntax and the editor's aids (#993).
                DocsHelpButton(
                  key: const ValueKey('editor-docs'),
                  page: DocsPage.editor,
                  topic: l10n.editorDocsTopic,
                ),
                _SaveButton(unsaved: _unsaved, wide: wide, onPressed: _save),
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
            // Esc leaves the editor like the back button, so unsaved changes
            // still ask (#749). The text field swallows Esc before
            // `EscapeGoesBack` sees it: it only hides its toolbar and
            // otherwise hands the `DismissIntent` up to here. Inside the
            // Scaffold, whose drawer action would stop it otherwise.
            // Autocomplete and search see Esc first and close themselves.
            body: Actions(
              actions: {
                DismissIntent: CallbackAction<DismissIntent>(
                  onInvoke: (_) => Navigator.maybePop(context),
                ),
              },
              child: wide
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
      ),
    );
  }
}

class _Preview extends ConsumerWidget {
  const _Preview({required this.song, required this.onTap});

  final Song song;

  /// A line or section was tapped: the editor shows its source.
  final ValueChanged<SourceTap> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (notation, fontSize, style, superscript) = ref.watch(
      settingsProvider.select(
        (s) => (s.notation, s.fontSize, s.chordStyle, s.chordSuperscript),
      ),
    );
    final formatter = ChordFormatter.forSong(
      song,
      notation: notation,
      style: style,
      superscript: superscript,
    );
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
              onElementTap: (tap) {
                // On narrow screens, switch to the editor tab first.
                DefaultTabController.maybeOf(context)?.index = 0;
                onTap(tap);
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Hint above the editor that the song has CCLI bar lines that can be
/// converted to grid sections (#481).
class CcliGridHint extends StatelessWidget {
  const CcliGridHint({
    super.key,
    required this.count,
    required this.onConvert,
    required this.onHide,
  });

  final int count;
  final VoidCallback onConvert;
  final VoidCallback onHide;

  @override
  Widget build(BuildContext context) => _ConvertHint(
    icon: Icons.grid_on,
    message: AppLocalizations.of(context).ccliGridsHint(count),
    onConvert: onConvert,
    onHide: onHide,
  );
}

/// Hint above the editor that the song ends with the CCLI footer of
/// SongSelect, which would be shown as lyrics (#785).
class CcliFooterHint extends StatelessWidget {
  const CcliFooterHint({
    super.key,
    required this.onRemove,
    required this.onHide,
  });

  final VoidCallback onRemove;
  final VoidCallback onHide;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _ConvertHint(
      icon: Icons.copyright,
      message: l10n.ccliFooterHint,
      action: l10n.remove,
      onConvert: onRemove,
      onHide: onHide,
    );
  }
}

/// Hint above the editor that section labels are in the short form
/// `{start_of_verse: Verse 1}` and can be converted to the attribute form
/// the ChordPro specification recommends (#672).
class LegacyLabelHint extends StatelessWidget {
  const LegacyLabelHint({
    super.key,
    required this.count,
    required this.onConvert,
    required this.onHide,
  });

  final int count;
  final VoidCallback onConvert;
  final VoidCallback onHide;

  @override
  Widget build(BuildContext context) => _ConvertHint(
    icon: Icons.label_outline,
    message: AppLocalizations.of(context).legacyLabelsHint(count),
    onConvert: onConvert,
    onHide: onHide,
  );
}

/// Hint above the editor that sections are marked with comment headings
/// such as `{comment: Verse 1}` (SongSelect) and can become section
/// environments (#963).
class CommentHeadingHint extends StatelessWidget {
  const CommentHeadingHint({
    super.key,
    required this.count,
    required this.onConvert,
    required this.onHide,
  });

  final int count;
  final VoidCallback onConvert;
  final VoidCallback onHide;

  @override
  Widget build(BuildContext context) => _ConvertHint(
    icon: Icons.view_agenda_outlined,
    message: AppLocalizations.of(context).commentHeadingsHint(count),
    onConvert: onConvert,
    onHide: onHide,
  );
}

/// Hint above the editor that the song has the SongSelect directives
/// `{ccli}` and `{ccli_license}`, which the ChordPro specification does not
/// define (#777): converting renames `{ccli}` to `{x_ccli}` and removes
/// `{ccli_license}`, as the import does.
class SongSelectDirectiveHint extends StatelessWidget {
  const SongSelectDirectiveHint({
    super.key,
    required this.count,
    required this.onConvert,
    required this.onHide,
  });

  final int count;
  final VoidCallback onConvert;
  final VoidCallback onHide;

  @override
  Widget build(BuildContext context) => _ConvertHint(
    icon: Icons.rule,
    message: AppLocalizations.of(context).songSelectDirectivesHint(count),
    onConvert: onConvert,
    onHide: onHide,
  );
}

/// A hint above the editor with a conversion and a button to hide it.
class _ConvertHint extends StatelessWidget {
  const _ConvertHint({
    required this.icon,
    required this.message,
    this.action,
    required this.onConvert,
    required this.onHide,
  });

  final IconData icon;
  final String message;

  /// Label of the action button; "Convert" by default.
  final String? action;
  final VoidCallback onConvert;
  final VoidCallback onHide;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
        child: Row(
          children: [
            Icon(icon, size: 20, color: scheme.onTertiaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: scheme.onTertiaryContainer),
              ),
            ),
            TextButton(
              onPressed: onConvert,
              child: Text(action ?? l10n.convert),
            ),
            IconButton(
              tooltip: l10n.hideHint,
              icon: const Icon(Icons.close),
              color: scheme.onTertiaryContainer,
              onPressed: onHide,
            ),
          ],
        ),
      ),
    );
  }
}

/// The save button in the app bar (#748): with a label on wide screens, a
/// round icon button on narrow ones. Tonal while nothing changed, filled in
/// the primary colour as soon as there are unsaved changes. Listens to
/// [unsaved] itself, so a keystroke does not rebuild the whole editor.
class _SaveButton extends StatelessWidget {
  const _SaveButton({
    required this.unsaved,
    required this.wide,
    required this.onPressed,
  });

  final ValueNotifier<bool> unsaved;
  final bool wide;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ValueListenableBuilder<bool>(
      valueListenable: unsaved,
      builder: (context, dirty, _) {
        const icon = Icon(Icons.check);
        if (!wide) {
          return dirty
              ? IconButton.filled(
                  key: const ValueKey('editor-save'),
                  tooltip: l10n.save,
                  icon: icon,
                  onPressed: onPressed,
                )
              : IconButton.filledTonal(
                  key: const ValueKey('editor-save'),
                  tooltip: l10n.save,
                  icon: icon,
                  onPressed: onPressed,
                );
        }
        final label = Text(l10n.save);
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Tooltip(
            message: l10n.save,
            child: dirty
                ? FilledButton.icon(
                    key: const ValueKey('editor-save'),
                    onPressed: onPressed,
                    icon: icon,
                    label: label,
                  )
                : FilledButton.tonalIcon(
                    key: const ValueKey('editor-save'),
                    onPressed: onPressed,
                    icon: icon,
                    label: label,
                  ),
          ),
        );
      },
    );
  }
}

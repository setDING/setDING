import 'package:chordpro/chordpro.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../../l10n/generated/app_localizations.dart';
import 'chordpro_editing_controller.dart';
import 'line_number_gutter.dart';

/// Search bar of the ChordPro editor (#368): highlights all matches in the
/// source, selects the current one and scrolls it into view. Enter goes to
/// the next match, Shift+Enter to the previous one, Esc closes the bar.
class EditorSearchBar extends StatefulWidget {
  const EditorSearchBar({
    super.key,
    required this.controller,
    required this.fieldKey,
    required this.scrollController,
    required this.onClose,
    this.initialQuery = '',
  });

  final ChordProEditingController controller;

  /// Key of the editor's [TextField], to scroll a match into view.
  final GlobalKey fieldKey;
  final ScrollController scrollController;

  /// Closes the bar; the current match stays selected in the editor.
  final VoidCallback onClose;

  /// Search text when the bar opens, e.g. the selected text.
  final String initialQuery;

  @override
  State<EditorSearchBar> createState() => _EditorSearchBarState();
}

class _EditorSearchBarState extends State<EditorSearchBar> {
  late final _query = TextEditingController(text: widget.initialQuery);
  final _focus = FocusNode();
  List<(int, int)> _matches = const [];
  int? _current;
  String? _searchedText;
  String? _searchedQuery;

  @override
  void initState() {
    super.initState();
    _query.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _query.text.length,
    );
    widget.controller.addListener(_update);
    _query.addListener(_onQuery);
    _update(rebuild: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    // The editor clears the highlighting in onClose; its controller may
    // already be disposed here.
    widget.controller.removeListener(_update);
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onQuery() {
    if (_query.text == _searchedQuery) return;
    _update();
    // While typing, jump to the first match at or after the cursor.
    if (_current != null) _select(_current!);
  }

  /// Searches again when the text or the query changed; the current match
  /// is the first one at or after the cursor.
  void _update({bool rebuild = true}) {
    final text = widget.controller.text;
    final query = _query.text;
    if (text == _searchedText && query == _searchedQuery) return;
    _searchedText = text;
    _searchedQuery = query;
    final matches = findInSource(text, query);
    final sel = widget.controller.selection;
    final from = sel.isValid ? sel.start : 0;
    final index = matches.indexWhere((m) => m.$1 >= from);
    _matches = matches;
    _current = matches.isEmpty ? null : (index < 0 ? 0 : index);
    if (rebuild) setState(() {});
    widget.controller.setSearchMatches(matches, _current);
  }

  void _step(int delta) {
    if (_matches.isEmpty) return;
    final current = _current;
    _select(current == null ? 0 : (current + delta) % _matches.length);
  }

  void _select(int index) {
    final (start, end) = _matches[index];
    setState(() => _current = index);
    widget.controller
      ..setSearchMatches(_matches, index)
      ..selection = TextSelection(baseOffset: start, extentOffset: end);
    WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(start));
  }

  /// Scrolls the editor so that [offset] is visible; the editor does this
  /// by itself only while it has the focus.
  void _reveal(int offset) {
    final editable = findRenderEditable(widget.fieldKey);
    final scroll = widget.scrollController;
    if (!mounted || editable == null || !scroll.hasClients) return;
    final caret = editable.getLocalRectForCaret(TextPosition(offset: offset));
    final height = editable.size.height;
    if (caret.top >= 0 && caret.bottom <= height) return;
    final position = scroll.position;
    scroll.jumpTo(
      (position.pixels + caret.top - height / 3).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      ),
    );
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      widget.onClose();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      _step(HardwareKeyboard.instance.isShiftPressed ? -1 : 1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final count = _query.text.isEmpty
        ? ''
        : _matches.isEmpty
        ? l10n.searchNoMatches
        : l10n.searchMatchCount((_current ?? 0) + 1, _matches.length);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      child: Row(
        children: [
          Expanded(
            child: Focus(
              onKeyEvent: _onKey,
              child: TextField(
                key: const ValueKey('editor-search'),
                controller: _query,
                focusNode: _focus,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(Icons.search, size: 20),
                  hintText: l10n.searchInSong,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(count, style: Theme.of(context).textTheme.bodySmall),
          IconButton(
            tooltip: l10n.searchPrevious,
            icon: const Icon(Icons.keyboard_arrow_up),
            onPressed: _matches.isEmpty ? null : () => _step(-1),
          ),
          IconButton(
            tooltip: l10n.searchNext,
            icon: const Icon(Icons.keyboard_arrow_down),
            onPressed: _matches.isEmpty ? null : () => _step(1),
          ),
          IconButton(
            tooltip: l10n.searchClose,
            icon: const Icon(Icons.close),
            onPressed: widget.onClose,
          ),
        ],
      ),
    );
  }
}

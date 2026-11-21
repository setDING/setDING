import 'package:chordpro/chordpro.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import 'chordpro_editing_controller.dart';
import 'line_number_gutter.dart';

/// Suggestions for directives and chords below the cursor of the ChordPro
/// editor (#38). Typing is never blocked: the list follows the text, a tap,
/// Tab or Enter accepts, Esc dismisses it until the next change.
class EditorAutocomplete extends StatefulWidget {
  const EditorAutocomplete({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.fieldKey,
    required this.child,
    this.typingAids = true,
  });

  final ChordProEditingController controller;
  final FocusNode focusNode;

  /// Key of the editor's [TextField], to place the list at the cursor.
  final GlobalKey fieldKey;
  final Widget child;

  /// Whether an accepted section start also renames or adds its end
  /// (setting *Close brackets and sections automatically*, #757).
  final bool typingAids;

  /// Number of suggestions visible without scrolling.
  static const visibleItems = 6;
  static const itemHeight = 36.0;

  @override
  State<EditorAutocomplete> createState() => _EditorAutocompleteState();
}

class _EditorAutocompleteState extends State<EditorAutocomplete> {
  final _portal = OverlayPortalController();
  final _list = ScrollController();
  CompletionResult? _result;
  int _highlighted = 0;
  Offset? _anchor;
  late String _lastText;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _lastText = widget.controller.text;
    widget.controller.addListener(_onChanged);
    widget.focusNode.addListener(_onFocus);
    widget.focusNode.onKeyEvent = _onKey;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    widget.focusNode.removeListener(_onFocus);
    widget.focusNode.onKeyEvent = null;
    _list.dispose();
    super.dispose();
  }

  void _onFocus() {
    if (!widget.focusNode.hasFocus) _hide();
  }

  /// Suggestions appear after typing and follow the cursor while shown.
  void _onChanged() {
    final controller = widget.controller;
    final textChanged = controller.text != _lastText;
    _lastText = controller.text;
    if (textChanged) _dismissed = false;
    if ((!textChanged && _result == null) || _dismissed) return;
    final sel = controller.selection;
    final result = sel.isValid && sel.isCollapsed
        ? completeChordPro(
            controller.text,
            sel.baseOffset,
            tokens: controller.tokens,
          )
        : null;
    if (result == null) {
      _hide();
      return;
    }
    setState(() {
      _result = result;
      _highlighted = 0;
    });
    if (_list.hasClients) _list.jumpTo(0);
    // The caret position is known after the next layout. The focus is
    // checked then too: a toolbar button (e.g. Insert chord) changes the
    // text first and gives the focus back to the editor afterwards.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _result == null) return;
      if (!widget.focusNode.hasFocus) {
        _hide();
        return;
      }
      setState(() => _anchor = _caretAnchor());
      _portal.show();
    });
  }

  void _hide() {
    if (_result == null) return;
    setState(() {
      _result = null;
      _anchor = null;
    });
    _portal.hide();
  }

  /// Bottom left of the cursor in the coordinates of the overlay.
  Offset? _caretAnchor() {
    final editable = findRenderEditable(widget.fieldKey);
    final overlay = Overlay.maybeOf(context)?.context.findRenderObject();
    final sel = widget.controller.selection;
    if (editable == null || overlay is! RenderBox || !sel.isValid) return null;
    final caret = editable.getLocalRectForCaret(sel.extent);
    return overlay.globalToLocal(editable.localToGlobal(caret.bottomLeft));
  }

  void _accept(Completion item) {
    final result = _result;
    if (result == null) return;
    final before = widget.controller.text;
    var (text, cursor) = result.apply(before, item);
    _hide();
    if (widget.typingAids && result.kind == CompletionKind.directive) {
      // A renamed section start renames its end too (#755); a new one
      // gets its end directive and an empty line (#747).
      if (syncSectionPartner(before, text, cursor) case final synced?) {
        (text, cursor) = (synced.text, synced.base);
      }
      if (closeSectionBlock(text, cursor) case final block?) {
        (text, cursor) = (block.text, block.base);
      }
    }
    widget.controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: cursor),
    );
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final result = _result;
    if (result == null || event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final count = result.items.length;
    // Alt+↑/↓ moves lines (#361), it does not walk the list.
    if ((key == LogicalKeyboardKey.arrowDown ||
            key == LogicalKeyboardKey.arrowUp) &&
        !HardwareKeyboard.instance.isAltPressed) {
      final step = key == LogicalKeyboardKey.arrowDown ? 1 : -1;
      setState(() => _highlighted = (_highlighted + step) % count);
      _reveal();
      return KeyEventResult.handled;
    }
    if (event is KeyRepeatEvent) return KeyEventResult.ignored;
    if (key == LogicalKeyboardKey.tab ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _accept(result.items[_highlighted]);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      _dismissed = true;
      _hide();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// Scrolls the highlighted suggestion into view.
  void _reveal() {
    if (!_list.hasClients) return;
    const h = EditorAutocomplete.itemHeight;
    final top = _highlighted * h;
    final view = _list.position.viewportDimension;
    if (top < _list.offset) {
      _list.jumpTo(top);
    } else if (top + h > _list.offset + view) {
      _list.jumpTo(top + h - view);
    }
  }

  @override
  Widget build(BuildContext context) => OverlayPortal(
    controller: _portal,
    overlayChildBuilder: _buildList,
    child: widget.child,
  );

  Widget _buildList(BuildContext context) {
    final result = _result;
    final anchor = _anchor;
    if (result == null || anchor == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final size = MediaQuery.sizeOf(context);
    const width = 260.0;
    final height =
        EditorAutocomplete.itemHeight *
        result.items.length.clamp(1, EditorAutocomplete.visibleItems);
    // Below the cursor, or above it when there is no room (keyboard).
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final below = anchor.dy + height + 8 <= size.height - keyboard;
    final lineHeight =
        findRenderEditable(widget.fieldKey)?.preferredLineHeight ?? 20;
    return Positioned(
      left: anchor.dx.clamp(0, (size.width - width).clamp(0, double.infinity)),
      top: below ? anchor.dy + 4 : anchor.dy - lineHeight - height - 4,
      width: width,
      height: height,
      // Taps on the list do not take the focus away from the editor.
      child: TextFieldTapRegion(
        child: Material(
          elevation: 4,
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(8),
          clipBehavior: Clip.antiAlias,
          child: ListView.builder(
            controller: _list,
            padding: EdgeInsets.zero,
            itemExtent: EditorAutocomplete.itemHeight,
            itemCount: result.items.length,
            itemBuilder: (context, i) {
              final item = result.items[i];
              final selected = i == _highlighted;
              return InkWell(
                canRequestFocus: false,
                onTap: () => _accept(item),
                child: Container(
                  color: selected ? scheme.secondaryContainer : null,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      Icon(
                        result.kind == CompletionKind.chord
                            ? Icons.music_note
                            : Icons.data_object,
                        size: 16,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.label,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            color: selected
                                ? scheme.onSecondaryContainer
                                : scheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

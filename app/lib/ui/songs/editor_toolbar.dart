import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../../l10n/generated/app_localizations.dart';

/// A piece of ChordPro that the editor toolbar inserts around the selection.
class EditorSnippet {
  const EditorSnippet({
    required this.label,
    required this.before,
    this.after = '',
    this.block = false,
    this.meta,
    this.shortcut,
    this.icon,
  });

  final String label;
  final String before;
  final String after;

  /// Starts on a line of its own.
  final bool block;

  /// Metadata directive name: an existing directive is selected instead of
  /// inserting a second one.
  final String? meta;
  final SingleActivator? shortcut;
  final IconData? icon;
}

/// A titled group of snippets, shown as a dropdown menu.
class EditorSnippetGroup {
  const EditorSnippetGroup(this.label, this.icon, this.items);

  final String label;
  final IconData icon;

  /// Snippets; `null` is a divider.
  final List<EditorSnippet?> items;
}

bool get _useMeta =>
    defaultTargetPlatform == TargetPlatform.macOS ||
    defaultTargetPlatform == TargetPlatform.iOS;

// No Ctrl+Alt combinations: on Windows they equal AltGr, which types
// characters such as @ and # on Swiss and German keyboards.
SingleActivator _key(LogicalKeyboardKey key, {bool shift = false}) =>
    SingleActivator(key, control: !_useMeta, meta: _useMeta, shift: shift);

/// Saves the song (Ctrl+S / Cmd+S).
SingleActivator get saveShortcut => _key(LogicalKeyboardKey.keyS);

/// Opens the search bar (Ctrl+F / Cmd+F).
SingleActivator get searchShortcut => _key(LogicalKeyboardKey.keyF);

/// Opens the search bar with the replace row (Ctrl+H; Cmd+Option+F on
/// Apple, where Cmd+H hides the app).
SingleActivator get replaceShortcut => _useMeta
    ? const SingleActivator(LogicalKeyboardKey.keyF, meta: true, alt: true)
    : const SingleActivator(LogicalKeyboardKey.keyH, control: true);

/// Line and chord editing commands of the editor (#361).
enum EditorCommand {
  moveLinesUp(Icons.move_up),
  moveLinesDown(Icons.move_down),
  moveChordLeft(Icons.chevron_left),
  moveChordRight(Icons.chevron_right),
  duplicateLines(Icons.content_copy),
  deleteLines(Icons.delete_sweep_outlined),
  toggleComment(Icons.tag),
  convertChordsOverLyrics(Icons.auto_fix_high),
  convertCcliGrids(Icons.grid_on);

  const EditorCommand(this.icon);

  final IconData icon;

  String label(AppLocalizations l10n) => switch (this) {
    moveLinesUp => l10n.moveLinesUp,
    moveLinesDown => l10n.moveLinesDown,
    moveChordLeft => l10n.moveChordLeft,
    moveChordRight => l10n.moveChordRight,
    duplicateLines => l10n.duplicateLines,
    deleteLines => l10n.deleteLines,
    toggleComment => l10n.toggleComment,
    convertChordsOverLyrics => l10n.convertChordsOverLyrics,
    convertCcliGrids => l10n.convertCcliGrids,
  };

  /// The shortcut shown in menus and tooltips. Alt+↑/↓ as in common code
  /// editors; chords move with Alt+←/→, on Apple with Ctrl+Option+←/→
  /// because Option+←/→ moves the cursor by word there.
  SingleActivator? get shortcut => switch (this) {
    moveLinesUp => const SingleActivator(LogicalKeyboardKey.arrowUp, alt: true),
    moveLinesDown => const SingleActivator(
      LogicalKeyboardKey.arrowDown,
      alt: true,
    ),
    moveChordLeft => SingleActivator(
      LogicalKeyboardKey.arrowLeft,
      alt: true,
      control: _useMeta,
    ),
    moveChordRight => SingleActivator(
      LogicalKeyboardKey.arrowRight,
      alt: true,
      control: _useMeta,
    ),
    duplicateLines => _key(LogicalKeyboardKey.keyD),
    deleteLines => _key(LogicalKeyboardKey.keyK, shift: true),
    toggleComment => _key(LogicalKeyboardKey.slash),
    convertChordsOverLyrics || convertCcliGrids => null,
  };

  /// The key combinations of the command: [shortcut] or, for the comment
  /// toggle, also the typed `/`, which needs Shift on Swiss and German
  /// keyboards. One activator, so that a key press matching both runs the
  /// command once.
  ShortcutActivator? get activator => this == toggleComment
      ? _AnyActivator([
          ?shortcut,
          CharacterActivator('/', control: !_useMeta, meta: _useMeta),
        ])
      : shortcut;
}

/// Accepts a key event when any of [activators] does.
class _AnyActivator extends ShortcutActivator {
  const _AnyActivator(this.activators);

  final List<ShortcutActivator> activators;

  @override
  Iterable<LogicalKeyboardKey>? get triggers => null;

  @override
  bool accepts(KeyEvent event, HardwareKeyboard state) =>
      activators.any((a) => a.accepts(event, state));

  @override
  String debugDescribeKeys() =>
      activators.map((a) => a.debugDescribeKeys()).join(' | ');
}

/// All snippets of the editor toolbar, grouped.
class EditorSnippets {
  EditorSnippets(AppLocalizations l10n)
    : chord = EditorSnippet(
        label: l10n.insertChord,
        before: '[',
        after: ']',
        shortcut: _key(LogicalKeyboardKey.keyK),
        icon: Icons.music_note,
      ),
      verse = EditorSnippet(
        label: l10n.sectionVerse,
        before: '{start_of_verse}\n',
        after: '\n{end_of_verse}\n',
        block: true,
        shortcut: _key(LogicalKeyboardKey.digit1),
      ),
      chorus = EditorSnippet(
        label: l10n.sectionChorus,
        before: '{start_of_chorus}\n',
        after: '\n{end_of_chorus}\n',
        block: true,
        shortcut: _key(LogicalKeyboardKey.digit3),
      ),
      comment = EditorSnippet(
        label: l10n.insertComment,
        before: '{comment: ',
        after: '}\n',
        block: true,
        shortcut: _key(LogicalKeyboardKey.keyC, shift: true),
      ) {
    EditorSnippet meta(String name, String label) => EditorSnippet(
      label: label,
      before: '{$name: ',
      after: '}\n',
      block: true,
      meta: name,
    );
    EditorSnippet section(
      String type,
      String label, {
      String? title,
      SingleActivator? shortcut,
    }) => EditorSnippet(
      label: label,
      before: '{start_of_$type${title == null ? '' : ': $title'}}\n',
      after: '\n{end_of_$type}\n',
      block: true,
      shortcut: shortcut,
    );
    // Section types ChordPro has no environment for: a standard
    // environment labelled with the type's name.
    EditorSnippet labelled(
      String type,
      String label, {
      SingleActivator? shortcut,
    }) => section(type, label, title: label, shortcut: shortcut);

    groups = [
      EditorSnippetGroup(l10n.editorGroupChords, Icons.music_note, [
        chord,
        EditorSnippet(
          label: l10n.insertOptionalChord,
          before: '[(',
          after: ')]',
        ),
        EditorSnippet(label: l10n.insertAnnotation, before: '[*', after: ']'),
        EditorSnippet(label: l10n.insertNoChord, before: '[N.C.]'),
        null,
        EditorSnippet(
          label: l10n.insertDefine,
          before: '{define: ',
          after: ' base-fret 1 frets x 0 2 2 1 0}\n',
          block: true,
        ),
        EditorSnippet(
          label: l10n.insertChordDiagram,
          before: '{chord: ',
          after: '}\n',
          block: true,
        ),
        EditorSnippet(
          label: l10n.insertTranspose,
          before: '{transpose: ',
          after: '}\n',
          block: true,
        ),
      ]),
      EditorSnippetGroup(l10n.editorGroupSections, Icons.view_agenda_outlined, [
        verse,
        chorus,
        section(
          'bridge',
          l10n.sectionBridge,
          shortcut: _key(LogicalKeyboardKey.digit4),
        ),
        EditorSnippet(
          label: l10n.insertChorusRecall,
          before: '{chorus}\n',
          block: true,
        ),
        null,
        labelled('verse', l10n.sectionIntro),
        labelled('verse', l10n.sectionOutro),
        labelled('verse', l10n.sectionEnding),
        null,
        labelled('verse', l10n.sectionInstrumental),
        labelled('verse', l10n.sectionInterlude),
        labelled('verse', l10n.sectionSolo),
        null,
        labelled('verse', l10n.sectionTag),
        labelled('verse', l10n.sectionTurnaround),
        labelled('verse', l10n.sectionVamp),
        labelled('chorus', l10n.sectionRefrain),
        null,
        labelled(
          'verse',
          l10n.sectionPreChorus,
          shortcut: _key(LogicalKeyboardKey.digit2),
        ),
        labelled('verse', l10n.sectionPostChorus),
        labelled('verse', l10n.sectionBreakdown),
        null,
        section('tab', l10n.insertTab),
        EditorSnippet(
          label: l10n.insertGrid,
          before: '{start_of_grid}\n',
          after: '| C . . . | G . . . |\n{end_of_grid}\n',
          block: true,
        ),
      ]),
      EditorSnippetGroup(l10n.editorGroupInfo, Icons.info_outline, [
        meta('title', l10n.title),
        meta('subtitle', l10n.metaSubtitle),
        meta('artist', l10n.artist),
        null,
        meta('key', l10n.metaKey),
        meta('capo', l10n.capo),
        meta('tempo', l10n.metaTempo),
        meta('time', l10n.metaTime),
        meta('duration', l10n.metaDuration),
        meta('x_sequence', l10n.sequenceLabel),
        null,
        meta('composer', l10n.metaComposer),
        meta('lyricist', l10n.metaLyricist),
        meta('copyright', l10n.metaCopyright),
        meta('ccli', l10n.metaCcli),
        meta('album', l10n.metaAlbum),
        meta('year', l10n.metaYear),
        EditorSnippet(
          label: l10n.metaTag,
          before: '{tag: ',
          after: '}\n',
          block: true,
        ),
      ]),
      EditorSnippetGroup(l10n.editorGroupText, Icons.text_format, [
        comment,
        EditorSnippet(
          label: l10n.insertCommentItalic,
          before: '{comment_italic: ',
          after: '}\n',
          block: true,
        ),
        EditorSnippet(
          label: l10n.insertCommentBox,
          before: '{comment_box: ',
          after: '}\n',
          block: true,
        ),
        EditorSnippet(
          label: l10n.insertHighlight,
          before: '{highlight: ',
          after: '}\n',
          block: true,
        ),
        null,
        EditorSnippet(
          label: l10n.insertBold,
          before: '<b>',
          after: '</b>',
          shortcut: _key(LogicalKeyboardKey.keyB),
          icon: Icons.format_bold,
        ),
        EditorSnippet(
          label: l10n.insertItalic,
          before: '<i>',
          after: '</i>',
          shortcut: _key(LogicalKeyboardKey.keyI),
          icon: Icons.format_italic,
        ),
        EditorSnippet(
          label: l10n.insertUnderline,
          before: '<u>',
          after: '</u>',
          shortcut: _key(LogicalKeyboardKey.keyU),
          icon: Icons.format_underline,
        ),
        EditorSnippet(
          label: l10n.insertColour,
          before: '<span color="red">',
          after: '</span>',
          icon: Icons.format_color_text,
        ),
      ]),
      EditorSnippetGroup(l10n.editorGroupMore, Icons.more_horiz, [
        EditorSnippet(
          label: l10n.insertColumnBreak,
          before: '{column_break}\n',
          block: true,
        ),
        EditorSnippet(
          label: l10n.insertNewPage,
          before: '{new_page}\n',
          block: true,
        ),
        EditorSnippet(
          label: l10n.insertColumns,
          before: '{columns: 2}\n',
          block: true,
        ),
        null,
        EditorSnippet(
          label: l10n.insertImage,
          before: '{image: src="',
          after: '"}\n',
          block: true,
        ),
        EditorSnippet(
          label: l10n.insertTextblock,
          before: '{start_of_textblock}\n',
          after: '\n{end_of_textblock}\n',
          block: true,
        ),
        EditorSnippet(
          label: l10n.insertAbc,
          before: '{start_of_abc}\nX:1\nK:C\n',
          after: '\n{end_of_abc}\n',
          block: true,
        ),
        null,
        EditorSnippet(
          label: l10n.insertNewSong,
          before: '{new_song}\n{title: ',
          after: '}\n',
          block: true,
        ),
      ]),
    ];
  }

  final EditorSnippet chord;
  final EditorSnippet verse;
  final EditorSnippet chorus;
  final EditorSnippet comment;
  late final List<EditorSnippetGroup> groups;

  /// Snippets that have a keyboard shortcut.
  Iterable<EditorSnippet> get withShortcut => {
    for (final group in groups)
      for (final item in group.items)
        if (item?.shortcut != null) item!,
  };
}

/// Quick buttons for the most used snippets plus grouped dropdown menus.
class EditorToolbar extends StatelessWidget {
  const EditorToolbar({
    super.key,
    required this.snippets,
    required this.onInsert,
    this.onDetails,
    this.onCommand,
    this.undoController,
    this.onSearch,
  });

  /// Opens the search bar (#368).
  final VoidCallback? onSearch;

  final EditorSnippets snippets;
  final ValueChanged<EditorSnippet> onInsert;

  /// Runs a line or chord command; without it, the buttons are hidden.
  final ValueChanged<EditorCommand>? onCommand;

  /// Undo history of the editor, for the undo and redo buttons.
  final UndoHistoryController? undoController;

  /// Opens the song details form (title, key, tempo, …).
  final VoidCallback? onDetails;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Widget quick(EditorSnippet snippet, String tooltip, String label) =>
        Tooltip(
          message: _withShortcut(tooltip, snippet.shortcut),
          child: ActionChip(
            visualDensity: VisualDensity.compact,
            label: Text(label),
            onPressed: () => onInsert(snippet),
          ),
        );
    // Wraps instead of scrolling so that every group stays visible, also
    // in the narrow editor half of the split view. The editing buttons
    // have a row of their own below the insert menus (#377).
    final onCommand = this.onCommand;
    final onSearch = this.onSearch;
    final editRow = onCommand == null && onSearch == null
        ? null
        : Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (onCommand != null)
                _CommandButtons(onCommand: onCommand, undo: undoController),
              if (onSearch != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: _withShortcut(l10n.searchInSong, searchShortcut),
                  icon: const Icon(Icons.search),
                  onPressed: onSearch,
                ),
            ],
          );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (onDetails != null)
                Tooltip(
                  message: l10n.songDetailsTooltip,
                  child: TextButton.icon(
                    onPressed: onDetails,
                    icon: const Icon(Icons.edit_note, size: 18),
                    label: Text(l10n.songDetails),
                  ),
                ),
              quick(snippets.chord, l10n.insertChord, '[ ]'),
              quick(snippets.verse, l10n.insertVerse, l10n.sectionVerse),
              quick(snippets.chorus, l10n.insertChorus, l10n.sectionChorus),
              quick(snippets.comment, l10n.insertComment, '{c: }'),
              for (final group in snippets.groups)
                _GroupMenu(group: group, onInsert: onInsert),
            ],
          ),
          if (editRow != null) ...[const SizedBox(height: 4), editRow],
        ],
      ),
    );
  }
}

/// Undo/redo and the line and chord commands as icon buttons, for tablets
/// without a keyboard, plus a menu with all line commands (#361).
class _CommandButtons extends StatelessWidget {
  const _CommandButtons({required this.onCommand, this.undo});

  final ValueChanged<EditorCommand> onCommand;
  final UndoHistoryController? undo;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Widget button(EditorCommand command) => IconButton(
      visualDensity: VisualDensity.compact,
      tooltip: _withShortcut(command.label(l10n), command.shortcut),
      icon: Icon(command.icon),
      onPressed: () => onCommand(command),
    );
    final undo = this.undo;
    // Wraps like the toolbar, so narrow editors keep all buttons visible.
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (undo != null)
          ValueListenableBuilder(
            valueListenable: undo,
            builder: (context, value, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: l10n.undo,
                  icon: const Icon(Icons.undo),
                  onPressed: value.canUndo ? undo.undo : null,
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: l10n.redo,
                  icon: const Icon(Icons.redo),
                  onPressed: value.canRedo ? undo.redo : null,
                ),
              ],
            ),
          ),
        button(EditorCommand.moveLinesUp),
        button(EditorCommand.moveLinesDown),
        button(EditorCommand.moveChordLeft),
        button(EditorCommand.moveChordRight),
        MenuAnchor(
          menuChildren: [
            for (final command in EditorCommand.values)
              MenuItemButton(
                leadingIcon: Icon(command.icon, size: 20),
                shortcut: command.shortcut,
                onPressed: () => onCommand(command),
                child: Text(command.label(l10n)),
              ),
          ],
          builder: (context, controller, _) => TextButton.icon(
            onPressed: () =>
                controller.isOpen ? controller.close() : controller.open(),
            icon: const Icon(Icons.format_line_spacing, size: 18),
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.editorGroupLines),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _GroupMenu extends StatelessWidget {
  const _GroupMenu({required this.group, required this.onInsert});

  final EditorSnippetGroup group;
  final ValueChanged<EditorSnippet> onInsert;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      menuChildren: [
        for (final item in group.items)
          if (item == null)
            const Divider(height: 8)
          else
            MenuItemButton(
              leadingIcon: Icon(item.icon, size: 20),
              shortcut: item.shortcut,
              onPressed: () => onInsert(item),
              child: Text(item.label),
            ),
      ],
      builder: (context, controller, _) => TextButton.icon(
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
        icon: Icon(group.icon, size: 18),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [Text(group.label), const Icon(Icons.arrow_drop_down)],
        ),
      ),
    );
  }
}

String _withShortcut(String text, SingleActivator? shortcut) {
  if (shortcut == null) return text;
  final keys = [
    if (shortcut.control) 'Ctrl',
    if (shortcut.meta) '⌘',
    if (shortcut.alt) _useMeta ? '⌥' : 'Alt',
    if (shortcut.shift) 'Shift',
    _keyLabels[shortcut.trigger] ?? shortcut.trigger.keyLabel,
  ];
  return '$text (${keys.join('+')})';
}

final _keyLabels = {
  LogicalKeyboardKey.arrowUp: '↑',
  LogicalKeyboardKey.arrowDown: '↓',
  LogicalKeyboardKey.arrowLeft: '←',
  LogicalKeyboardKey.arrowRight: '→',
};

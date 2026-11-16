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
        section(
          'verse',
          l10n.sectionPreChorus,
          title: l10n.sectionPreChorus,
          shortcut: _key(LogicalKeyboardKey.digit2),
        ),
        chorus,
        section(
          'bridge',
          l10n.sectionBridge,
          shortcut: _key(LogicalKeyboardKey.digit4),
        ),
        section('verse', l10n.sectionIntro, title: l10n.sectionIntro),
        section('verse', l10n.sectionOutro, title: l10n.sectionOutro),
        EditorSnippet(
          label: l10n.insertChorusRecall,
          before: '{chorus}\n',
          block: true,
        ),
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
  });

  final EditorSnippets snippets;
  final ValueChanged<EditorSnippet> onInsert;

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
    // in the narrow editor half of the split view.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Wrap(
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
    if (shortcut.alt) 'Alt',
    if (shortcut.shift) 'Shift',
    shortcut.trigger.keyLabel,
  ];
  return '$text (${keys.join('+')})';
}

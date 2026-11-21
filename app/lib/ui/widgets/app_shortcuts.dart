import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/generated/app_localizations.dart';

/// Keyboard shortcuts of a screen (ADR-0049, #729): single keys such as E
/// (edit) or L (live), for a computer or a tablet with a keyboard.
///
/// A focus node around the screen takes the focus when the screen opens and
/// sees the keys after the focused widget (a slider keeps its arrows) but
/// before the app-wide shortcuts, which would otherwise move the focus with
/// the arrow keys. A late key event handler catches the keys when the focus
/// is elsewhere (e.g. a hidden tab had it). They apply only while
/// - the screen's route is the current one (no dialog, menu or other screen
///   above it),
/// - the screen is visible (not a hidden tab of an `IndexedStack`), and
/// - no text field has the focus, so typing an "e" stays typing.
class PageShortcuts extends StatefulWidget {
  const PageShortcuts({
    super.key,
    required this.bindings,
    this.whileTyping = const {},
    required this.child,
  });

  /// The shortcuts and what they do; a `null` callback is not active (e.g.
  /// editing without the permission).
  final Map<ShortcutActivator, VoidCallback?> bindings;

  /// Shortcuts of [bindings] that also apply while a text field has the
  /// focus, because they type nothing (Esc closing the selection, #739).
  final Set<ShortcutActivator> whileTyping;
  final Widget child;

  @override
  State<PageShortcuts> createState() => _PageShortcutsState();
}

class _PageShortcutsState extends State<PageShortcuts> {
  @override
  void initState() {
    super.initState();
    FocusManager.instance.addLateKeyEventHandler(_onKey);
  }

  @override
  void dispose() {
    FocusManager.instance.removeLateKeyEventHandler(_onKey);
    super.dispose();
  }

  KeyEventResult _onKey(KeyEvent event) {
    if (!mounted || !screenActive(context)) return KeyEventResult.ignored;
    final typing = textFieldFocused();
    for (final MapEntry(key: activator, value: callback)
        in widget.bindings.entries) {
      if (callback == null) continue;
      if (typing && !widget.whileTyping.contains(activator)) continue;
      if (activator.accepts(event, HardwareKeyboard.instance)) {
        callback();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) => Focus(
    autofocus: true,
    skipTraversal: true,
    onKeyEvent: (_, event) => _onKey(event),
    child: widget.child,
  );
}

/// Whether the screen of [context] takes shortcuts now: its route is current
/// and it is visible.
bool screenActive(BuildContext context) {
  final route = ModalRoute.of(context);
  if (route != null && !route.isCurrent) return false;
  // Hidden tabs of an IndexedStack have their tickers off.
  return TickerMode.valuesOf(context).enabled;
}

/// Whether a text field has the keyboard focus.
bool textFieldFocused() {
  final focused = FocusManager.instance.primaryFocus?.context;
  if (focused == null) return false;
  return focused.widget is EditableText ||
      focused.findAncestorStateOfType<EditableTextState>() != null;
}

bool get _useMeta =>
    defaultTargetPlatform == TargetPlatform.macOS ||
    defaultTargetPlatform == TargetPlatform.iOS;

/// Shortcuts that do not repeat while the key is held.
SingleActivator _once(LogicalKeyboardKey key) =>
    SingleActivator(key, includeRepeats: false);

/// E: edit the song or set.
final editShortcut = _once(LogicalKeyboardKey.keyE);

/// L: start live mode.
final liveShortcut = _once(LogicalKeyboardKey.keyL);

/// / or Ctrl+F (Cmd+F): search the song list.
final searchShortcuts = <ShortcutActivator>[
  const CharacterActivator('/'),
  SingleActivator(
    LogicalKeyboardKey.keyF,
    control: !_useMeta,
    meta: _useMeta,
    includeRepeats: false,
  ),
];

/// + and −: personal transposition up and down.
const transposeUpShortcuts = <ShortcutActivator>[
  CharacterActivator('+'),
  SingleActivator(LogicalKeyboardKey.numpadAdd),
];
const transposeDownShortcuts = <ShortcutActivator>[
  CharacterActivator('-'),
  SingleActivator(LogicalKeyboardKey.numpadSubtract),
];

/// ← and →: previous and next song of the set.
const previousSongShortcut = SingleActivator(
  LogicalKeyboardKey.arrowLeft,
  includeRepeats: false,
);
const nextSongShortcut = SingleActivator(
  LogicalKeyboardKey.arrowRight,
  includeRepeats: false,
);

/// Esc: close the selection of the song list (#739); otherwise Esc goes
/// back (`EscapeGoesBack`).
const closeSelectionShortcut = SingleActivator(LogicalKeyboardKey.escape);

/// ?: the list of all shortcuts.
const helpShortcut = CharacterActivator('?');

/// Shows the list of all shortcuts on `?` from every screen (#729).
class ShortcutHelpKey extends StatefulWidget {
  const ShortcutHelpKey({super.key, required this.child});

  final Widget child;

  @override
  State<ShortcutHelpKey> createState() => _ShortcutHelpKeyState();
}

class _ShortcutHelpKeyState extends State<ShortcutHelpKey> {
  @override
  void initState() {
    super.initState();
    FocusManager.instance.addLateKeyEventHandler(_onKey);
  }

  @override
  void dispose() {
    FocusManager.instance.removeLateKeyEventHandler(_onKey);
    super.dispose();
  }

  KeyEventResult _onKey(KeyEvent event) {
    if (!helpShortcut.accepts(event, HardwareKeyboard.instance)) {
      return KeyEventResult.ignored;
    }
    final context = FocusManager.instance.primaryFocus?.context;
    if (context == null || !context.mounted || textFieldFocused()) {
      return KeyEventResult.ignored;
    }
    // Not above a dialog or menu.
    final route = ModalRoute.of(context);
    if (route is! PageRoute || !route.isCurrent) return KeyEventResult.ignored;
    showShortcutHelp(context);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The dialog listing all keyboard shortcuts.
Future<void> showShortcutHelp(BuildContext context) => showDialog<void>(
  context: context,
  builder: (_) => const ShortcutHelpDialog(),
);

class ShortcutHelpDialog extends StatelessWidget {
  const ShortcutHelpDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    const left = Icons.arrow_back;
    const right = Icons.arrow_forward;
    const up = Icons.arrow_upward;
    const down = Icons.arrow_downward;
    // Keys are text or an icon (the arrows are missing in some fonts).
    final sections = <(String, List<(List<Object>, String)>)>[
      (
        l10n.shortcutsEverywhere,
        [
          (['Esc'], l10n.shortcutBack),
          (['?'], l10n.shortcutHelp),
        ],
      ),
      (
        l10n.shortcutsSong,
        [
          (['E'], l10n.shortcutEditSong),
          (['L'], l10n.shortcutLive),
          (['+', '−'], l10n.shortcutTranspose),
          ([left, right], l10n.shortcutPreviousNextSong),
        ],
      ),
      (
        l10n.shortcutsSet,
        [
          (['E'], l10n.shortcutEditSet),
          (['L'], l10n.shortcutLive),
        ],
      ),
      (
        l10n.shortcutsSongList,
        [
          (['/', _useMeta ? '⌘F' : 'Ctrl+F'], l10n.shortcutSearch),
          (['Esc'], l10n.shortcutCloseSelection),
        ],
      ),
      (
        l10n.shortcutsLive,
        [
          (
            [right, down, l10n.shortcutKeyPageDown, l10n.shortcutKeySpace],
            l10n.shortcutNextPage,
          ),
          ([left, up, l10n.shortcutKeyPageUp], l10n.shortcutPreviousPage),
          (['Enter'], l10n.shortcutBeat),
          (['Esc'], l10n.liveExit),
        ],
      ),
    ];
    final theme = Theme.of(context);
    return AlertDialog(
      key: const Key('shortcut-help'),
      title: Text(l10n.keyboardShortcuts),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (title, rows) in sections) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 4),
                  child: Text(title, style: theme.textTheme.titleSmall),
                ),
                for (final (keys, action) in rows)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 240,
                          child: Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: [for (final key in keys) _KeyCap(key)],
                          ),
                        ),
                        Expanded(child: Text(action)),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.close),
        ),
      ],
    );
  }
}

/// One key of the help dialog, drawn as a key cap.
class _KeyCap extends StatelessWidget {
  const _KeyCap(this.label);

  /// A `String` or an `IconData`.
  final Object label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelMedium;
    return Container(
      constraints: const BoxConstraints(minWidth: 26),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(4),
      ),
      child: switch (label) {
        final IconData icon => Icon(icon, size: 16),
        _ => Text(
          '$label',
          textAlign: TextAlign.center,
          style: style?.copyWith(fontWeight: FontWeight.w600),
        ),
      },
    );
  }
}

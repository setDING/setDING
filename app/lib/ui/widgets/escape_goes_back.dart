import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// Esc acts like the back button in the app bar on every screen (#726).
///
/// Registered as a late key event handler, so it only sees Esc when nothing
/// else handled it: dialogs, menus and bottom sheets still close themselves
/// (their `DismissIntent`), and widgets with their own Esc (editor search,
/// autocomplete, live mode) keep it. It pops only a page route that is the
/// current route of the focused screen, through `maybePop`, so a `PopScope`
/// (unsaved changes) still asks first and the start screen stays.
class EscapeGoesBack extends StatefulWidget {
  const EscapeGoesBack({super.key, required this.child});

  final Widget child;

  @override
  State<EscapeGoesBack> createState() => _EscapeGoesBackState();
}

class _EscapeGoesBackState extends State<EscapeGoesBack> {
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
    if (event.logicalKey != LogicalKeyboardKey.escape) {
      return KeyEventResult.ignored;
    }
    final context = FocusManager.instance.primaryFocus?.context;
    if (context == null || !context.mounted) return KeyEventResult.ignored;
    final route = ModalRoute.of(context);
    if (route is! PageRoute || !route.isCurrent || !route.canPop) {
      return KeyEventResult.ignored;
    }
    if (event is KeyDownEvent) Navigator.of(context).maybePop();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

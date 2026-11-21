import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/generated/app_localizations.dart';
import 'loading_indicator.dart';

/// The style of the button that confirms a destructive action (deleting,
/// removing, leaving, discarding): filled in the error colours, so it never
/// looks like an ordinary "OK" (docs/development/ui-design.md, "Dialogs").
ButtonStyle destructiveButtonStyle(BuildContext context) {
  final colors = Theme.of(context).colorScheme;
  return FilledButton.styleFrom(
    backgroundColor: colors.error,
    foregroundColor: colors.onError,
  );
}

/// Asks for confirmation. [action] names what happens ("Delete" by
/// default); a [destructive] action gets a button in the error colours.
Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  String? action,
  bool destructive = true,
}) async {
  final l10n = AppLocalizations.of(context);
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const Key('confirm-action'),
          style: destructive ? destructiveButtonStyle(context) : null,
          onPressed: () => Navigator.pop(context, true),
          child: Text(action ?? l10n.delete),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Asks for a single line or multi-line text.
Future<String?> askText(
  BuildContext context, {
  required String title,
  String initial = '',
  String? label,
  String? hint,
  bool multiline = false,
  bool allowEmpty = false,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _TextDialog(
      title: title,
      initial: initial,
      label: label,
      hint: hint,
      multiline: multiline,
      allowEmpty: allowEmpty,
    ),
  );
}

class _TextDialog extends StatefulWidget {
  const _TextDialog({
    required this.title,
    required this.initial,
    this.label,
    this.hint,
    required this.multiline,
    required this.allowEmpty,
  });

  final String title;
  final String initial;
  final String? label;
  final String? hint;
  final bool multiline;
  final bool allowEmpty;

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty && !widget.allowEmpty) return;
    Navigator.pop(context, text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: TextField(
          controller: _controller,
          autofocus: true,
          minLines: widget.multiline ? 3 : 1,
          maxLines: widget.multiline ? 8 : 1,
          textInputAction: widget.multiline
              ? TextInputAction.newline
              : TextInputAction.done,
          onSubmitted: widget.multiline ? null : (_) => _submit(),
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hint,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.save)),
      ],
    );
  }
}

/// An action of a message, e.g. "Open" or "Undo".
typedef MessageAction = ({String label, VoidCallback onPressed, Key? key});

/// How long a message without an action stays (Flutter's default).
const messageDuration = Duration(seconds: 4);

/// How long a message with an action (e.g. "Open") stays.
const messageActionDuration = Duration(seconds: 8);

/// Shows a short message at the bottom of the screen
/// (docs/development/ui-design.md, "Messages").
void showMessage(BuildContext context, String message) =>
    showMessageOn(ScaffoldMessenger.of(context), message);

/// Shows [message] through [messenger], taken before an async gap or before
/// the screen closes, so the message shows on the next screen.
///
/// The message replaces one still shown, unless [queue] is set (hints at
/// app start that must not hide each other). A message with an [action]
/// still goes away by itself, after [duration] or [messageActionDuration]:
/// a hint, never a question.
void showMessageOn(
  ScaffoldMessengerState? messenger,
  String message, {
  Key? key,
  MessageAction? action,
  Duration? duration,
  bool queue = false,
}) {
  if (messenger == null) return;
  if (!queue) messenger.hideCurrentSnackBar();
  messenger.showSnackBar(_snackBar(message, key, action, duration));
}

SnackBar _snackBar(
  String message,
  Key? key,
  MessageAction? action,
  Duration? duration,
) => SnackBar(
  key: key,
  content: Text(message),
  duration:
      duration ?? (action == null ? messageDuration : messageActionDuration),
  persist: false,
  action: action == null
      ? null
      : SnackBarAction(
          key: action.key,
          label: action.label,
          onPressed: action.onPressed,
        ),
);

/// Shows a message with one action, e.g. "Open" after an export (#721).
/// It disappears on its own after [messageActionDuration].
void showMessageWithAction(
  BuildContext context,
  String message, {
  required String actionLabel,
  required VoidCallback onAction,
}) => showMessageOn(
  ScaffoldMessenger.of(context),
  message,
  action: (label: actionLabel, onPressed: onAction, key: null),
);

/// Builds [data] once the [value] is available, with loading and error states.
class AsyncBody<T> extends StatelessWidget {
  const AsyncBody({super.key, required this.value, required this.data});

  final AsyncValue<T> value;
  final Widget Function(T data) data;

  @override
  Widget build(BuildContext context) => value.when(
    data: data,
    loading: () => const LoadingIndicator(),
    error: (error, _) => Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(AppLocalizations.of(context).errorGeneric('$error')),
      ),
    ),
  );
}

/// Placeholder for empty lists.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String message;

  /// Optional button below the message.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

/// Formats a byte count for display.
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// Formats a transposition value, e.g. `+2`, `−1`, `0`.
String formatSemitones(int value) => value > 0
    ? '+$value'
    : value < 0
    ? '−${-value}'
    : '0';

/// How long "Undo" is offered after a deletion.
const undoDuration = Duration(seconds: 6);

/// Tells that something was deleted and offers "Undo" for [undoDuration]
/// (#267). [onUndo] restores it; [onGone] runs once the undo is no longer
/// offered (e.g. to delete files). [messenger] is taken before the screen of
/// the deleted record is closed, so the message shows on the next one.
void showUndo(
  ScaffoldMessengerState messenger,
  String message, {
  required String undoLabel,
  required Future<void> Function() onUndo,
  Future<void> Function()? onGone,
}) {
  messenger.hideCurrentSnackBar();
  final controller = messenger.showSnackBar(
    _snackBar(message, null, (
      label: undoLabel,
      onPressed: onUndo,
      key: null,
    ), undoDuration),
  );
  if (onGone != null) {
    controller.closed.then((reason) {
      if (reason != SnackBarClosedReason.action) return onGone();
    });
  }
}

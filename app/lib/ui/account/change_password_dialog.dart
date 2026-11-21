import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../sync/auth_providers.dart';
import '../../sync/sync_backend.dart';
import 'sign_in_screen.dart' show backendErrorText, minPasswordLength;

/// Asks for the current and a new password and changes it on the server
/// (issue #779). Returns true when the password was changed.
Future<bool> showChangePasswordDialog(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => const ChangePasswordDialog(),
    ) ??
    false;

class ChangePasswordDialog extends ConsumerStatefulWidget {
  const ChangePasswordDialog({super.key});

  @override
  ConsumerState<ChangePasswordDialog> createState() =>
      _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<ChangePasswordDialog> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _showPassword = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(syncBackendProvider)
          .changePassword(
            oldPassword: _current.text,
            newPassword: _password.text,
          );
      if (mounted) Navigator.pop(context, true);
    } on BackendException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.kind == BackendErrorKind.invalidCredentials
            ? l10n.accountPasswordWrongCurrent
            : backendErrorText(l10n, e.kind);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    String? required(String? v) =>
        v == null || v.isEmpty ? l10n.accountFieldRequired : null;
    final visibility = IconButton(
      key: const Key('change-password-visibility'),
      icon: Icon(
        _showPassword
            ? Icons.visibility_off_outlined
            : Icons.visibility_outlined,
      ),
      tooltip: _showPassword
          ? l10n.accountPasswordHide
          : l10n.accountPasswordShow,
      onPressed: () => setState(() => _showPassword = !_showPassword),
    );
    return AlertDialog(
      title: Text(l10n.accountChangePassword),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _form,
          child: AutofillGroup(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.accountChangePasswordHint),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('change-password-current'),
                  controller: _current,
                  autofocus: true,
                  obscureText: !_showPassword,
                  decoration: InputDecoration(
                    labelText: l10n.accountCurrentPassword,
                    suffixIcon: visibility,
                  ),
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.password],
                  validator: required,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('change-password-new'),
                  controller: _password,
                  obscureText: !_showPassword,
                  decoration: InputDecoration(
                    labelText: l10n.accountNewPassword,
                  ),
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return l10n.accountFieldRequired;
                    }
                    if (v.length < minPasswordLength) {
                      return l10n.accountPasswordTooShort(minPasswordLength);
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('change-password-confirm'),
                  controller: _confirm,
                  obscureText: !_showPassword,
                  decoration: InputDecoration(
                    labelText: l10n.accountPasswordConfirm,
                  ),
                  textInputAction: TextInputAction.done,
                  validator: (v) =>
                      v != _password.text ? l10n.accountPasswordMismatch : null,
                  onFieldSubmitted: (_) => _submit(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    key: const Key('change-password-error'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const Key('change-password-save'),
          onPressed: _busy ? null : _submit,
          child: Text(l10n.save),
        ),
      ],
    );
  }
}

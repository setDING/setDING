import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../sync/auth_providers.dart';
import '../../sync/browser_session_store.dart';
import '../../sync/sync_backend.dart';
import '../bands/join_screen.dart';
import '../widgets/dialogs.dart';

/// Minimum password length of the server (PocketBase default).
const minPasswordLength = 8;

/// Message for a failed backend call.
String backendErrorText(AppLocalizations l10n, BackendErrorKind kind) =>
    switch (kind) {
      BackendErrorKind.network => l10n.accountErrorNetwork,
      BackendErrorKind.invalidCredentials =>
        l10n.accountErrorInvalidCredentials,
      BackendErrorKind.emailTaken => l10n.accountErrorEmailTaken,
      BackendErrorKind.invalidEmail => l10n.accountErrorInvalidEmail,
      BackendErrorKind.weakPassword => l10n.accountErrorWeakPassword,
      BackendErrorKind.lastAdmin => l10n.bandErrorLastAdmin,
      BackendErrorKind.notAllowed => l10n.bandErrorNotAllowed,
      BackendErrorKind.notOrgMember => l10n.bandErrorNotOrgMember,
      BackendErrorKind.inviteUnknown => l10n.inviteErrorUnknown,
      BackendErrorKind.inviteExpired => l10n.inviteErrorExpired,
      BackendErrorKind.inviteRevoked => l10n.inviteErrorRevoked,
      BackendErrorKind.conflict => l10n.accountErrorConflict,
      BackendErrorKind.signedOut => l10n.accountErrorSignedOut,
      BackendErrorKind.server => l10n.accountErrorServer,
    };

/// Sign in or create an account. Closes itself after success, unless it is
/// the [gate] of the web client, which the app replaces after signing in.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key, this.signUp = false, this.gate = false});

  /// Start in "create account" mode.
  final bool signUp;

  /// The start screen of the web client, where signing in is required
  /// (ADR-0018): no back button, and a way to join with an invitation.
  final bool gate;

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  late bool _signUp = widget.signUp;
  bool _keepSignedIn = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final backend = ref.read(syncBackendProvider);
    if (ref.read(sessionStoreProvider) case final BrowserSessionStore store) {
      store.keepSignedIn = _keepSignedIn;
    }
    try {
      if (_signUp) {
        await backend.signUp(
          email: _email.text,
          password: _password.text,
          name: _name.text,
        );
      } else {
        await backend.signIn(email: _email.text, password: _password.text);
      }
      if (mounted && !widget.gate) Navigator.of(context).pop(true);
    } on BackendException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = backendErrorText(AppLocalizations.of(context), e.kind);
      });
    }
  }

  Future<void> _resetPassword() async {
    final l10n = AppLocalizations.of(context);
    final email = await askText(
      context,
      title: l10n.accountResetTitle,
      label: l10n.accountEmail,
      initial: _email.text.trim(),
    );
    if (email == null || email.trim().isEmpty || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(syncBackendProvider).requestPasswordReset(email);
      messenger.showSnackBar(SnackBar(content: Text(l10n.accountResetSent)));
    } on BackendException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(backendErrorText(l10n, e.kind))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    String? required(String? v) =>
        v == null || v.trim().isEmpty ? l10n.accountFieldRequired : null;

    final browserSession =
        ref.watch(sessionStoreProvider) is BrowserSessionStore;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.gate,
        title: Text(
          widget.gate
              ? l10n.appTitle
              : (_signUp ? l10n.accountSignUp : l10n.accountSignIn),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Form(
            key: _form,
            child: AutofillGroup(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  if (widget.gate) ...[
                    Text(
                      _signUp ? l10n.accountSignUp : l10n.accountSignIn,
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(l10n.webSignInHint),
                    const SizedBox(height: 24),
                  ],
                  if (_signUp) ...[
                    TextFormField(
                      key: const Key('account-name'),
                      controller: _name,
                      decoration: InputDecoration(
                        labelText: l10n.accountName,
                        helperText: l10n.accountNameHint,
                      ),
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.name],
                      validator: required,
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    key: const Key('account-email'),
                    controller: _email,
                    decoration: InputDecoration(labelText: l10n.accountEmail),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    autofillHints: const [AutofillHints.email],
                    validator: required,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('account-password'),
                    controller: _password,
                    decoration: InputDecoration(
                      labelText: l10n.accountPassword,
                    ),
                    obscureText: true,
                    textInputAction: _signUp
                        ? TextInputAction.next
                        : TextInputAction.done,
                    autofillHints: [
                      _signUp
                          ? AutofillHints.newPassword
                          : AutofillHints.password,
                    ],
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return l10n.accountFieldRequired;
                      }
                      if (_signUp && v.length < minPasswordLength) {
                        return l10n.accountPasswordTooShort(minPasswordLength);
                      }
                      return null;
                    },
                    onFieldSubmitted: _signUp ? null : (_) => _submit(),
                  ),
                  if (_signUp) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('account-password-confirm'),
                      controller: _confirm,
                      decoration: InputDecoration(
                        labelText: l10n.accountPasswordConfirm,
                      ),
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      validator: (v) => v != _password.text
                          ? l10n.accountPasswordMismatch
                          : null,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                  ],
                  if (browserSession) ...[
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      key: const Key('account-keep-signed-in'),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _keepSignedIn,
                      onChanged: _busy
                          ? null
                          : (v) => setState(() => _keepSignedIn = v ?? false),
                      title: Text(l10n.accountKeepSignedIn),
                      subtitle: Text(l10n.accountKeepSignedInHint),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      key: const Key('account-error'),
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    key: const Key('account-submit'),
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _signUp ? l10n.accountSignUp : l10n.accountSignIn,
                          ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                            _signUp = !_signUp;
                            _error = null;
                          }),
                    child: Text(
                      _signUp ? l10n.accountToSignIn : l10n.accountToSignUp,
                    ),
                  ),
                  if (!_signUp)
                    TextButton(
                      onPressed: _busy ? null : _resetPassword,
                      child: Text(l10n.accountForgotPassword),
                    ),
                  if (widget.gate)
                    TextButton.icon(
                      key: const Key('account-open-join'),
                      icon: const Icon(Icons.link),
                      onPressed: _busy
                          ? null
                          : () => Navigator.of(context).push(
                              MaterialPageRoute<bool>(
                                builder: (_) => const JoinScreen(),
                              ),
                            ),
                      label: Text(l10n.accountJoin),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

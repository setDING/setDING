import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../sync/auth_providers.dart';
import '../../sync/browser_session_store.dart';
import '../../sync/sync_backend.dart';
import '../../util/log.dart';
import '../bands/join_screen.dart';
import '../widgets/dialogs.dart';
import '../../util/semver.dart';
import '../widgets/logo.dart';
import '../widgets/update_required_banner.dart';
import '../widgets/page_width.dart';

const _log = Log('account');

/// Minimum password length of the server (PocketBase default).
const minPasswordLength = 8;

/// Message for a failed backend call.
String backendErrorText(
  AppLocalizations l10n,
  BackendErrorKind kind,
) => switch (kind) {
  BackendErrorKind.network => l10n.accountErrorNetwork,
  BackendErrorKind.invalidCredentials => l10n.accountErrorInvalidCredentials,
  BackendErrorKind.emailTaken => l10n.accountErrorEmailTaken,
  BackendErrorKind.invalidEmail => l10n.accountErrorInvalidEmail,
  BackendErrorKind.weakPassword => l10n.accountErrorWeakPassword,
  BackendErrorKind.lastAdmin => l10n.bandErrorLastAdmin,
  BackendErrorKind.soleOrgAdmin => l10n.accountDeleteSoleAdmin,
  BackendErrorKind.notAllowed => l10n.bandErrorNotAllowed,
  BackendErrorKind.notOrgMember => l10n.bandErrorNotOrgMember,
  BackendErrorKind.inviteUnknown => l10n.inviteErrorUnknown,
  BackendErrorKind.inviteExpired => l10n.inviteErrorExpired,
  BackendErrorKind.inviteRevoked => l10n.inviteErrorRevoked,
  BackendErrorKind.inviteUsed => l10n.inviteErrorUsed,
  BackendErrorKind.inviteNotStored => l10n.inviteErrorNotStored,
  BackendErrorKind.invitationRequired => l10n.accountErrorInvitationRequired,
  BackendErrorKind.emailNotVerified => l10n.accountErrorEmailNotVerified,
  BackendErrorKind.founderInvitationRequired =>
    l10n.bandErrorFounderInvitationRequired,
  BackendErrorKind.conflict => l10n.accountErrorConflict,
  BackendErrorKind.signedOut => l10n.accountErrorSignedOut,
  BackendErrorKind.updateRequired => l10n.accountErrorUpdateRequired,
  BackendErrorKind.server => l10n.accountErrorServer,
};

/// Sign in or create an account. Closes itself after success, unless it is
/// the [gate] of the web client, which the app replaces after signing in.
///
/// On an invite-only server (ADR-0024) an account can only be created with
/// an [invite] token; otherwise the screen points to joining with a link.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({
    super.key,
    this.signUp = false,
    this.gate = false,
    this.invite,
  });

  /// Start in "create account" mode.
  final bool signUp;

  /// The start screen of the web client, where signing in is required
  /// (ADR-0018): no back button, and a way to join with an invitation.
  final bool gate;

  /// Invitation token sent with a sign-up (ADR-0024); the caller redeems it.
  final String? invite;

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

  /// Whether the password fields show their text (eye button).
  bool _showPassword = false;
  bool _busy = false;
  String? _error;

  /// Address that still has to be confirmed (ADR-0024).
  String? _unverified;

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
      _unverified = null;
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
          invite: widget.invite,
        );
      } else {
        await backend.signIn(email: _email.text, password: _password.text);
      }
      if (mounted && !widget.gate) Navigator.of(context).pop(true);
    } on BackendException catch (e) {
      if (!mounted) return;
      if (e.kind == BackendErrorKind.emailNotVerified) {
        // The account exists; sign in once the address is confirmed.
        _log.info('Email address not confirmed yet');
        setState(() {
          _busy = false;
          _signUp = false;
          _unverified = _email.text.trim();
        });
        return;
      }
      _log.warning(_signUp ? 'Sign-up failed' : 'Sign-in failed', e);
      setState(() {
        _busy = false;
        _error = backendErrorText(AppLocalizations.of(context), e.kind);
      });
    }
  }

  Future<void> _resendVerification() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(syncBackendProvider).requestVerification(_unverified!);
      showMessageOn(messenger, l10n.accountVerifySent);
    } on BackendException catch (e) {
      _log.warning('Verification mail failed', e);
      showMessageOn(messenger, backendErrorText(l10n, e.kind));
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
      showMessageOn(messenger, l10n.accountResetSent);
    } on BackendException catch (e) {
      _log.warning('Password reset failed', e);
      showMessageOn(messenger, backendErrorText(l10n, e.kind));
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
    final config = ref.watch(serverConfigProvider).value;
    final inviteOnly = config?.inviteOnly ?? false;
    // The server no longer accepts this version (ADR-0029): say so before
    // anyone tries to sign in.
    final min = config?.minClientVersion;
    final current = ref.watch(clientVersionProvider);
    final outdated =
        min != null && current != null && isOlderThan(current, min);
    // New accounts only with an invitation on invite-only servers (ADR-0024).
    final canSignUp = !inviteOnly || widget.invite != null;
    if (!canSignUp && _signUp) _signUp = false;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.gate,
        title: Text(
          widget.gate
              ? l10n.appTitle
              : (_signUp ? l10n.accountSignUp : l10n.accountSignIn),
        ),
      ),
      body: PageWidth(
        maxWidth: formMaxWidth,
        alignment: Alignment.center,
        child: Form(
          key: _form,
          child: AutofillGroup(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                if (outdated) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: UpdateRequiredBanner(minVersion: min),
                  ),
                  const SizedBox(height: 24),
                ],
                if (widget.gate) ...[
                  const Center(child: SetdingLogo(height: 36)),
                  const SizedBox(height: 32),
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
                    suffixIcon: IconButton(
                      key: const Key('account-password-visibility'),
                      icon: Icon(
                        _showPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      tooltip: _showPassword
                          ? l10n.accountPasswordHide
                          : l10n.accountPasswordShow,
                      onPressed: () =>
                          setState(() => _showPassword = !_showPassword),
                    ),
                  ),
                  obscureText: !_showPassword,
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
                    obscureText: !_showPassword,
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
                if (_unverified case final email?) ...[
                  const SizedBox(height: 16),
                  Text(
                    l10n.accountVerifyEmail(email),
                    key: const Key('account-verify'),
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton(
                      key: const Key('account-verify-resend'),
                      onPressed: _busy ? null : _resendVerification,
                      child: Text(l10n.accountVerifyResend),
                    ),
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
                      : Text(_signUp ? l10n.accountSignUp : l10n.accountSignIn),
                ),
                const SizedBox(height: 8),
                if (canSignUp)
                  TextButton(
                    key: const Key('account-toggle'),
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                            _signUp = !_signUp;
                            _error = null;
                          }),
                    child: Text(
                      _signUp ? l10n.accountToSignIn : l10n.accountToSignUp,
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      l10n.accountInviteOnlyHint,
                      key: const Key('account-invite-only'),
                      textAlign: TextAlign.center,
                    ),
                  ),
                if (!_signUp)
                  TextButton(
                    onPressed: _busy ? null : _resetPassword,
                    child: Text(l10n.accountForgotPassword),
                  ),
                if ((widget.gate || !canSignUp) && widget.invite == null)
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
    );
  }
}

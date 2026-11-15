import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../providers.dart';
import '../../sync/auth_providers.dart';
import '../../sync/sync_backend.dart';
import '../account/sign_in_screen.dart';

/// Joins an organization with an invitation link (ADR-0005, ADR-0017):
/// opened by a deep link or by pasting the link. Signing in comes first;
/// joining needs a connection once.
class JoinScreen extends ConsumerStatefulWidget {
  const JoinScreen({super.key, this.initialLink});

  /// Link or token from a deep link.
  final String? initialLink;

  @override
  ConsumerState<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends ConsumerState<JoinScreen> {
  late final _link = TextEditingController(text: widget.initialLink ?? '');
  String? _token;
  InvitePreview? _preview;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialLink != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _check());
    }
  }

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on BackendException catch (e) {
      if (mounted) {
        setState(
          () => _error = backendErrorText(AppLocalizations.of(context), e.kind),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _check() async {
    final l10n = AppLocalizations.of(context);
    final token = inviteTokenFrom(_link.text);
    if (token == null) {
      setState(() => _error = l10n.joinInvalidLink);
      return;
    }
    _token = token;
    if (ref.read(authProvider) == null) {
      setState(() => _preview = null);
      return;
    }
    await _run(() async {
      final preview = await ref.read(syncBackendProvider).previewInvite(token);
      if (mounted) setState(() => _preview = preview);
    });
  }

  Future<void> _join() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final preview = _preview!;
    await _run(() async {
      await ref.read(syncBackendProvider).redeemInvite(_token!);
      await ref.read(bandServiceProvider).refresh();
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.joinDone(preview.organizationName))),
      );
      navigator.pop(true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final signedIn = ref.watch(authProvider) != null;
    final preview = _preview;
    final theme = Theme.of(context);

    // Continue automatically after signing in.
    ref.listen(authProvider, (previous, next) {
      if (previous == null && next != null && _token != null) _check();
    });

    return Scaffold(
      appBar: AppBar(title: Text(l10n.joinTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (preview == null) ...[
                Text(l10n.joinHint),
                const SizedBox(height: 16),
                TextField(
                  key: const Key('join-link'),
                  controller: _link,
                  decoration: InputDecoration(labelText: l10n.joinLink),
                  autocorrect: false,
                  onSubmitted: (_) => _check(),
                ),
                const SizedBox(height: 16),
                if (!signedIn && _token != null) ...[
                  Text(l10n.joinSignInFirst),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<bool>(
                        builder: (_) => const SignInScreen(),
                      ),
                    ),
                    child: Text(l10n.accountSignIn),
                  ),
                ] else
                  FilledButton(
                    key: const Key('join-continue'),
                    onPressed: _busy ? null : _check,
                    child: Text(l10n.joinContinue),
                  ),
              ] else ...[
                Text(
                  preview.alreadyMember
                      ? l10n.joinAlreadyMember(preview.organizationName)
                      : l10n.joinQuestion(preview.organizationName),
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                if (preview.status != InviteStatus.valid)
                  Text(
                    preview.status == InviteStatus.expired
                        ? l10n.inviteErrorExpired
                        : l10n.inviteErrorRevoked,
                    style: TextStyle(color: theme.colorScheme.error),
                  )
                else if (!preview.alreadyMember) ...[
                  Text(l10n.joinExplanation),
                  const SizedBox(height: 24),
                  FilledButton(
                    key: const Key('join-button'),
                    onPressed: _busy ? null : _join,
                    child: Text(l10n.joinButton),
                  ),
                ],
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  key: const Key('join-error'),
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

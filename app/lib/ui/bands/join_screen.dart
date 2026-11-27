import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/band_providers.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../data/person_name.dart';
import '../../settings/settings.dart' show nameFormatProvider;
import '../../sync/auth_providers.dart';
import '../../sync/sync_backend.dart';
import '../account/sign_in_screen.dart';
import '../widgets/dialogs.dart';
import '../widgets/page_width.dart';
import 'qr_scanner.dart';
import '../routes.dart';

/// Joins an organization with an invitation link (ADR-0005, ADR-0017):
/// opened by a deep link, by pasting the link or, on phones and tablets, by
/// scanning its QR code. The link is checked first,
/// also without an account; then the person signs in or creates an account
/// with the link (needed on invite-only servers, ADR-0024) and joins. A
/// founder invitation founds the organization instead. Joining needs a
/// connection once.
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
    await _run(() async {
      final preview = await ref.read(syncBackendProvider).previewInvite(token);
      if (mounted) setState(() => _preview = preview);
    });
  }

  Future<void> _scan() async {
    final text = await ref.read(qrScannerProvider)(context);
    if (text == null || !mounted) return;
    _link.text = text.trim();
    await _check();
  }

  Future<void> _join() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final preview = _preview!;
    await _run(() async {
      await ref.read(syncBackendProvider).redeemInvite(_token!);
      await ref.read(bandServiceProvider).refresh();
      showMessageOn(
        messenger,
        preview.founder
            ? l10n.joinFoundDone(preview.organizationName)
            : l10n.joinDone(preview.organizationName),
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
    final format = ref.watch(nameFormatProvider);

    // Continue automatically after signing in.
    ref.listen(authProvider, (previous, next) {
      if (previous == null && next != null && _token != null) _check();
    });

    return Scaffold(
      appBar: AppBar(title: Text(l10n.joinTitle)),
      body: PageWidth(
        maxWidth: formMaxWidth,
        alignment: Alignment.center,
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
              FilledButton(
                key: const Key('join-continue'),
                onPressed: _busy ? null : _check,
                child: Text(l10n.joinContinue),
              ),
              if (canScanQrCodes) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  key: const Key('join-scan'),
                  onPressed: _busy ? null : _scan,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: Text(l10n.joinScan),
                ),
              ],
            ] else ...[
              Text(
                preview.founder
                    ? l10n.joinFoundQuestion(preview.organizationName)
                    : preview.alreadyMember && !preview.personal
                    ? l10n.joinAlreadyMember(preview.organizationName)
                    : preview.bandName != null
                    ? l10n.joinQuestionBand(
                        preview.bandName!,
                        preview.organizationName,
                      )
                    : l10n.joinQuestion(preview.organizationName),
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              if (preview.contact case final contact?) ...[
                Text(
                  l10n.joinPersonal(personLabel(contact.name, format)),
                  key: const Key('join-personal'),
                ),
                const SizedBox(height: 16),
              ],
              if (preview.status != InviteStatus.valid)
                Text(switch (preview.status) {
                  InviteStatus.expired => l10n.inviteErrorExpired,
                  InviteStatus.used => l10n.inviteErrorUsed,
                  _ => l10n.inviteErrorRevoked,
                }, style: TextStyle(color: theme.colorScheme.error))
              else if (!signedIn) ...[
                Text(l10n.joinSignInFirst),
                const SizedBox(height: 16),
                FilledButton(
                  key: const Key('join-sign-up'),
                  onPressed: () => context.push<bool>(
                    AppPaths.signIn,
                    extra: signInExtra(
                      signUp: true,
                      invite: _token,
                      // A personal invitation prefills it (ADR-0064).
                      prefill: preview.contact,
                    ),
                  ),
                  child: Text(l10n.accountSignUp),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  key: const Key('join-sign-in'),
                  onPressed: () => context.push<bool>(
                    AppPaths.signIn,
                    extra: signInExtra(invite: _token),
                  ),
                  child: Text(l10n.joinHaveAccount),
                ),
              ] else if (!preview.alreadyMember || preview.personal) ...[
                Text(
                  preview.founder
                      ? l10n.joinFoundExplanation
                      : preview.contact != null && preview.alreadyMember
                      ? l10n.joinPersonalExplanation(
                          personLabel(preview.contact!.name, format),
                        )
                      : preview.bandName != null
                      ? l10n.joinExplanationBand
                      : l10n.joinExplanation,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  key: const Key('join-button'),
                  onPressed: _busy ? null : _join,
                  child: Text(
                    preview.founder
                        ? l10n.joinFoundButton
                        : preview.personal
                        ? l10n.joinPersonalButton
                        : l10n.joinButton,
                  ),
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
    );
  }
}

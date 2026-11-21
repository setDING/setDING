import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../providers.dart';
import '../../settings/settings.dart';
import '../../sync/auth_providers.dart';
import '../widgets/dialogs.dart';
import '../bands/join_screen.dart';
import 'sign_in_screen.dart';
import 'sync_tile.dart';

/// Account tiles of the settings screen: sign-in state and server.
class AccountSection extends ConsumerWidget {
  const AccountSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(authProvider);
    final serverUrl = ref.watch(settingsProvider.select((s) => s.serverUrl));

    return Column(
      children: [
        if (user == null) ...[
          ListTile(
            leading: const Icon(Icons.account_circle_outlined),
            title: Text(l10n.accountSignedOut),
            subtitle: Text(l10n.accountSignedOutHint),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(72, 0, 16, 8),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: SignedOutActions(),
            ),
          ),
        ] else
          ListTile(
            leading: const Icon(Icons.account_circle),
            title: Text(user.displayName),
            subtitle: user.displayName == user.email ? null : Text(user.email),
            trailing: OutlinedButton(
              key: const Key('account-sign-out'),
              onPressed: () async {
                final ok = await confirm(
                  context,
                  title: l10n.accountSignOutTitle,
                  message: ref.read(webClientProvider)
                      ? l10n.accountSignOutMessageWeb
                      : l10n.accountSignOutMessage,
                  action: l10n.accountSignOut,
                  destructive: false,
                );
                if (ok) await ref.read(authProvider.notifier).signOut();
              },
              child: Text(l10n.accountSignOut),
            ),
          ),
        if (user != null) const SyncTile(),
        ListTile(
          leading: const Icon(Icons.dns_outlined),
          title: Text(l10n.settingsServer),
          subtitle: Text('$serverUrl\n${l10n.settingsServerHint}'),
          isThreeLine: true,
          trailing: const Icon(Icons.edit_outlined),
          onTap: () => _editServer(context, ref, serverUrl),
        ),
      ],
    );
  }

  Future<void> _editServer(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final value = await askText(
      context,
      title: l10n.settingsServer,
      initial: current,
    );
    if (value == null) return;
    final url = normalizeServerUrl(value);
    if (url == null) {
      showMessageOn(messenger, l10n.settingsServerInvalid);
      return;
    }
    if (url == current) return;
    // A session belongs to one server.
    await ref.read(authProvider.notifier).signOut();
    await ref
        .read(settingsProvider.notifier)
        .update((s) => s.copyWith(serverUrl: url));
  }
}

/// What a signed-out user can do: sign in, or join an organization with an
/// invitation link (creating an account on the way).
class SignedOutActions extends StatelessWidget {
  const SignedOutActions({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        FilledButton(
          key: const Key('account-open-sign-in'),
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute<bool>(builder: (_) => const SignInScreen())),
          child: Text(l10n.accountSignIn),
        ),
        OutlinedButton.icon(
          key: const Key('account-open-join'),
          icon: const Icon(Icons.link),
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute<bool>(builder: (_) => const JoinScreen())),
          label: Text(l10n.accountJoin),
        ),
      ],
    );
  }
}

/// Trims the URL and removes trailing slashes; null if it is no http(s) URL.
String? normalizeServerUrl(String input) {
  var url = input.trim();
  while (url.endsWith('/')) {
    url = url.substring(0, url.length - 1);
  }
  final uri = Uri.tryParse(url);
  if (uri == null ||
      !(uri.scheme == 'http' || uri.scheme == 'https') ||
      uri.host.isEmpty) {
    return null;
  }
  return url;
}

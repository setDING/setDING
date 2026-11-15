import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../settings/settings.dart';
import '../../sync/auth_providers.dart';
import '../widgets/dialogs.dart';
import '../bands/bands_screen.dart';
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
        if (user == null)
          ListTile(
            leading: const Icon(Icons.account_circle_outlined),
            title: Text(l10n.accountSignedOut),
            subtitle: Text(l10n.accountSignedOutHint),
            trailing: FilledButton(
              key: const Key('account-open-sign-in'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<bool>(builder: (_) => const SignInScreen()),
              ),
              child: Text(l10n.accountSignIn),
            ),
          )
        else
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
                  message: l10n.accountSignOutMessage,
                  action: l10n.accountSignOut,
                );
                if (ok) await ref.read(authProvider.notifier).signOut();
              },
              child: Text(l10n.accountSignOut),
            ),
          ),
        if (user != null) const SyncTile(),
        if (user != null)
          ListTile(
            key: const Key('account-bands'),
            leading: const Icon(Icons.groups_outlined),
            title: Text(l10n.bandsTitle),
            subtitle: Text(l10n.bandManage),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const BandsScreen()),
            ),
          ),
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
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.settingsServerInvalid)),
      );
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

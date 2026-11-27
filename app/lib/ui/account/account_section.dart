import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../platform/web_client.dart';
import '../../settings/settings.dart';
import '../../sync/auth_providers.dart';
import '../widgets/dialogs.dart';
import 'change_password_dialog.dart';
import 'delete_account_dialog.dart';
import 'person_name_form.dart';
import 'sync_tile.dart';
import '../routes.dart';

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
        if (user != null) ...[
          ListTile(
            key: const Key('account-change-name'),
            leading: const Icon(Icons.badge_outlined),
            title: Text(l10n.accountChangeName),
            // The full name when the account shows only the nickname.
            subtitle: switch (user.person.format(NameFormat.fullWithNickname)) {
              final full when full.isNotEmpty && full != user.displayName =>
                Text(full),
              _ => null,
            },
            trailing: const Icon(Icons.edit_outlined),
            onTap: () async {
              final messenger = ScaffoldMessenger.of(context);
              if (await showChangeNameDialog(context)) {
                showMessageOn(messenger, l10n.accountNameChanged);
              }
            },
          ),
          ListTile(
            key: const Key('account-change-password'),
            leading: const Icon(Icons.lock_outline),
            title: Text(l10n.accountChangePassword),
            subtitle: Text(l10n.accountChangePasswordHint),
            trailing: const Icon(Icons.edit_outlined),
            onTap: () async {
              final messenger = ScaffoldMessenger.of(context);
              if (await showChangePasswordDialog(context)) {
                showMessageOn(messenger, l10n.accountPasswordChanged);
              }
            },
          ),
          const SyncTile(),
        ],
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
    // Plain http only goes unasked to a local server (issue #1199).
    if (!context.mounted) return;
    final host = insecureServerHost(url);
    if (host != null &&
        !await confirm(
          context,
          title: l10n.settingsServerHttpTitle,
          message: l10n.settingsServerHttpMessage(host),
          action: l10n.settingsServerHttpUse,
          destructive: false,
        )) {
      return;
    }
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
          onPressed: () => context.push<bool>(AppPaths.signIn),
          child: Text(l10n.accountSignIn),
        ),
        OutlinedButton.icon(
          key: const Key('account-open-join'),
          icon: const Icon(Icons.link),
          onPressed: () => context.push<bool>(AppPaths.join),
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

/// The host of [url] if it uses plain `http://` for a server that is not
/// local, so the password and token would go over the network unencrypted
/// (issue #1199); null for `https://` and for local servers.
String? insecureServerHost(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.scheme != 'http') return null;
  return isLocalHost(uri.host) ? null : uri.host;
}

/// Whether [host] is a loopback or private network address or a local name
/// (`localhost`, `*.local`, `*.localhost`, `*.test`), for which plain http is
/// fine (issue #1199).
bool isLocalHost(String host) {
  var name = host.toLowerCase();
  if (name.startsWith('[') && name.endsWith(']')) {
    name = name.substring(1, name.length - 1);
  }
  while (name.endsWith('.')) {
    name = name.substring(0, name.length - 1);
  }
  if (name.isEmpty) return false;
  if (name == 'localhost' ||
      name.endsWith('.localhost') ||
      name.endsWith('.local') ||
      name.endsWith('.test')) {
    return true;
  }
  final ipv4 = _tryParse(Uri.parseIPv4Address, name);
  if (ipv4 != null) return _isLocalIPv4(ipv4);
  final ipv6 = _tryParse(Uri.parseIPv6Address, name.split('%').first);
  if (ipv6 == null) return false;
  // ::1, the loopback address.
  if (ipv6.take(15).every((b) => b == 0) && ipv6[15] == 1) return true;
  // fe80::/10, link-local.
  if (ipv6[0] == 0xfe && ipv6[1] & 0xc0 == 0x80) return true;
  // fc00::/7, unique local addresses.
  if (ipv6[0] & 0xfe == 0xfc) return true;
  // ::ffff:a.b.c.d, an IPv4 address mapped into IPv6.
  if (ipv6.take(10).every((b) => b == 0) &&
      ipv6[10] == 0xff &&
      ipv6[11] == 0xff) {
    return _isLocalIPv4(ipv6.sublist(12));
  }
  return false;
}

List<int>? _tryParse(List<int> Function(String) parse, String host) {
  try {
    return parse(host);
  } on FormatException {
    return null;
  }
}

bool _isLocalIPv4(List<int> a) =>
    a[0] == 127 || // 127/8, loopback
    a[0] == 10 || // 10/8
    (a[0] == 172 && a[1] >= 16 && a[1] <= 31) || // 172.16/12
    (a[0] == 192 && a[1] == 168) || // 192.168/16
    (a[0] == 169 && a[1] == 254); // 169.254/16, link-local

/// Deleting the account, in the danger zone at the end of the account
/// category, shown while signed in (ADR-0052, docs/development/ui-design.md).
class DeleteAccountTile extends ConsumerWidget {
  const DeleteAccountTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final error = Theme.of(context).colorScheme.error;
    return ListTile(
      leading: Icon(Icons.person_remove_outlined, color: error),
      title: Text(l10n.accountDelete),
      subtitle: Text(l10n.accountDeleteHint),
      trailing: OutlinedButton(
        key: const Key('account-delete'),
        style: OutlinedButton.styleFrom(foregroundColor: error),
        onPressed: () async {
          final messenger = ScaffoldMessenger.of(context);
          if (await showDeleteAccountDialog(context, ref)) {
            showMessageOn(messenger, l10n.accountDeleted);
          }
        },
        child: Text(l10n.accountDelete),
      ),
    );
  }
}

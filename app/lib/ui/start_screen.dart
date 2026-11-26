import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/generated/app_localizations.dart';
import '../providers.dart';
import '../sync/auth_providers.dart';
import '../sync/sync_controller.dart';
import 'account/sign_in_screen.dart';
import 'home_screen.dart';
import 'routes.dart';
import 'widgets/logo.dart';
import 'widgets/page_width.dart';

/// The first screen. The native apps start with the [HomeScreen]; the web
/// client requires signing in and a band first (ADR-0018).
class StartScreen extends ConsumerWidget {
  const StartScreen({super.key, required this.navigation});

  /// The main navigation's tabs (ADR-0065).
  final StatefulNavigationShell navigation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(webClientProvider)) {
      return HomeScreen(navigation: navigation);
    }
    if (ref.watch(authProvider) == null) {
      return const SignInScreen(key: Key('web-sign-in'), gate: true);
    }
    final bands = ref.watch(bandsProvider).value;
    if (bands != null && bands.isNotEmpty) {
      return HomeScreen(navigation: navigation);
    }
    // The bands arrive with the first sync after signing in.
    final syncing = ref.watch(syncControllerProvider.select((s) => s.running));
    if (bands == null || syncing) {
      return const Scaffold(body: SplashScreen(busy: true));
    }
    return const _NoBandScreen();
  }
}

/// Signed in on the web, but not in any band yet.
class _NoBandScreen extends ConsumerWidget {
  const _NoBandScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      key: const Key('web-no-band'),
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: PageWidth(
        maxWidth: formMaxWidth,
        alignment: Alignment.center,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(24),
          children: [
            Text(l10n.webNoBandTitle, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(l10n.webNoBandMessage),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.groups_outlined),
              onPressed: () => context.push(AppPaths.bands),
              label: Text(l10n.bandManage),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.link),
              onPressed: () => context.push(AppPaths.join),
              label: Text(l10n.accountJoin),
            ),
            const SizedBox(height: 8),
            TextButton(
              key: const Key('web-no-band-sign-out'),
              onPressed: () => ref.read(authProvider.notifier).signOut(),
              child: Text(l10n.accountSignOut),
            ),
          ],
        ),
      ),
    );
  }
}

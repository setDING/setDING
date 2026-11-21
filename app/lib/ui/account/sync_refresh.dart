import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../sync/auth_providers.dart';
import '../../sync/sync_backend.dart';
import '../../sync/sync_controller.dart';
import 'sign_in_screen.dart' show backendErrorText;
import '../widgets/dialogs.dart';

/// Pull to refresh on a list (#384): pulling down and releasing starts a
/// sync, like "Sync now" in the settings. A failed sync is reported in a
/// snack bar; an outdated app is left to the update banner (ADR-0029).
///
/// [child] is a scrollable, or with [scrollable] false a fixed widget (an
/// empty state) that is made scrollable so it can be pulled too. Signed out
/// there is nothing to sync and [child] is shown as it is.
class SyncRefresh extends ConsumerWidget {
  const SyncRefresh({super.key, required this.child, this.scrollable = true});

  final Widget child;
  final bool scrollable;

  Future<void> _sync(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final report = await ref.read(syncControllerProvider.notifier).syncNow();
    final error = report?.error;
    if (error == null || error == BackendErrorKind.updateRequired) return;
    showMessageOn(
      messenger,
      error == BackendErrorKind.network
          ? l10n.syncOffline
          : backendErrorText(l10n, error),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(authProvider.select((u) => u != null));
    final content = scrollable
        ? child
        : LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(child: child),
              ),
            ),
          );
    if (!signedIn) return content;
    return RefreshIndicator(
      key: const Key('sync-refresh'),
      onRefresh: () => _sync(context, ref),
      child: content,
    );
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../platform/http_client.dart';
import '../platform/self_update.dart';
import '../sync/auth_providers.dart';
import '../util/log.dart';
import 'app_update.dart';

const _log = Log('update');

/// Whether this app updates itself from the GitHub releases: only the
/// Windows app installed with the setup (ADR-0035).
final selfUpdateSupportedProvider = Provider<bool>(
  (ref) => isInstalledWithSetup(),
);

/// A newer release to install, checked once per app start (and again from
/// the settings); null if this version is current or updates are not
/// supported. Fails without network; no automatic retries, so an offline
/// device does not keep asking GitHub.
final availableUpdateProvider = FutureProvider<AvailableUpdate?>((ref) async {
  if (!ref.watch(selfUpdateSupportedProvider)) return null;
  final current = ref.watch(clientVersionProvider);
  if (current == null) return null;
  final client = createHttpClient();
  try {
    final update = await fetchAvailableUpdate(client, currentVersion: current);
    if (update != null) _log.info('Update ${update.version} available');
    return update;
  } catch (e) {
    _log.warning('Update check failed', e);
    rethrow;
  } finally {
    client.close();
  }
}, retry: (_, _) => null);

/// Whether the person put off the update banner until the next start.
final updateBannerDismissedProvider =
    NotifierProvider<UpdateBannerDismissed, bool>(UpdateBannerDismissed.new);

class UpdateBannerDismissed extends Notifier<bool> {
  @override
  bool build() => false;

  void dismiss() => state = true;
}

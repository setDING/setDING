import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../platform/self_update.dart';
import '../sync/auth_providers.dart';
import '../sync/update_check.dart';
import 'app_update.dart';

/// How this app installs updates itself, or null: the Windows app installed
/// with the setup (ADR-0035) and the Linux AppImage (ADR-0038).
final selfUpdateKindProvider = Provider<SelfUpdateKind?>(
  (ref) => detectSelfUpdateKind(),
);

/// The newer version this app can install itself, or null (ADR-0035,
/// ADR-0038).
///
/// The version comes from the update check (ADR-0036); when the server
/// refuses this version (ADR-0029) before the daily check knew of a newer
/// one, from the server config, so the "Please update" banner can install
/// it directly.
final installableUpdateProvider = Provider<String?>((ref) {
  if (ref.watch(selfUpdateKindProvider) == null) return null;
  final checked = ref.watch(updateCheckProvider);
  if (checked != null) return checked;
  final current = ref.watch(clientVersionProvider);
  final latest = ref.watch(serverConfigProvider).value?.latestClientVersion;
  return latest != null && current != null && isUpdate(latest, current)
      ? latest
      : null;
});

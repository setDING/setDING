import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/settings.dart' show sharedPreferencesProvider;
import '../util/log.dart';
import '../util/semver.dart';
import 'auth_providers.dart';

const _log = Log('update');

/// Where new versions of the installed apps are published (ADR-0021).
const releasesUrl = 'https://github.com/setDING/setDING/releases';

/// The release page of [version].
Uri releasePageUrl(String version) =>
    Uri.parse('$releasesUrl/tag/v${version.replaceFirst(RegExp('^v'), '')}');

/// Whether this build looks for new releases (ADR-0036): installed release
/// builds only, not the web client (the server always serves the current
/// build), debug builds or the Android beta build. Overridden in main().
final updateCheckEnabledProvider = Provider<bool>((ref) => false);

/// Whether [latest] is worth pointing to from [current]: newer, and a
/// pre-release only for people who already run a pre-release.
bool isUpdate(String latest, String current) =>
    compareVersions(latest, current) > 0 &&
    (!isPrerelease(latest) || isPrerelease(current));

/// The newer app version that is available, or null (ADR-0036).
///
/// Asks the server (`/api/setding/config`, `latestClientVersion`) a few
/// seconds after the start, at most once per [interval]; the answer is kept
/// on the device, so the hint stays while offline. Errors are silent.
final updateCheckProvider = NotifierProvider<UpdateCheck, String?>(
  UpdateCheck.new,
);

class UpdateCheck extends Notifier<String?> {
  /// How often the server is asked at most.
  static const interval = Duration(hours: 24);

  /// Delay after the start, so the check never competes with opening the app.
  static const startDelay = Duration(seconds: 5);

  static const _latestKey = 'updateCheck.latest';
  static const _checkedAtKey = 'updateCheck.checkedAt';
  static const _notifiedKey = 'updateCheck.notified';

  @override
  String? build() {
    if (!ref.watch(updateCheckEnabledProvider)) return null;
    final current = ref.watch(clientVersionProvider);
    if (current == null) return null;
    final prefs = ref.watch(sharedPreferencesProvider);
    final checkedAt = prefs.getInt(_checkedAtKey);
    final due =
        checkedAt == null ||
        DateTime.now().difference(
              DateTime.fromMillisecondsSinceEpoch(checkedAt),
            ) >=
            interval;
    if (due) {
      final timer = Timer(startDelay, () => _check(current));
      ref.onDispose(timer.cancel);
    }
    return _available(prefs.getString(_latestKey), current);
  }

  Future<void> _check(String current) async {
    try {
      final config = await ref.read(syncBackendProvider).fetchServerConfig();
      if (!ref.mounted) return;
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setInt(_checkedAtKey, DateTime.now().millisecondsSinceEpoch);
      // Kept when the server does not say (older server, working-tree
      // deploy), so a known update does not disappear.
      if (config.latestClientVersion case final latest?) {
        await prefs.setString(_latestKey, latest);
      }
      if (!ref.mounted) return;
      state = _available(prefs.getString(_latestKey), current);
    } catch (e) {
      _log.info('Update check failed: $e');
    }
  }

  static String? _available(String? latest, String current) =>
      latest != null && isUpdate(latest, current) ? latest : null;

  /// Whether the one-time hint for [version] is still to be shown.
  bool shouldNotify(String version) =>
      ref.read(sharedPreferencesProvider).getString(_notifiedKey) != version;

  /// The one-time hint for [version] was shown.
  Future<void> markNotified(String version) =>
      ref.read(sharedPreferencesProvider).setString(_notifiedKey, version);
}

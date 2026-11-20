import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Application ID of the beta build (`make android-install`,
/// docs/development/releases.md).
const betaPackageName = 'app.setding.beta';

/// Commit the app was built from, set by `make android-install` with
/// `--dart-define=SETDING_BUILD_COMMIT=…`; empty in release builds.
const buildCommit = String.fromEnvironment('SETDING_BUILD_COMMIT');

/// The displayed version of the running app, e.g. `0.1.1 (3)`: the version
/// from `pubspec.yaml` and the build number (Android `versionCode`), which the
/// release workflow sets (ADR-0021). A beta build adds `beta` and its commit,
/// e.g. `0.1.1 (1, beta, 39f2c1b)`.
///
/// Only for display and the diagnostic log: the version sent to the server
/// and used for "What's new" stays the plain `PackageInfo.version`
/// (ADR-0029, ADR-0041).
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return formatAppVersion(
    info.version,
    info.buildNumber,
    beta: info.packageName == betaPackageName,
    commit: buildCommit,
  );
});

/// [version] with the [build] number, `beta` and the [commit] in parentheses,
/// as far as there are any.
String formatAppVersion(
  String version,
  String build, {
  bool beta = false,
  String commit = '',
}) {
  final details = [
    if (build.isNotEmpty && build != version) build,
    if (beta) 'beta',
    if (commit.isNotEmpty) commit,
  ];
  return details.isEmpty ? version : '$version (${details.join(', ')})';
}

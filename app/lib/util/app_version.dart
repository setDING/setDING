import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// The version of the running app, e.g. `0.1.1 (3)`: the version from
/// `pubspec.yaml` and the build number (Android `versionCode`), which the
/// release workflow sets (ADR-0021).
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return formatAppVersion(info.version, info.buildNumber);
});

/// [version] with the [build] number in parentheses, if there is one.
String formatAppVersion(String version, String build) =>
    build.isEmpty || build == version ? version : '$version ($build)';

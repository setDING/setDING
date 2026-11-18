/// Updates of the Windows app from the GitHub releases (ADR-0035).
///
/// The installed app (Inno Setup) looks for a newer release, downloads its
/// setup, checks it against the release's `SHA256SUMS` and runs it silently.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../util/semver.dart';

/// The GitHub repository whose releases carry the setup (ADR-0021).
const updateRepository = 'tafli/setDING';

/// The end of the setup's file name in a release
/// (`setding-<version>-windows-x64-setup.exe`).
const setupSuffix = '-windows-x64-setup.exe';

/// Arguments for an update without questions: Inno Setup closes the running
/// app, installs over it and starts it again (`[Run]` without
/// `skipifsilent`, `app/windows/installer/setding.iss`).
const installerArguments = ['/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART'];

/// A newer release with a setup for this app.
class AvailableUpdate {
  const AvailableUpdate({
    required this.version,
    required this.setupName,
    required this.setupUrl,
    required this.sha256,
  });

  /// The release version without `v`, e.g. `0.9.0`.
  final String version;

  /// The file name of the setup.
  final String setupName;

  /// Where the setup is downloaded from.
  final Uri setupUrl;

  /// The expected SHA-256 of the setup, lower-case hex.
  final String sha256;
}

/// The update could not be checked, downloaded or verified.
class UpdateException implements Exception {
  const UpdateException(this.message);

  final String message;

  @override
  String toString() => 'UpdateException: $message';
}

/// The newest release if it is newer than [currentVersion] and has a setup
/// with a checksum; null if there is none. GitHub's "latest" release is never
/// a draft or pre-release, so beta tags are not offered (ADR-0021).
Future<AvailableUpdate?> fetchAvailableUpdate(
  http.Client client, {
  required String currentVersion,
  String repository = updateRepository,
}) async {
  final response = await client.get(
    Uri.https('api.github.com', '/repos/$repository/releases/latest'),
    headers: const {'Accept': 'application/vnd.github+json'},
  );
  // No release published yet.
  if (response.statusCode == 404) return null;
  if (response.statusCode != 200) {
    throw UpdateException('GitHub answered ${response.statusCode}');
  }
  final release = jsonDecode(response.body) as Map<String, dynamic>;
  if (release['draft'] == true || release['prerelease'] == true) return null;
  final tag = release['tag_name'];
  if (tag is! String) throw const UpdateException('release without a tag');
  final version = tag.startsWith('v') ? tag.substring(1) : tag;
  if (compareVersions(version, currentVersion) <= 0) return null;

  final assets = [
    for (final a in (release['assets'] as List? ?? const []))
      if (a is Map<String, dynamic> &&
          a['name'] is String &&
          a['browser_download_url'] is String)
        (a['name'] as String, Uri.parse(a['browser_download_url'] as String)),
  ];
  final setup = assets.where((a) => a.$1.endsWith(setupSuffix)).firstOrNull;
  final sums = assets.where((a) => a.$1 == 'SHA256SUMS').firstOrNull;
  // A release without a Windows setup (e.g. built before ADR-0035).
  if (setup == null || sums == null) return null;

  final sumsResponse = await client.get(sums.$2);
  if (sumsResponse.statusCode != 200) {
    throw UpdateException('SHA256SUMS: HTTP ${sumsResponse.statusCode}');
  }
  final hash = parseSha256Sums(sumsResponse.body)[setup.$1];
  if (hash == null) throw UpdateException('no checksum for ${setup.$1}');
  return AvailableUpdate(
    version: version,
    setupName: setup.$1,
    setupUrl: setup.$2,
    sha256: hash,
  );
}

/// File name → lower-case SHA-256 from the output of `sha256sum`
/// (`<hash>  <name>`, or `<hash> *<name>` in binary mode).
Map<String, String> parseSha256Sums(String text) {
  final line = RegExp(r'^([0-9a-fA-F]{64}) [ *](.+)$');
  return {
    for (final l in const LineSplitter().convert(text))
      if (line.firstMatch(l.trim()) case final m?)
        m.group(2)!: m.group(1)!.toLowerCase(),
  };
}

/// Updates of the Windows app from the GitHub releases (ADR-0035).
///
/// Which version is current comes from the update check (ADR-0036); the
/// installed app (Inno Setup) downloads that release's setup, checks it
/// against the release's `SHA256SUMS` and runs it silently.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../sync/update_check.dart' show releasesUrl;

/// The end of the setup's file name in a release
/// (`setding-<version>-windows-x64-setup.exe`).
const setupSuffix = '-windows-x64-setup.exe';

/// Arguments for an update without questions: Inno Setup closes the running
/// app, installs over it and starts it again (`[Run]` without
/// `skipifsilent`, `app/windows/installer/setding.iss`).
const installerArguments = ['/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART'];

/// Where the file [name] of the release of [version] is downloaded from.
Uri releaseFileUrl(String version, String name) =>
    Uri.parse('$releasesUrl/download/v$version/$name');

/// The setup of a release with its expected checksum.
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

/// The update could not be downloaded or verified.
class UpdateException implements Exception {
  const UpdateException(this.message);

  final String message;

  @override
  String toString() => 'UpdateException: $message';
}

/// The setup of the release of [version] (from the update check, ADR-0036)
/// and its checksum from the release's `SHA256SUMS`. Throws
/// [UpdateException] if the release has no setup with a checksum (e.g. one
/// built before ADR-0035).
Future<AvailableUpdate> fetchUpdate(http.Client client, String version) async {
  final name = 'setding-$version$setupSuffix';
  final response = await client.get(releaseFileUrl(version, 'SHA256SUMS'));
  if (response.statusCode != 200) {
    throw UpdateException('SHA256SUMS: HTTP ${response.statusCode}');
  }
  final hash = parseSha256Sums(response.body)[name];
  if (hash == null) throw UpdateException('no checksum for $name');
  return AvailableUpdate(
    version: version,
    setupName: name,
    setupUrl: releaseFileUrl(version, name),
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

import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';

import 'inputs.dart';

/// What a shipped archive (APK, zip, tar.gz) contains, as far as the SBOM
/// needs it.
class ArchiveContents {
  ArchiveContents({required this.assetPackages, required this.fileHashes});

  /// Packages with files under `flutter_assets/packages/<name>/` (apps) or
  /// `pb_public/assets/packages/<name>/` (the web client of a server bundle).
  final Set<String> assetPackages;

  /// SHA-256 per file name (last path segment) of every file in the archive.
  /// A name that occurs more than once with different content maps to null.
  final Map<String, String?> fileHashes;
}

/// SHA-256 of a file as lower-case hex.
String sha256OfFile(String path) {
  final file = File(path);
  if (!file.existsSync()) throw SbomException('$path does not exist');
  return sha256.convert(file.readAsBytesSync()).toString();
}

/// Reads [path] (`.apk`, `.zip`, `.tar.gz`) and collects its contents.
ArchiveContents readArchive(String path) {
  final file = File(path);
  if (!file.existsSync()) throw SbomException('$path does not exist');
  final bytes = file.readAsBytesSync();
  final Archive archive;
  if (path.endsWith('.tar.gz') || path.endsWith('.tgz')) {
    archive = TarDecoder().decodeBytes(GZipDecoder().decodeBytes(bytes));
  } else if (path.endsWith('.zip') || path.endsWith('.apk')) {
    archive = ZipDecoder().decodeBytes(bytes);
  } else {
    throw SbomException('$path: unsupported archive (apk, zip, tar.gz)');
  }
  return contentsOf([
    for (final entry in archive)
      if (entry.isFile) (entry.name, entry.readBytes() ?? const <int>[]),
  ]);
}

/// Collects [ArchiveContents] from (path, bytes) pairs.
ArchiveContents contentsOf(Iterable<(String, List<int>)> files) {
  final assetPackages = <String>{};
  final hashes = <String, String?>{};
  for (final (path, bytes) in files) {
    final segments = path.replaceAll(r'\', '/').split('/');
    final assets = segments.indexOf('flutter_assets');
    if (assets >= 0 &&
        assets + 2 < segments.length &&
        segments[assets + 1] == 'packages') {
      assetPackages.add(segments[assets + 2]);
    }
    final public = segments.indexOf('pb_public');
    if (public >= 0 &&
        public + 3 < segments.length &&
        segments[public + 1] == 'assets' &&
        segments[public + 2] == 'packages') {
      assetPackages.add(segments[public + 3]);
    }
    final name = segments.last;
    final hash = sha256.convert(bytes).toString();
    hashes[name] = hashes.containsKey(name) && hashes[name] != hash
        ? null
        : hash;
  }
  return ArchiveContents(assetPackages: assetPackages, fileHashes: hashes);
}

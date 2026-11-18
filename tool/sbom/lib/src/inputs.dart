import 'dart:convert';

import 'package:yaml/yaml.dart';

/// Thrown when an SBOM cannot be generated or checked; the message says why.
class SbomException implements Exception {
  SbomException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// A release platform: its name in properties and file names, its key in
/// `.flutter-plugins-dependencies` and its key in `native_assets.json`.
enum Platform {
  android('android', 'android', 'android_arm64'),
  linuxX64('linux-x64', 'linux', 'linux_x64'),
  windowsX64('windows-x64', 'windows', 'windows_x64');

  const Platform(this.id, this.pluginKey, this.nativeAssetsKey);

  final String id;
  final String pluginKey;
  final String nativeAssetsKey;

  static Platform parse(String id) => Platform.values.firstWhere(
    (p) => p.id == id,
    orElse: () => throw SbomException(
      'unknown platform "$id" (${Platform.values.map((p) => p.id).join(', ')})',
    ),
  );
}

/// A package from `pubspec.lock`.
class LockedPackage {
  LockedPackage({
    required this.name,
    required this.version,
    required this.source,
    this.sha256,
  });

  final String name;
  final String version;

  /// `hosted`, `path`, `sdk` or `git`.
  final String source;

  /// SHA-256 of the package archive on pub.dev (hosted packages only).
  final String? sha256;
}

/// Parses `pubspec.lock`.
Map<String, LockedPackage> parseLock(String text) {
  final doc = loadYaml(text) as YamlMap;
  final packages = (doc['packages'] as YamlMap?) ?? YamlMap();
  return {
    for (final entry in packages.entries)
      entry.key as String: LockedPackage(
        name: entry.key as String,
        version: '${(entry.value as YamlMap)['version']}',
        source: '${(entry.value as YamlMap)['source']}',
        sha256: switch ((entry.value as YamlMap)['description']) {
          final YamlMap d => d['sha256'] as String?,
          _ => null,
        },
      ),
  };
}

/// Reads the `version` of a `pubspec.yaml` without build metadata (`1.2.3+4` → `1.2.3`).
String pubspecVersion(String text) {
  final version = (loadYaml(text) as YamlMap)['version'];
  if (version == null) throw SbomException('pubspec.yaml has no version');
  return '$version'.split('+').first;
}

/// The packages with compiled code in the AOT snapshot, from the file written
/// by `--extra-gen-snapshot-options=--print-instructions-sizes-to=<file>`.
Set<String> compiledPackages(String instructionSizesJson) {
  final entries = jsonDecode(instructionSizesJson) as List;
  final packages = <String>{};
  for (final entry in entries) {
    final library = (entry as Map)['l'];
    if (library is String && library.startsWith('package:')) {
      packages.add(library.substring('package:'.length).split('/').first);
    }
  }
  if (packages.isEmpty) {
    throw SbomException(
      'the instruction sizes file names no package libraries',
    );
  }
  return packages;
}

/// The plugins Flutter registers for [platform] in a release build, from
/// `.flutter-plugins-dependencies` (dev dependency plugins are left out).
Set<String> pluginsFor(
  String flutterPluginsDependenciesJson,
  Platform platform,
) {
  final plugins =
      (jsonDecode(flutterPluginsDependenciesJson) as Map)['plugins'] as Map;
  final list = (plugins[platform.pluginKey] as List?) ?? const [];
  return {
    for (final plugin in list)
      if ((plugin as Map)['dev_dependency'] != true) plugin['name'] as String,
  };
}

/// The native code assets of [platform] from `native_assets.json`: shipped file
/// name → asset id (`package:<name>/…`).
Map<String, String> nativeAssets(String nativeAssetsJson, Platform platform) {
  final all = (jsonDecode(nativeAssetsJson) as Map)['native-assets'] as Map;
  final assets = (all[platform.nativeAssetsKey] as Map?) ?? const {};
  return {
    for (final MapEntry(:key, :value) in assets.entries)
      ((value as List).last as String).split('/').last: key as String,
  };
}

/// The package that provides an asset id (`package:sqlite3/src/…` → `sqlite3`).
String assetPackage(String assetId) {
  if (!assetId.startsWith('package:')) {
    throw SbomException('native asset "$assetId" has no package');
  }
  return assetId.substring('package:'.length).split('/').first;
}

/// The dependency graph from `flutter pub deps --json`: package → its dependencies.
Map<String, List<String>> pubDependencies(String pubDepsJson) {
  final packages = (jsonDecode(pubDepsJson) as Map)['packages'] as List;
  return {
    for (final p in packages)
      (p as Map)['name'] as String: [
        for (final d in (p['dependencies'] as List? ?? const [])) d as String,
      ],
  };
}

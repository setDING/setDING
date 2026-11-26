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
  windowsX64('windows-x64', 'windows', 'windows_x64'),

  /// The server bundles (ADR-0063): PocketBase and the web client, whose
  /// plugins are the web ones; they have no native assets of build hooks.
  serverLinuxAmd64('server-linux-amd64', 'web', 'web'),
  serverLinuxArm64('server-linux-arm64', 'web', 'web');

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

/// The packages with code in the web client (dart2js), from the source map of
/// `main.dart.js`: hosted packages by their pub cache directory
/// (`…/hosted/pub.dev/<name>-<version>/lib/…`), others by the directory in
/// front of `/lib/` when that is a package of [lock] (path and SDK packages).
Set<String> compiledPackagesFromSourceMap(
  String sourceMapJson,
  Map<String, LockedPackage> lock,
) {
  final sources =
      (jsonDecode(sourceMapJson) as Map)['sources'] as List? ?? const [];
  final hosted = RegExp(r'/hosted/[^/]+/([a-z0-9_]+)-\d[^/]*/lib/');
  final other = RegExp(r'(?:^|/)([a-z0-9_]+)/lib/');
  final packages = <String>{};
  for (final source in sources) {
    final path = source as String;
    final h = hosted.firstMatch(path);
    if (h != null) {
      packages.add(h.group(1)!);
      continue;
    }
    final o = other.firstMatch(path);
    if (o != null && lock.containsKey(o.group(1))) packages.add(o.group(1)!);
  }
  if (packages.isEmpty) {
    throw SbomException('the source map names no package libraries');
  }
  return packages;
}

/// A Go module from a binary's build information.
class GoModule {
  GoModule(this.path, this.version, [this.sum]);

  final String path;

  /// With `v`, as Go writes it (`v1.2.3`).
  final String version;

  /// The `go.sum` hash (`h1:…`), if any.
  final String? sum;
}

/// The build information Go embeds in a binary (`go version -m <binary>`).
class GoBuildInfo {
  GoBuildInfo({
    required this.goVersion,
    required this.main,
    required this.deps,
  });

  /// Without `go` (`1.27.4`).
  final String goVersion;
  final GoModule main;
  final List<GoModule> deps;
}

/// Parses the output of `go version -m <binary>`. Replaced modules (`=>`) are
/// not supported: the SBOM would name a module that is not in the binary.
GoBuildInfo parseGoBuildInfo(String text) {
  String? goVersion;
  GoModule? main;
  final deps = <GoModule>[];
  for (final line in const LineSplitter().convert(text)) {
    if (goVersion == null) {
      final m = RegExp(r':\s+go([0-9][^\s]*)').firstMatch(line);
      if (m != null) {
        goVersion = m.group(1)!.split('-').first;
        continue;
      }
    }
    final fields = line.trim().split('\t');
    switch (fields.first) {
      case 'mod' when fields.length >= 3:
        main = GoModule(
          fields[1],
          fields[2],
          fields.length > 3 ? fields[3] : null,
        );
      case 'dep' when fields.length >= 3:
        deps.add(
          GoModule(fields[1], fields[2], fields.length > 3 ? fields[3] : null),
        );
      case '=>':
        throw SbomException(
          'replaced Go module ${fields.skip(1).join(' ')} is not supported',
        );
    }
  }
  if (goVersion == null || main == null) {
    throw SbomException('no Go build information (go version -m)');
  }
  return GoBuildInfo(goVersion: goVersion, main: main, deps: deps);
}

import 'dart:math';

import 'inputs.dart';

const appName = 'setDING';
const repository = 'https://github.com/tafli/setDING';
const website = 'https://setding.app';
const specVersion = '1.6';

/// Version of this generator, reported in `metadata.tools`.
const toolVersion = '1.0.0';

/// Everything an SBOM is generated from. Collected by the command line from
/// the build (see bin/sbom.dart) and kept free of I/O, so it can be tested.
class BomInput {
  BomInput({
    required this.platform,
    required this.version,
    required this.artifactName,
    required this.artifactSha256,
    required this.flutterVersion,
    required this.lock,
    required this.compiled,
    required this.plugins,
    required this.assetPackages,
    required this.nativeAssets,
    required this.nativeFileHashes,
    required this.pubDependencies,
    required this.licenses,
    this.rootPackage = 'setding',
    this.build,
    this.commit,
    this.gradleBom,
    this.extraComponents = const [],
    this.extraDependencies = const {},
    DateTime? timestamp,
    String? serialNumber,
  }) : timestamp = timestamp ?? DateTime.now().toUtc(),
       serialNumber = serialNumber ?? _randomUuid();

  final Platform platform;

  /// Release version without `v` (e.g. `0.13.0`).
  final String version;

  /// File name of the asset the SBOM describes.
  final String artifactName;
  final String artifactSha256;
  final String flutterVersion;
  final String rootPackage;
  final String? build;
  final String? commit;

  final Map<String, LockedPackage> lock;

  /// Packages with code in the AOT snapshot.
  final Set<String> compiled;

  /// Plugins registered for the platform (release build).
  final Set<String> plugins;

  /// Packages with files under `flutter_assets/packages/`.
  final Set<String> assetPackages;

  /// Shipped native library file name → asset id (`package:<name>/…`).
  final Map<String, String> nativeAssets;

  /// SHA-256 per file name in the shipped archive.
  final Map<String, String?> nativeFileHashes;

  /// Package → dependencies (`flutter pub deps --json`).
  final Map<String, List<String>> pubDependencies;

  /// SPDX licence ids per hosted package that is shipped.
  final Map<String, List<String>> licenses;

  /// CycloneDX document of the CycloneDX Gradle plugin (Android only).
  final Map<String, Object?>? gradleBom;

  /// Further CycloneDX components shipped in the asset (e.g. the Visual C++
  /// runtime), taken over as they are.
  final List<Map<String, Object?>> extraComponents;

  /// Dependencies of and on [extraComponents] (bom-ref → bom-refs), e.g.
  /// PocketBase → its Go modules. An extra component that another one depends
  /// on is not attached to the root.
  final Map<String, Set<String>> extraDependencies;

  final DateTime timestamp;
  final String serialNumber;
}

/// The Dart packages shipped in the asset: compiled code, bundled assets,
/// plugins of the platform, providers of native assets. Packages of the
/// Flutter SDK (`source: sdk`) are part of the Flutter component.
Set<String> shippedPackages({
  required Map<String, LockedPackage> lock,
  required Set<String> compiled,
  required Set<String> plugins,
  required Set<String> assetPackages,
  required Map<String, String> nativeAssets,
  String rootPackage = 'setding',
}) {
  final names = {
    ...compiled,
    ...plugins,
    ...assetPackages,
    for (final id in nativeAssets.values) assetPackage(id),
  }..remove(rootPackage);
  final unknown = names.where((n) => !lock.containsKey(n)).toList()..sort();
  if (unknown.isNotEmpty) {
    throw SbomException(
      'shipped but not in pubspec.lock: ${unknown.join(', ')}',
    );
  }
  return {
    for (final n in names)
      if (lock[n]!.source != 'sdk') n,
  };
}

String pubRef(LockedPackage p) => p.source == 'hosted'
    ? 'pkg:pub/${p.name}@${p.version}'
    : 'setding:package/${p.name}@${p.version}';

String flutterRef(String version) => 'pkg:github/flutter/flutter@$version';

/// Builds the CycloneDX document.
Map<String, Object?> buildBom(BomInput input) {
  final rootRef = 'setding-${input.platform.id}';
  final fRef = flutterRef(input.flutterVersion);
  final shipped = shippedPackages(
    lock: input.lock,
    compiled: input.compiled,
    plugins: input.plugins,
    assetPackages: input.assetPackages,
    nativeAssets: input.nativeAssets,
    rootPackage: input.rootPackage,
  );

  final components = <Map<String, Object?>>[];
  final edges = <String, Set<String>>{
    rootRef: {fRef},
  };
  final refOfPackage = <String, String>{};

  // Dart packages.
  for (final name in shipped.toList()..sort()) {
    final p = input.lock[name]!;
    final ref = pubRef(p);
    refOfPackage[name] = ref;
    if (p.source == 'hosted') {
      final licenses = input.licenses[name];
      if (licenses == null || licenses.isEmpty) {
        throw SbomException('$name ${p.version}: no licence');
      }
      components.add({
        'type': 'library',
        'bom-ref': ref,
        'name': name,
        'version': p.version,
        'purl': ref,
        if (p.sha256 != null)
          'hashes': [
            {'alg': 'SHA-256', 'content': p.sha256},
          ],
        'licenses': [
          for (final id in licenses)
            {
              'license': {'id': id},
            },
        ],
        'externalReferences': [
          {
            'type': 'distribution',
            'url': 'https://pub.dev/packages/$name/versions/${p.version}',
          },
        ],
      });
    } else if (p.source == 'path') {
      // First-party packages of this repository (packages/…).
      components.add({
        'type': 'library',
        'bom-ref': ref,
        'name': name,
        'version': p.version,
        'licenses': [
          {
            'license': {'id': 'MIT'},
          },
        ],
        'externalReferences': [
          {'type': 'vcs', 'url': repository},
        ],
        'properties': [
          {'name': 'setding:source', 'value': 'path'},
        ],
      });
    } else {
      throw SbomException(
        '$name: unsupported package source "${p.source}" in pubspec.lock',
      );
    }
  }

  // Dependency graph of the Dart packages, restricted to shipped packages.
  final rootDeps = input.pubDependencies[input.rootPackage] ?? const [];
  edges[rootRef]!.addAll([
    for (final d in rootDeps)
      if (refOfPackage[d] != null) refOfPackage[d]!,
  ]);
  for (final name in shipped) {
    edges[refOfPackage[name]!] = {
      for (final d in input.pubDependencies[name] ?? const <String>[])
        if (refOfPackage[d] != null) refOfPackage[d]!,
    };
  }

  // Native libraries built or downloaded by the packages' build hooks.
  for (final MapEntry(key: file, value: id)
      in (input.nativeAssets.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key)))) {
    if (!input.nativeFileHashes.containsKey(file)) {
      throw SbomException('native asset $file ($id) is not in the asset');
    }
    final hash = input.nativeFileHashes[file];
    if (hash == null) {
      throw SbomException('native asset $file occurs twice in the asset');
    }
    final provider = assetPackage(id);
    final ref = 'setding:native/$provider/$file';
    components.add({
      'type': 'library',
      'bom-ref': ref,
      'name': file,
      'hashes': [
        {'alg': 'SHA-256', 'content': hash},
      ],
      'properties': [
        {'name': 'setding:native-asset', 'value': id},
        {'name': 'setding:provided-by', 'value': provider},
      ],
    });
    (edges[refOfPackage[provider]!] ??= {}).add(ref);
  }

  // Flutter engine and framework (including the Dart runtime and the SDK
  // packages flutter, flutter_localizations, sky_engine).
  components.add({
    'type': 'framework',
    'bom-ref': fRef,
    'name': 'flutter',
    'version': input.flutterVersion,
    'purl': fRef,
    'licenses': [
      {
        'license': {'id': 'BSD-3-Clause'},
      },
    ],
    'externalReferences': [
      {'type': 'website', 'url': 'https://flutter.dev'},
      {'type': 'vcs', 'url': 'https://github.com/flutter/flutter'},
    ],
  });

  if (input.gradleBom != null) {
    _mergeGradle(
      input.gradleBom!,
      rootRef,
      fRef,
      refOfPackage,
      components,
      edges,
    );
  }

  final dependedOn = {
    for (final targets in input.extraDependencies.values) ...targets,
  };
  for (final extra in input.extraComponents) {
    final ref = extra['bom-ref'];
    if (ref is! String || extra['name'] is! String) {
      throw SbomException('extra component without name or bom-ref: $extra');
    }
    components.add(extra);
    if (!dependedOn.contains(ref)) edges[rootRef]!.add(ref);
  }
  for (final MapEntry(key: from, value: targets)
      in input.extraDependencies.entries) {
    (edges[from] ??= {}).addAll(targets);
  }

  final refs = {for (final c in components) c['bom-ref'] as String};
  final duplicates = components.length - refs.length;
  if (duplicates > 0) throw SbomException('$duplicates duplicate bom-refs');

  final tag = 'v${input.version}';
  return {
    'bomFormat': 'CycloneDX',
    'specVersion': specVersion,
    'serialNumber': 'urn:uuid:${input.serialNumber}',
    'version': 1,
    'metadata': {
      'timestamp': _iso(input.timestamp),
      'tools': {
        'components': [
          {
            'type': 'application',
            'name': 'setding-sbom',
            'version': toolVersion,
            'externalReferences': [
              {'type': 'vcs', 'url': '$repository/tree/main/tool/sbom'},
            ],
          },
        ],
      },
      'component': {
        'type': 'application',
        'bom-ref': rootRef,
        'name': appName,
        'version': input.version,
        'purl': 'pkg:github/tafli/setDING@$tag',
        'supplier': _supplier,
        'licenses': [
          {
            'license': {'id': 'MIT'},
          },
        ],
        'hashes': [
          {'alg': 'SHA-256', 'content': input.artifactSha256},
        ],
        'externalReferences': [
          {'type': 'website', 'url': website},
          {'type': 'vcs', 'url': repository},
          {'type': 'distribution', 'url': '$repository/releases/tag/$tag'},
        ],
        'properties': [
          {'name': 'setding:platform', 'value': input.platform.id},
          {'name': 'setding:artifact', 'value': input.artifactName},
          if (input.build != null)
            {'name': 'setding:build', 'value': input.build},
          if (input.commit != null)
            {'name': 'setding:commit', 'value': input.commit},
        ],
      },
      'supplier': _supplier,
    },
    'components': components,
    'dependencies': [
      for (final ref in [rootRef, ...refs])
        {'ref': ref, 'dependsOn': (edges[ref] ?? <String>{}).toList()..sort()},
    ],
  };
}

const _supplier = {
  'name': 'setDING',
  'url': [website],
};

/// Takes the Maven components of the Gradle plugin's document. Not shipped
/// or represented elsewhere, and therefore removed:
/// - the Gradle projects (the app and the Flutter plugins): the app is the
///   root, a plugin is its Dart package;
/// - `io.flutter` artifacts: the Flutter component;
/// - `type=pom` entries (BOMs and Kotlin multiplatform root modules): no
///   code; their dependencies are attached to whoever depended on them.
void _mergeGradle(
  Map<String, Object?> gradle,
  String rootRef,
  String flutterRef,
  Map<String, String> refOfPackage,
  List<Map<String, Object?>> components,
  Map<String, Set<String>> edges,
) {
  final gradleRoot =
      ((gradle['metadata'] as Map?)?['component'] as Map?)?['bom-ref'];
  final alias = <String, String?>{}; // ref → replacement, null = splice
  if (gradleRoot is String) alias[gradleRoot] = rootRef;
  final kept = <String>{};
  for (final c in (gradle['components'] as List? ?? const [])) {
    final component = Map<String, Object?>.from(c as Map);
    final ref = component['bom-ref'] as String;
    final purl = (component['purl'] as String?) ?? '';
    final project = RegExp(r'project_path=%3A([^&]+)').firstMatch(purl);
    if (project != null) {
      alias[ref] = refOfPackage[Uri.decodeComponent(project.group(1)!)];
    } else if (component['group'] == 'io.flutter') {
      alias[ref] = flutterRef;
    } else if (purl.contains('type=pom')) {
      alias[ref] = null;
    } else {
      component.remove('properties');
      components.add(component);
      kept.add(ref);
    }
  }

  final dependsOn = <String, List<String>>{
    for (final d in (gradle['dependencies'] as List? ?? const []))
      (d as Map)['ref'] as String: [
        for (final r in (d['dependsOn'] as List? ?? const [])) r as String,
      ],
  };

  Set<String> resolve(String ref, Set<String> seen) {
    if (kept.contains(ref)) return {ref};
    if (!seen.add(ref)) return {};
    if (alias.containsKey(ref) && alias[ref] != null) return {alias[ref]!};
    return {
      for (final d in dependsOn[ref] ?? const <String>[]) ...resolve(d, seen),
    };
  }

  for (final MapEntry(key: from, value: targets) in dependsOn.entries) {
    final String? owner;
    if (kept.contains(from)) {
      owner = from;
    } else if (alias.containsKey(from) && alias[from] != null) {
      owner = alias[from];
    } else {
      continue; // spliced: its edges reach the owners through resolve()
    }
    if (owner == flutterRef) continue;
    final set = edges[owner!] ??= {};
    for (final t in targets) {
      set.addAll(resolve(t, {from}).where((r) => r != owner));
    }
  }
}

String _iso(DateTime t) => '${t.toUtc().toIso8601String().split('.').first}Z';

String _randomUuid() {
  final r = Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
      '${h.substring(16, 20)}-${h.substring(20)}';
}

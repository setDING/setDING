import 'dart:math';

import 'bom.dart';
import 'inputs.dart';

/// What a server bundle ships besides the web client's Dart packages
/// (ADR-0037, ADR-0063): PocketBase with its Go modules and the Go standard
/// library, and the web client's `sqlite3.wasm`. Passed to [buildBom] as
/// extra components and dependencies.
class ServerParts {
  ServerParts(this.components, this.dependencies);

  final List<Map<String, Object?>> components;
  final Map<String, Set<String>> dependencies;
}

String goRef(String path, String version) => 'pkg:golang/$path@$version';

/// The extra components of a server bundle for [arch] (`amd64`, `arm64`).
/// [fileHashes] are those of the bundle (the `pocketbase` binary and
/// `sqlite3.wasm` must be in it), [goLicenses] the SPDX ids per Go module path
/// (the main module included).
ServerParts serverParts({
  required String arch,
  required GoBuildInfo go,
  required Map<String, List<String>> goLicenses,
  required Map<String, String?> fileHashes,
  required Map<String, LockedPackage> lock,
}) {
  List<Map<String, Object?>> licensesOf(String path) {
    final ids = goLicenses[path];
    if (ids == null || ids.isEmpty) throw SbomException('$path: no licence');
    return [
      for (final id in ids)
        {
          'license': {'id': id},
        },
    ];
  }

  String hashOf(String file) {
    if (!fileHashes.containsKey(file)) {
      throw SbomException('$file is not in the bundle');
    }
    final hash = fileHashes[file];
    if (hash == null) throw SbomException('$file occurs twice in the bundle');
    return hash;
  }

  final components = <Map<String, Object?>>[];
  final dependencies = <String, Set<String>>{};

  // PocketBase: the binary of this architecture.
  final main = go.main;
  final pocketbaseRef = 'setding:pocketbase/linux-$arch';
  final stdlibRef = 'pkg:golang/stdlib@${go.goVersion}';
  components.add({
    'type': 'application',
    'bom-ref': pocketbaseRef,
    'name': 'pocketbase',
    'version': main.version.replaceFirst(RegExp('^v'), ''),
    'purl': goRef(main.path, main.version),
    'hashes': [
      {'alg': 'SHA-256', 'content': hashOf('pocketbase')},
    ],
    'licenses': licensesOf(main.path),
    'externalReferences': [
      {'type': 'website', 'url': 'https://pocketbase.io'},
    ],
    'properties': [
      {'name': 'setding:file', 'value': 'pocketbase'},
      {'name': 'setding:go-module', 'value': main.path},
      {'name': 'setding:goarch', 'value': arch},
    ],
  });
  final deps = dependencies[pocketbaseRef] = {stdlibRef};

  // Its Go modules, as the binary's build information names them.
  for (final m in [...go.deps]..sort((a, b) => a.path.compareTo(b.path))) {
    final ref = goRef(m.path, m.version);
    components.add({
      'type': 'library',
      'bom-ref': ref,
      'name': m.path,
      'version': m.version,
      'purl': ref,
      'licenses': licensesOf(m.path),
      if (m.sum != null)
        'properties': [
          {'name': 'setding:go-sum', 'value': m.sum},
        ],
    });
    deps.add(ref);
  }

  // The Go runtime and standard library compiled into it.
  components.add({
    'type': 'library',
    'bom-ref': stdlibRef,
    'name': 'go',
    'version': go.goVersion,
    'purl': stdlibRef,
    'licenses': [
      {
        'license': {'id': 'BSD-3-Clause'},
      },
    ],
    'externalReferences': [
      {'type': 'website', 'url': 'https://go.dev'},
    ],
  });

  // The web client's SQLite (checked in, pinned to package:sqlite3).
  final sqlite3 = lock['sqlite3'];
  if (sqlite3 == null) throw SbomException('sqlite3 is not in pubspec.lock');
  const wasm = 'sqlite3.wasm';
  final wasmRef = 'setding:native/sqlite3/$wasm';
  components.add({
    'type': 'library',
    'bom-ref': wasmRef,
    'name': wasm,
    'hashes': [
      {'alg': 'SHA-256', 'content': hashOf(wasm)},
    ],
    'properties': [
      {'name': 'setding:provided-by', 'value': 'sqlite3'},
      {'name': 'setding:file', 'value': 'pb_public/$wasm'},
    ],
  });
  dependencies[pubRef(sqlite3)] = {wasmRef};

  return ServerParts(components, dependencies);
}

/// The SBOM of the server image (ADR-0063): the image (`container`,
/// identified by its [digest] in [repository]) contains the bundles of
/// [bundleBoms] (one per architecture, as they were published) on the
/// distroless [baseImage] (`<name>@sha256:…`).
Map<String, Object?> buildImageBom({
  required List<Map<String, Object?>> bundleBoms,
  required String version,
  required String repository,
  required String digest,
  required String baseImage,
  String? build,
  String? commit,
  DateTime? timestamp,
  String? serialNumber,
}) {
  if (!RegExp(r'^sha256:[0-9a-f]{64}$').hasMatch(digest)) {
    throw SbomException('image digest "$digest" is not sha256:<hex>');
  }
  final base = RegExp(
    r'^([^@]+?)(?::([^@:/]+))?@(sha256:[0-9a-f]{64})$',
  ).firstMatch(baseImage);
  if (base == null) {
    throw SbomException(
      'base image "$baseImage" is not <name>[:tag]@sha256:<hex>',
    );
  }
  if (bundleBoms.isEmpty) throw SbomException('no bundle SBOMs');

  const rootRef = 'setding-server-image';
  final hex = digest.substring('sha256:'.length);
  final repoName = repository.split('/').last;
  final components = <Map<String, Object?>>[];
  final seen = <String>{};
  final edges = <String, Set<String>>{rootRef: {}};

  for (final bom in bundleBoms) {
    final bundle = Map<String, Object?>.from(
      ((bom['metadata'] as Map?)?['component'] as Map?) ??
          (throw SbomException('bundle SBOM without metadata.component')),
    );
    if (bundle['version'] != version) {
      throw SbomException(
        'bundle SBOM of version ${bundle['version']}, expected $version',
      );
    }
    final bundleRef = bundle['bom-ref'] as String;
    if (!seen.add(bundleRef)) {
      throw SbomException('two bundle SBOMs for $bundleRef');
    }
    components.add(bundle);
    edges[rootRef]!.add(bundleRef);
    for (final c in (bom['components'] as List? ?? const [])) {
      final component = Map<String, Object?>.from(c as Map);
      if (seen.add(component['bom-ref'] as String)) components.add(component);
    }
    for (final d in (bom['dependencies'] as List? ?? const [])) {
      final ref = (d as Map)['ref'] as String;
      (edges[ref] ??= {}).addAll([
        for (final t in (d['dependsOn'] as List? ?? const [])) t as String,
      ]);
    }
  }

  final baseName = base.group(1)!;
  final baseDigest = base.group(3)!;
  final baseRef =
      'pkg:oci/${baseName.split('/').last}@${Uri.encodeComponent(baseDigest)}'
      '?repository_url=${Uri.encodeComponent(baseName)}';
  components.add({
    'type': 'container',
    'bom-ref': baseRef,
    'name': baseName,
    if (base.group(2) != null) 'version': base.group(2),
    'purl': baseRef,
    'hashes': [
      {'alg': 'SHA-256', 'content': baseDigest.substring('sha256:'.length)},
    ],
    'externalReferences': [
      {
        'type': 'vcs',
        'url': 'https://github.com/GoogleContainerTools/distroless',
      },
    ],
  });
  edges[rootRef]!.add(baseRef);

  final tag = 'v$version';
  final purl =
      'pkg:oci/$repoName@${Uri.encodeComponent(digest)}'
      '?repository_url=${Uri.encodeComponent(repository)}&tag=$version';
  final refs = {for (final c in components) c['bom-ref'] as String};
  return {
    'bomFormat': 'CycloneDX',
    'specVersion': specVersion,
    'serialNumber': 'urn:uuid:${serialNumber ?? _uuid()}',
    'version': 1,
    'metadata': {
      'timestamp': _iso(timestamp ?? DateTime.now().toUtc()),
      'tools': {
        'components': [
          {
            'type': 'application',
            'name': 'setding-sbom',
            'version': toolVersion,
            'externalReferences': [
              {
                'type': 'vcs',
                'url': 'https://github.com/tafli/setDING/tree/main/tool/sbom',
              },
            ],
          },
        ],
      },
      'component': {
        'type': 'container',
        'bom-ref': rootRef,
        'name': appName,
        'version': version,
        'purl': purl,
        'supplier': const {
          'name': 'setDING',
          'url': [website],
        },
        'licenses': [
          {
            'license': {'id': 'MIT'},
          },
        ],
        'hashes': [
          {'alg': 'SHA-256', 'content': hex},
        ],
        'externalReferences': [
          {'type': 'website', 'url': website},
          {'type': 'vcs', 'url': 'https://github.com/tafli/setDING'},
          {
            'type': 'distribution',
            'url': 'https://github.com/tafli/setDING/releases/tag/$tag',
          },
        ],
        'properties': [
          {'name': 'setding:platform', 'value': 'server-image'},
          {'name': 'setding:artifact', 'value': '$repository:$version'},
          if (build != null) {'name': 'setding:build', 'value': build},
          if (commit != null) {'name': 'setding:commit', 'value': commit},
        ],
      },
      'supplier': const {
        'name': 'setDING',
        'url': [website],
      },
    },
    'components': components,
    'dependencies': [
      for (final ref in [rootRef, ...refs])
        {'ref': ref, 'dependsOn': (edges[ref] ?? <String>{}).toList()..sort()},
    ],
  };
}

String _iso(DateTime t) => '${t.toUtc().toIso8601String().split('.').first}Z';

String _uuid() {
  final r = Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
      '${h.substring(16, 20)}-${h.substring(20)}';
}

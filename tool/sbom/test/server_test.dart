// The SBOM of the server bundles and the server image (ADR-0037, ADR-0063,
// issue #1062).
import 'dart:convert';

import 'package:setding_sbom/setding_sbom.dart';
import 'package:test/test.dart';

import 'sbom_test.dart' show lockYaml, pubDepsJson, componentsOf, dependsOn;

final sourceMapJson = jsonEncode({
  'version': 3,
  'sources': [
    'org-dartlang-sdk:///dart-sdk/lib/core/list.dart',
    '../../../../../../.pub-cache/hosted/pub.dev/http-1.6.0/lib/src/client.dart',
    '../../../../../../.pub-cache/hosted/pub.dev/sqlite3-3.9.1/lib/wasm.dart',
    '../../../../packages/chordpro/lib/chordpro.dart',
    '../../../../../../development/flutter/packages/flutter/lib/widgets.dart',
    '../../../lib/main.dart',
    'web_plugin_registrant.dart',
  ],
});

const buildInfo = '''
/tmp/x/pocketbase: go1.27.4
\tpath\tganigeorgiev.com/pocketbase/pocketbase/examples/base
\tmod\tganigeorgiev.com/pocketbase/pocketbase\tv0.42.3\t
\tdep\tgithub.com/dop251/goja\tv0.0.0-20261023121931-6ace4dde0b29\th1:abc=
\tdep\tgolang.org/x/crypto\tv0.45.0\th1:def=
\tbuild\t-buildmode=exe
\tbuild\tGOARCH=amd64
''';

final goLicenses = {
  'ganigeorgiev.com/pocketbase/pocketbase': ['MIT'],
  'github.com/dop251/goja': ['MIT'],
  'golang.org/x/crypto': ['BSD-3-Clause'],
};

BomInput serverInput({Map<String, String?>? fileHashes}) {
  final lock = parseLock(lockYaml);
  final hashes =
      fileHashes ?? {'pocketbase': 'aaaa', 'sqlite3.wasm': 'bbbb', 'x': 'cccc'};
  final parts = serverParts(
    arch: 'amd64',
    go: parseGoBuildInfo(buildInfo),
    goLicenses: goLicenses,
    fileHashes: hashes,
    lock: lock,
  );
  return BomInput(
    platform: Platform.serverLinuxAmd64,
    version: '1.2.3',
    artifactName: 'setding-server-1.2.3-linux-amd64.tar.gz',
    artifactSha256: '0123',
    flutterVersion: '3.50.0',
    lock: lock,
    compiled: compiledPackagesFromSourceMap(sourceMapJson, lock),
    plugins: const {},
    assetPackages: {'material_ui'},
    nativeAssets: const {},
    nativeFileHashes: hashes,
    pubDependencies: pubDependencies(pubDepsJson),
    licenses: {
      'http': ['BSD-3-Clause'],
      'material_ui': ['BSD-3-Clause'],
      'sqlite3': ['MIT'],
    },
    extraComponents: parts.components,
    extraDependencies: parts.dependencies,
    timestamp: DateTime.utc(2026, 11, 26, 12),
    serialNumber: '00000000-0000-4000-8000-000000000001',
  );
}

const digest =
    'sha256:1111111111111111111111111111111111111111111111111111111111111111';
const base =
    'gcr.io/distroless/static-debian13:nonroot@sha256:'
    '2222222222222222222222222222222222222222222222222222222222222222';

void main() {
  group('inputs', () {
    test('the source map names the compiled packages', () {
      expect(
        compiledPackagesFromSourceMap(sourceMapJson, parseLock(lockYaml)),
        {'http', 'sqlite3', 'chordpro', 'flutter'},
      );
    });

    test('a source map without packages fails', () {
      expect(
        () => compiledPackagesFromSourceMap(
          jsonEncode({
            'sources': ['main.dart'],
          }),
          parseLock(lockYaml),
        ),
        throwsA(isA<SbomException>()),
      );
    });

    test('the Go build information names the modules', () {
      final info = parseGoBuildInfo(buildInfo);
      expect(info.goVersion, '1.27.4');
      expect(info.main.path, 'ganigeorgiev.com/pocketbase/pocketbase');
      expect(info.main.version, 'v0.42.3');
      expect(info.deps.map((m) => m.path), [
        'github.com/dop251/goja',
        'golang.org/x/crypto',
      ]);
      expect(info.deps.first.sum, 'h1:abc=');
    });

    test('replaced Go modules are refused', () {
      expect(
        () => parseGoBuildInfo(
          '$buildInfo\t=>\tgithub.com/other/goja\tv1.0.0\th1:x=\n',
        ),
        throwsA(isA<SbomException>()),
      );
    });

    test('deps.dev licences must be known SPDX ids', () {
      expect(spdxFromDepsDev('m', ['Apache-2.0', 'BSD-3-Clause']), [
        'Apache-2.0',
        'BSD-3-Clause',
      ]);
      expect(spdxFromDepsDev('m', ['MIT OR Apache-2.0']), [
        'MIT',
        'Apache-2.0',
      ]);
      expect(
        () => spdxFromDepsDev('m', ['GPL-3.0-only']),
        throwsA(isA<SbomException>()),
      );
      expect(() => spdxFromDepsDev('m', []), throwsA(isA<SbomException>()));
    });

    test('the web client of a bundle ships asset packages', () {
      final contents = contentsOf([
        (
          'setding-server-1.2.3/pb_public/assets/packages/material_ui/f.ttf',
          [1],
        ),
        ('setding-server-1.2.3/pb_public/main.dart.js', [2]),
      ]);
      expect(contents.assetPackages, {'material_ui'});
    });
  });

  group('bundle SBOM', () {
    final bom = buildBom(serverInput());
    final root = 'setding-server-linux-amd64';
    Map<String, Object?> component(String ref) =>
        componentsOf(bom).singleWhere((c) => c['bom-ref'] == ref);

    test('identifies the bundle', () {
      final meta = (bom['metadata'] as Map)['component'] as Map;
      expect(meta['name'], 'setDING');
      expect(meta['bom-ref'], root);
      expect(
        checkBom(
          bom,
          version: '1.2.3',
          artifactName: 'setding-server-1.2.3-linux-amd64.tar.gz',
          artifactSha256: '0123',
        ),
        isEmpty,
      );
    });

    test('lists the web client\'s compiled packages and assets', () {
      final refs = componentsOf(bom).map((c) => c['bom-ref']).toSet();
      expect(
        refs,
        containsAll(['pkg:pub/http@1.6.0', 'pkg:pub/sqlite3@3.9.1']),
      );
      expect(refs, contains('pkg:pub/material_ui@1.11.1'));
      expect(refs, contains('setding:package/chordpro@0.1.0'));
      // Not compiled into the web client.
      expect(refs, isNot(contains('pkg:pub/test@1.33.0')));
      expect(refs, isNot(contains('pkg:pub/path_provider_linux@2.2.2')));
    });

    test('lists PocketBase with its hash, Go modules and the Go runtime', () {
      final pb = component('setding:pocketbase/linux-amd64');
      expect(pb['version'], '0.42.3');
      expect(
        pb['purl'],
        'pkg:golang/ganigeorgiev.com/pocketbase/pocketbase@v0.42.3',
      );
      expect(pb['hashes'], [
        {'alg': 'SHA-256', 'content': 'aaaa'},
      ]);
      final goja = component(
        'pkg:golang/github.com/dop251/goja@v0.0.0-20261023121931-6ace4dde0b29',
      );
      expect((goja['licenses'] as List).single, {
        'license': {'id': 'MIT'},
      });
      expect(component('pkg:golang/stdlib@1.27.4')['name'], 'go');
      expect(dependsOn(bom, 'setding:pocketbase/linux-amd64'), [
        'pkg:golang/github.com/dop251/goja@v0.0.0-20261023121931-6ace4dde0b29',
        'pkg:golang/golang.org/x/crypto@v0.45.0',
        'pkg:golang/stdlib@1.27.4',
      ]);
      // The root depends on PocketBase, not on its modules.
      expect(dependsOn(bom, root), contains('setding:pocketbase/linux-amd64'));
      expect(
        dependsOn(bom, root),
        isNot(contains('pkg:golang/golang.org/x/crypto@v0.45.0')),
      );
    });

    test('lists sqlite3.wasm under package:sqlite3', () {
      expect(component('setding:native/sqlite3/sqlite3.wasm')['hashes'], [
        {'alg': 'SHA-256', 'content': 'bbbb'},
      ]);
      expect(
        dependsOn(bom, 'pkg:pub/sqlite3@3.9.1'),
        contains('setding:native/sqlite3/sqlite3.wasm'),
      );
    });

    test('fails without the PocketBase binary or a Go licence', () {
      expect(
        () => serverInput(fileHashes: {'sqlite3.wasm': 'bbbb'}),
        throwsA(isA<SbomException>()),
      );
      expect(
        () => serverParts(
          arch: 'amd64',
          go: parseGoBuildInfo(buildInfo),
          goLicenses: {
            'ganigeorgiev.com/pocketbase/pocketbase': ['MIT'],
          },
          fileHashes: {'pocketbase': 'a', 'sqlite3.wasm': 'b'},
          lock: parseLock(lockYaml),
        ),
        throwsA(isA<SbomException>()),
      );
    });
  });

  group('image SBOM', () {
    final amd64 = buildBom(serverInput());
    final arm64 =
        jsonDecode(
              jsonEncode(amd64)
                  .replaceAll('linux-amd64', 'linux-arm64')
                  .replaceAll('"aaaa"', '"dddd"')
                  .replaceAll('"0123"', '"4567"'),
            )
            as Map<String, Object?>;
    Map<String, Object?> image({List<Map<String, Object?>>? boms}) =>
        buildImageBom(
          bundleBoms: boms ?? [amd64, arm64],
          version: '1.2.3',
          repository: 'ghcr.io/tafli/setding-server',
          digest: digest,
          baseImage: base,
        );

    test('identifies the image by its digest', () {
      final bom = image();
      final meta = (bom['metadata'] as Map)['component'] as Map;
      expect(meta['type'], 'container');
      expect(meta['name'], 'setDING');
      expect(meta['purl'], startsWith('pkg:oci/setding-server@sha256%3A1111'));
      expect(
        checkBom(
          bom,
          version: '1.2.3',
          artifactName: 'ghcr.io/tafli/setding-server:1.2.3',
          artifactSha256: digest.substring('sha256:'.length),
          componentType: 'container',
        ),
        isEmpty,
      );
    });

    test('contains both bundles, their components once, and the base', () {
      final bom = image();
      final refs = [for (final c in componentsOf(bom)) c['bom-ref']];
      expect(refs.toSet().length, refs.length);
      expect(
        refs,
        containsAll([
          'setding-server-linux-amd64',
          'setding-server-linux-arm64',
          'setding:pocketbase/linux-amd64',
          'setding:pocketbase/linux-arm64',
          'pkg:pub/http@1.6.0',
        ]),
      );
      final baseRef = refs.singleWhere(
        (r) => (r as String).startsWith('pkg:oci/static-debian13@'),
      );
      expect(dependsOn(bom, 'setding-server-image'), [
        baseRef,
        'setding-server-linux-amd64',
        'setding-server-linux-arm64',
      ]);
      expect(
        dependsOn(bom, 'setding-server-linux-arm64'),
        contains('setding:pocketbase/linux-arm64'),
      );
    });

    test('refuses bundles of another version, a bad digest or base', () {
      final other =
          jsonDecode(jsonEncode(amd64).replaceAll('"1.2.3"', '"1.2.4"'))
              as Map<String, Object?>;
      expect(() => image(boms: [other]), throwsA(isA<SbomException>()));
      expect(
        () => buildImageBom(
          bundleBoms: [amd64],
          version: '1.2.3',
          repository: 'r',
          digest: 'latest',
          baseImage: base,
        ),
        throwsA(isA<SbomException>()),
      );
      expect(
        () => buildImageBom(
          bundleBoms: [amd64],
          version: '1.2.3',
          repository: 'r',
          digest: digest,
          baseImage: 'gcr.io/distroless/static-debian13:nonroot',
        ),
        throwsA(isA<SbomException>()),
      );
    });
  });
}

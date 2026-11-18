import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:setding_sbom/setding_sbom.dart';
import 'package:test/test.dart';

const lockYaml = '''
packages:
  chordpro:
    dependency: "direct main"
    description:
      path: "../packages/chordpro"
      relative: true
    source: path
    version: "0.1.0"
  flutter:
    dependency: "direct main"
    description: flutter
    source: sdk
    version: "0.0.0"
  http:
    dependency: "direct main"
    description:
      name: http
      sha256: aaaa
      url: "https://pub.dev"
    source: hosted
    version: "1.6.0"
  material_ui:
    dependency: "direct main"
    description:
      name: material_ui
      sha256: bbbb
      url: "https://pub.dev"
    source: hosted
    version: "1.11.1"
  sqlite3:
    dependency: "direct dev"
    description:
      name: sqlite3
      sha256: cccc
      url: "https://pub.dev"
    source: hosted
    version: "3.9.1"
  path_provider_linux:
    dependency: transitive
    description:
      name: path_provider_linux
      sha256: dddd
      url: "https://pub.dev"
    source: hosted
    version: "2.2.2"
  path_provider_windows:
    dependency: transitive
    description:
      name: path_provider_windows
      sha256: eeee
      url: "https://pub.dev"
    source: hosted
    version: "2.3.0"
  test:
    dependency: "direct dev"
    description:
      name: test
      sha256: ffff
      url: "https://pub.dev"
    source: hosted
    version: "1.33.0"
sdks:
  dart: ">=3.9.0 <4.0.0"
''';

final sizesJson = jsonEncode([
  {'l': 'dart:core', 'c': 'DateTime', 'n': 'compareTo', 's': 184},
  {'n': '[Stub] Type Test', 's': 40},
  {'l': 'package:setding/main.dart', 'n': 'main', 's': 10},
  {'l': 'package:http/src/client.dart', 'n': 'get', 's': 10},
  {'l': 'package:chordpro/chordpro.dart', 'n': 'parse', 's': 10},
  {'l': 'package:flutter/src/widgets/framework.dart', 'n': 'build', 's': 10},
  {'l': 'package:sqlite3/src/ffi.dart', 'n': 'open', 's': 10},
  {'l': 'file:///tmp/app/.dart_tool/dart_plugin_registrant.dart', 's': 1},
]);

final pluginsJson = jsonEncode({
  'plugins': {
    'linux': [
      {'name': 'path_provider_linux', 'dev_dependency': false},
      {'name': 'integration_test', 'dev_dependency': true},
    ],
    'windows': [
      {'name': 'path_provider_windows', 'dev_dependency': false},
    ],
  },
});

final nativeAssetsJson = jsonEncode({
  'format-version': [1, 0, 0],
  'native-assets': {
    'linux_x64': {
      'package:sqlite3/src/ffi/libsqlite3.g.dart': [
        'absolute',
        'libsqlite3.so',
      ],
    },
    'android_arm64': {
      'package:sqlite3/src/ffi/libsqlite3.g.dart': [
        'absolute',
        'libsqlite3.so',
      ],
    },
  },
});

final pubDepsJson = jsonEncode({
  'root': 'setding',
  'packages': [
    {
      'name': 'setding',
      'dependencies': ['http', 'chordpro', 'flutter', 'test', 'sqlite3'],
    },
    {'name': 'http', 'dependencies': <String>[]},
    {'name': 'chordpro', 'dependencies': <String>[]},
    {
      'name': 'sqlite3',
      'dependencies': ['http'],
    },
    {'name': 'path_provider_linux', 'dependencies': <String>[]},
    {'name': 'material_ui', 'dependencies': <String>[]},
  ],
});

BomInput linuxInput({
  Map<String, String?>? fileHashes,
  Map<String, List<String>>? licenses,
  Map<String, Object?>? gradleBom,
  Platform platform = Platform.linuxX64,
  List<Map<String, Object?>> extraComponents = const [],
}) => BomInput(
  platform: platform,
  version: '1.2.3',
  artifactName: 'setding-1.2.3-${platform.id}.tar.gz',
  artifactSha256: '0123',
  flutterVersion: '3.50.0',
  lock: parseLock(lockYaml),
  compiled: compiledPackages(sizesJson),
  plugins: pluginsFor(pluginsJson, platform),
  assetPackages: {'material_ui'},
  nativeAssets: nativeAssets(nativeAssetsJson, platform),
  nativeFileHashes:
      fileHashes ?? {'libsqlite3.so': '5151', 'libapp.so': '9999'},
  pubDependencies: pubDependencies(pubDepsJson),
  licenses:
      licenses ??
      {
        'http': ['BSD-3-Clause'],
        'material_ui': ['BSD-3-Clause'],
        'sqlite3': ['MIT'],
        'path_provider_linux': ['BSD-3-Clause'],
      },
  build: '42',
  commit: 'abc123',
  gradleBom: gradleBom,
  extraComponents: extraComponents,
  timestamp: DateTime.utc(2026, 11, 18, 12),
  serialNumber: '00000000-0000-4000-8000-000000000000',
);

List<Map<String, Object?>> componentsOf(Map<String, Object?> bom) =>
    (bom['components'] as List).cast<Map<String, Object?>>();

List<String> namesOf(Map<String, Object?> bom) => [
  for (final c in componentsOf(bom)) c['name'] as String,
];

List<String> dependsOn(Map<String, Object?> bom, String ref) => [
  for (final d in (bom['dependencies'] as List).cast<Map<String, Object?>>())
    if (d['ref'] == ref) ...(d['dependsOn'] as List).cast<String>(),
];

void main() {
  group('inputs', () {
    test('parseLock reads version, source and archive hash', () {
      final lock = parseLock(lockYaml);
      expect(lock['http']!.version, '1.6.0');
      expect(lock['http']!.source, 'hosted');
      expect(lock['http']!.sha256, 'aaaa');
      expect(lock['chordpro']!.source, 'path');
      expect(lock['chordpro']!.sha256, isNull);
      expect(lock['flutter']!.source, 'sdk');
    });

    test('pubspecVersion drops build metadata', () {
      expect(pubspecVersion('name: x\nversion: 0.13.0+7\n'), '0.13.0');
      expect(pubspecVersion('name: x\nversion: 0.13.0\n'), '0.13.0');
      expect(() => pubspecVersion('name: x\n'), throwsA(isA<SbomException>()));
    });

    test('compiledPackages names the packages with code', () {
      expect(compiledPackages(sizesJson), {
        'setding',
        'http',
        'chordpro',
        'flutter',
        'sqlite3',
      });
      expect(
        () => compiledPackages(
          jsonEncode([
            {'l': 'dart:core'},
          ]),
        ),
        throwsA(isA<SbomException>()),
      );
    });

    test(
      'pluginsFor leaves out dev dependency plugins and other platforms',
      () {
        expect(pluginsFor(pluginsJson, Platform.linuxX64), {
          'path_provider_linux',
        });
        expect(pluginsFor(pluginsJson, Platform.windowsX64), {
          'path_provider_windows',
        });
        expect(pluginsFor(pluginsJson, Platform.android), isEmpty);
      },
    );

    test('nativeAssets maps file names to asset ids per platform', () {
      expect(nativeAssets(nativeAssetsJson, Platform.linuxX64), {
        'libsqlite3.so': 'package:sqlite3/src/ffi/libsqlite3.g.dart',
      });
      expect(nativeAssets(nativeAssetsJson, Platform.windowsX64), isEmpty);
      expect(assetPackage('package:sqlite3/src/x.dart'), 'sqlite3');
    });

    test('Platform.parse knows the release platforms', () {
      expect(Platform.parse('android'), Platform.android);
      expect(Platform.parse('linux-x64'), Platform.linuxX64);
      expect(() => Platform.parse('ios'), throwsA(isA<SbomException>()));
    });
  });

  group('contents', () {
    test('contentsOf finds asset packages and hashes files by name', () {
      final contents = contentsOf([
        ('bundle/data/flutter_assets/packages/material_ui/shaders/a.frag', [1]),
        ('bundle/data/flutter_assets/AssetManifest.bin', [2]),
        ('bundle/lib/libsqlite3.so', [3]),
        ('lib/arm64-v8a/libdartjni.so', [4]),
        ('lib/x86_64/libdartjni.so', [5]),
        ('lib/a/libsame.so', [6]),
        ('lib/b/libsame.so', [6]),
      ]);
      expect(contents.assetPackages, {'material_ui'});
      expect(contents.fileHashes['libsqlite3.so'], hasLength(64));
      expect(contents.fileHashes['libdartjni.so'], isNull);
      expect(contents.fileHashes['libsame.so'], isNotNull);
    });

    test('readArchive reads zip/apk and tar.gz', () {
      final dir = Directory.systemTemp.createTempSync('sbom_test');
      addTearDown(() => dir.deleteSync(recursive: true));
      final archive = Archive()
        ..add(ArchiveFile.bytes('lib/arm64-v8a/libsqlite3.so', [1, 2, 3]))
        ..add(
          ArchiveFile.bytes(
            'assets/flutter_assets/packages/material_ui/x.frag',
            [4],
          ),
        );
      final apk = File('${dir.path}/app.apk')
        ..writeAsBytesSync(ZipEncoder().encode(archive));
      final tgz = File('${dir.path}/app.tar.gz')
        ..writeAsBytesSync(GZipEncoder().encode(TarEncoder().encode(archive)));
      for (final file in [apk, tgz]) {
        final contents = readArchive(file.path);
        expect(contents.assetPackages, {'material_ui'});
        expect(
          contents.fileHashes['libsqlite3.so'],
          '039058c6f2c0cb492c533b0a4d14ef77cc0f78abccced5287d84a1a2011cfb81',
        );
      }
      expect(
        () => readArchive('${dir.path}/app.exe'),
        throwsA(isA<SbomException>()),
      );
    });
  });

  group('licenses', () {
    test('spdxFromTags maps licence tags and skips the others', () {
      expect(
        spdxFromTags('x', [
          'sdk:flutter',
          'license:bsd-3-clause',
          'license:fsf-libre',
          'license:osi-approved',
        ]),
        ['BSD-3-Clause'],
      );
      expect(spdxFromTags('x', ['license:mpl-2.0']), ['MPL-2.0']);
      expect(spdxFromTags('x', ['is:null-safe']), isEmpty);
    });

    test('spdxFromTags fails on an unknown licence', () {
      expect(
        () => spdxFromTags('x', ['license:gpl-3.0']),
        throwsA(isA<SbomException>()),
      );
    });
  });

  group('shippedPackages', () {
    test('takes code, assets, plugins and native assets, not the SDK', () {
      final shipped = shippedPackages(
        lock: parseLock(lockYaml),
        compiled: compiledPackages(sizesJson),
        plugins: {'path_provider_linux'},
        assetPackages: {'material_ui'},
        nativeAssets: nativeAssets(nativeAssetsJson, Platform.linuxX64),
      );
      expect(shipped, {
        'http',
        'chordpro',
        'sqlite3',
        'path_provider_linux',
        'material_ui',
      });
    });

    test('fails on a shipped package that is not in pubspec.lock', () {
      expect(
        () => shippedPackages(
          lock: parseLock(lockYaml),
          compiled: {'unknown_pkg'},
          plugins: {},
          assetPackages: {},
          nativeAssets: {},
        ),
        throwsA(
          isA<SbomException>().having(
            (e) => e.message,
            'message',
            contains('unknown_pkg'),
          ),
        ),
      );
    });
  });

  group('buildBom', () {
    test('identifies the application and the asset', () {
      final bom = buildBom(linuxInput());
      expect(bom['bomFormat'], 'CycloneDX');
      expect(bom['specVersion'], '1.6');
      expect(
        bom['serialNumber'],
        'urn:uuid:00000000-0000-4000-8000-000000000000',
      );
      final metadata = bom['metadata'] as Map;
      expect(metadata['timestamp'], '2026-11-18T12:00:00Z');
      final c = metadata['component'] as Map;
      expect(c['type'], 'application');
      expect(c['name'], 'setDING');
      expect(c['version'], '1.2.3');
      expect(c['purl'], 'pkg:github/tafli/setDING@v1.2.3');
      expect(c['bom-ref'], 'setding-linux-x64');
      expect(c['hashes'], [
        {'alg': 'SHA-256', 'content': '0123'},
      ]);
      expect(c['licenses'], [
        {
          'license': {'id': 'MIT'},
        },
      ]);
      expect(c['properties'], [
        {'name': 'setding:platform', 'value': 'linux-x64'},
        {'name': 'setding:artifact', 'value': 'setding-1.2.3-linux-x64.tar.gz'},
        {'name': 'setding:build', 'value': '42'},
        {'name': 'setding:commit', 'value': 'abc123'},
      ]);
      expect(
        checkBom(
          bom,
          version: '1.2.3',
          artifactName: 'setding-1.2.3-linux-x64.tar.gz',
          artifactSha256: '0123',
        ),
        isEmpty,
      );
    });

    test('lists only shipped components', () {
      final names = namesOf(buildBom(linuxInput()));
      expect(
        names,
        containsAll([
          'chordpro',
          'http',
          'material_ui',
          'path_provider_linux',
          'sqlite3',
          'libsqlite3.so',
          'flutter',
        ]),
      );
      // dev dependencies, other platforms, the SDK packages, the app itself
      // and files that are not native assets are not listed.
      expect(
        names,
        isNot(
          anyOf([
            contains('test'),
            contains('path_provider_windows'),
            contains('integration_test'),
            contains('setding'),
            contains('libapp.so'),
          ]),
        ),
      );
      expect(names.where((n) => n == 'flutter'), hasLength(1));
    });

    test('describes hosted, path, native and Flutter components', () {
      final components = {
        for (final c in componentsOf(buildBom(linuxInput()))) c['name']: c,
      };
      expect(components['http']!['purl'], 'pkg:pub/http@1.6.0');
      expect(components['http']!['hashes'], [
        {'alg': 'SHA-256', 'content': 'aaaa'},
      ]);
      expect(components['http']!['licenses'], [
        {
          'license': {'id': 'BSD-3-Clause'},
        },
      ]);
      expect(components['chordpro']!['purl'], isNull);
      expect(components['chordpro']!['licenses'], [
        {
          'license': {'id': 'MIT'},
        },
      ]);
      expect(components['libsqlite3.so']!['hashes'], [
        {'alg': 'SHA-256', 'content': '5151'},
      ]);
      expect(components['flutter']!['version'], '3.50.0');
      expect(
        components['flutter']!['purl'],
        'pkg:github/flutter/flutter@3.50.0',
      );
    });

    test('keeps the dependency graph of the shipped components', () {
      final bom = buildBom(linuxInput());
      expect(
        dependsOn(bom, 'setding-linux-x64'),
        unorderedEquals([
          'pkg:github/flutter/flutter@3.50.0',
          'pkg:pub/http@1.6.0',
          'setding:package/chordpro@0.1.0',
          'pkg:pub/sqlite3@3.9.1',
        ]),
      );
      expect(dependsOn(bom, 'pkg:pub/sqlite3@3.9.1'), [
        'pkg:pub/http@1.6.0',
        'setding:native/sqlite3/libsqlite3.so',
      ]);
      final refs = {
        'setding-linux-x64',
        for (final c in componentsOf(bom)) c['bom-ref'],
      };
      for (final d
          in (bom['dependencies'] as List).cast<Map<String, Object?>>()) {
        expect(refs, contains(d['ref']));
        expect(refs, containsAll(d['dependsOn'] as List));
      }
    });

    test('fails when a native asset is missing from the asset', () {
      expect(
        () => buildBom(linuxInput(fileHashes: {})),
        throwsA(isA<SbomException>()),
      );
      expect(
        () => buildBom(linuxInput(fileHashes: {'libsqlite3.so': null})),
        throwsA(isA<SbomException>()),
      );
    });

    test('fails when a hosted package has no licence', () {
      expect(
        () => buildBom(linuxInput(licenses: {})),
        throwsA(isA<SbomException>()),
      );
    });

    test('adds extra components below the application', () {
      final bom = buildBom(
        linuxInput(
          platform: Platform.windowsX64,
          fileHashes: {},
          extraComponents: [
            {
              'type': 'library',
              'bom-ref': 'msvc/vcruntime140.dll',
              'name': 'vcruntime140.dll',
              'version': '14.44.35211.0',
            },
          ],
          licenses: {
            'http': ['BSD-3-Clause'],
            'material_ui': ['BSD-3-Clause'],
            'sqlite3': ['MIT'],
            'path_provider_windows': ['BSD-3-Clause'],
          },
        ),
      );
      expect(namesOf(bom), contains('vcruntime140.dll'));
      expect(namesOf(bom), contains('path_provider_windows'));
      expect(namesOf(bom), isNot(contains('path_provider_linux')));
      expect(
        dependsOn(bom, 'setding-windows-x64'),
        contains('msvc/vcruntime140.dll'),
      );
      expect(
        () => buildBom(
          linuxInput(
            extraComponents: [
              {'name': 'x'},
            ],
          ),
        ),
        throwsA(isA<SbomException>()),
      );
    });

    test('merges the Gradle components of the release classpath', () {
      const app = 'pkg:maven/android/app@unspecified?project_path=%3Aapp';
      const plugin = 'pkg:maven/x/sqlite3@1.0?project_path=%3Asqlite3';
      const otherProject = 'pkg:maven/x/jni@1.0?project_path=%3Ajni';
      const tink =
          'pkg:maven/com.google.crypto.tink/tink-android@1.23.0?type=jar';
      const kotlinPom =
          'pkg:maven/org.jetbrains.kotlin/annotations@1.0?type=pom';
      const kotlinJvm =
          'pkg:maven/org.jetbrains.kotlin/annotations-jvm@1.0?type=jar';
      const engine = 'pkg:maven/io.flutter/x86_64_release@1.0.0-abc?type=jar';
      final gradle = {
        'metadata': {
          'component': {'bom-ref': app, 'purl': app, 'name': 'app'},
        },
        'components': [
          {'bom-ref': plugin, 'purl': plugin, 'name': 'sqlite3'},
          {'bom-ref': otherProject, 'purl': otherProject, 'name': 'jni'},
          {
            'bom-ref': tink,
            'purl': tink,
            'group': 'com.google.crypto.tink',
            'name': 'tink-android',
            'version': '1.23.0',
            'properties': [
              {'name': 'x', 'value': 'y'},
            ],
          },
          {'bom-ref': kotlinPom, 'purl': kotlinPom, 'name': 'annotations'},
          {'bom-ref': kotlinJvm, 'purl': kotlinJvm, 'name': 'annotations-jvm'},
          {
            'bom-ref': engine,
            'purl': engine,
            'group': 'io.flutter',
            'name': 'x86_64_release',
          },
        ],
        'dependencies': [
          {
            'ref': app,
            'dependsOn': [plugin, otherProject, engine],
          },
          {
            'ref': plugin,
            'dependsOn': [tink],
          },
          {
            'ref': otherProject,
            'dependsOn': [kotlinPom],
          },
          {
            'ref': kotlinPom,
            'dependsOn': [kotlinJvm],
          },
        ],
      };
      final bom = buildBom(
        linuxInput(platform: Platform.android, gradleBom: gradle),
      );
      final names = namesOf(bom);
      expect(names, containsAll(['tink-android', 'annotations-jvm']));
      expect(
        names,
        isNot(
          anyOf([
            contains('app'),
            contains('jni'),
            contains('annotations'),
            contains('x86_64_release'),
          ]),
        ),
      );
      expect(names.where((n) => n == 'sqlite3'), hasLength(1));
      final tinkComponent = componentsOf(
        bom,
      ).firstWhere((c) => c['name'] == 'tink-android');
      expect(tinkComponent['properties'], isNull);
      // The plugin project's dependencies belong to its Dart package; spliced
      // nodes pass theirs on to the root.
      expect(dependsOn(bom, 'pkg:pub/sqlite3@3.9.1'), contains(tink));
      expect(
        dependsOn(bom, 'setding-android'),
        containsAll([kotlinJvm, 'pkg:pub/sqlite3@3.9.1']),
      );
    });
  });

  group('checkBom', () {
    final bom = buildBom(linuxInput());
    List<String> check(Map<String, Object?> b, {String version = '1.2.3'}) =>
        checkBom(
          b,
          version: version,
          artifactName: 'setding-1.2.3-linux-x64.tar.gz',
          artifactSha256: '0123',
        );

    Map<String, Object?> withComponent(
      void Function(Map<String, Object?> c) change,
    ) {
      final copy = jsonDecode(jsonEncode(bom)) as Map<String, Object?>;
      change((copy['metadata'] as Map)['component'] as Map<String, Object?>);
      return copy;
    }

    test('accepts a matching SBOM', () => expect(check(bom), isEmpty));

    test('rejects a wrong version', () {
      expect(check(bom, version: '1.2.4'), [contains('version')]);
    });

    test('rejects a wrong name', () {
      expect(check(withComponent((c) => c['name'] = 'app')), [
        contains('name'),
      ]);
    });

    test('rejects a hash of another file', () {
      expect(
        check(
          withComponent(
            (c) => c['hashes'] = [
              {'alg': 'SHA-256', 'content': 'ffff'},
            ],
          ),
        ),
        [contains('SHA-256')],
      );
    });

    test('rejects another artifact name', () {
      expect(
        check(
          withComponent(
            (c) => c['properties'] = [
              {'name': 'setding:artifact', 'value': 'other.zip'},
            ],
          ),
        ),
        [contains('setding:artifact')],
      );
    });

    test('rejects a document without metadata', () {
      expect(check({'bomFormat': 'CycloneDX', 'specVersion': '1.6'}), [
        contains('metadata.component'),
      ]);
    });
  });
}

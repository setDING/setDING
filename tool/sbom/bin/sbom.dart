/// Generates and checks the CycloneDX SBOM of a setDING release asset
/// (ADR-0037, docs/development/releases.md).
///
///   dart run bin/sbom.dart generate --platform linux-x64 --app ../../app \
///     --artifact setding-1.2.3-linux-x64.tar.gz --instruction-sizes sizes.json \
///     [--flutter-version 3.50.0] [--contents <archive>] [--gradle-bom bom.json] \
///     [--extra-components extra.json] [--build N] [--commit SHA] [--output F]
///
///   dart run bin/sbom.dart generate-server --arch amd64 --app ../../app \
///     --artifact setding-server-1.2.3-linux-amd64.tar.gz \
///     --web-source-map main.dart.js.map --go-buildinfo buildinfo.txt \
///     [--flutter-version …] [--pub-deps F] [--version …] [--build N] [--commit SHA]
///
///   dart run bin/sbom.dart generate-image --bundle-sbom A.cdx.json \
///     --bundle-sbom B.cdx.json --repository ghcr.io/tafli/setding-server \
///     --digest sha256:… --base gcr.io/distroless/static-debian13:nonroot@sha256:… \
///     --version 1.2.3 --output image.cdx.json
///
///   dart run bin/sbom.dart check --sbom F.cdx.json --artifact F --version 1.2.3
///   dart run bin/sbom.dart check --sbom image.cdx.json --version 1.2.3 \
///     --digest sha256:… --artifact-name ghcr.io/tafli/setding-server:1.2.3
library;

import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:setding_sbom/setding_sbom.dart';

Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addCommand(
      'generate',
      ArgParser()
        ..addOption('platform', mandatory: true)
        ..addOption('app', mandatory: true, help: 'Flutter app directory')
        ..addOption('artifact', mandatory: true, help: 'the asset described')
        ..addOption(
          'contents',
          help: 'archive whose contents are shipped (default: --artifact)',
        )
        ..addOption('instruction-sizes', mandatory: true)
        ..addOption(
          'flutter-version',
          help: 'default: flutter --version --machine',
        )
        ..addOption(
          'native-assets',
          help:
              'native_assets.json (default: newest of the platform in <app>/.dart_tool/flutter_build)',
        )
        ..addOption(
          'pub-deps',
          help: 'output of flutter pub deps --json (default: runs it)',
        )
        ..addOption('gradle-bom')
        ..addOption(
          'extra-components',
          help: 'JSON array of CycloneDX components',
        )
        ..addOption(
          'version',
          help: 'release version (default: app/pubspec.yaml)',
        )
        ..addOption('build')
        ..addOption('commit')
        ..addOption('output', help: 'default: <artifact>.cdx.json'),
    )
    ..addCommand(
      'generate-server',
      ArgParser()
        ..addOption('arch', mandatory: true, allowed: ['amd64', 'arm64'])
        ..addOption('app', mandatory: true, help: 'Flutter app directory')
        ..addOption('artifact', mandatory: true, help: 'the server bundle')
        ..addOption(
          'web-source-map',
          mandatory: true,
          help: 'main.dart.js.map of the bundled web client',
        )
        ..addOption(
          'go-buildinfo',
          mandatory: true,
          help: 'output of go version -m on the bundled pocketbase',
        )
        ..addOption('flutter-version')
        ..addOption('pub-deps')
        ..addOption('version')
        ..addOption('build')
        ..addOption('commit')
        ..addOption('output', help: 'default: <artifact>.cdx.json'),
    )
    ..addCommand(
      'generate-image',
      ArgParser()
        ..addMultiOption('bundle-sbom')
        ..addOption('repository', mandatory: true)
        ..addOption('digest', mandatory: true)
        ..addOption('base', mandatory: true)
        ..addOption('version', mandatory: true)
        ..addOption('build')
        ..addOption('commit')
        ..addOption('output', mandatory: true),
    )
    ..addCommand(
      'check',
      ArgParser()
        ..addOption('sbom', mandatory: true)
        ..addOption('artifact', help: 'the file described')
        ..addOption('version', mandatory: true)
        ..addOption('digest', help: 'instead of --artifact: an image digest')
        ..addOption('artifact-name', help: 'with --digest: the image name'),
    );

  try {
    final results = parser.parse(args);
    switch (results.command?.name) {
      case 'generate':
        await _generate(results.command!);
      case 'generate-server':
        await _generateServer(results.command!);
      case 'generate-image':
        _generateImage(results.command!);
      case 'check':
        _check(results.command!);
      default:
        stderr.writeln('usage: sbom <generate|check> …\n${parser.usage}');
        exitCode = 64;
    }
  } on SbomException catch (e) {
    stderr.writeln('sbom: $e');
    exitCode = 1;
  } on FormatException catch (e) {
    stderr.writeln('sbom: ${e.message}');
    exitCode = 64;
  }
}

Future<void> _generate(ArgResults a) async {
  final platform = Platform.parse(a.option('platform')!);
  final app = a.option('app')!;
  final artifact = a.option('artifact')!;
  final contents = readArchive(a.option('contents') ?? artifact);
  final lock = parseLock(_read('$app/pubspec.lock'));
  final version =
      a.option('version') ?? pubspecVersion(_read('$app/pubspec.yaml'));
  final nativeAssetsFile =
      a.option('native-assets') ?? _findNativeAssets(app, platform);
  final native = nativeAssetsFile == null
      ? <String, String>{}
      : nativeAssets(_read(nativeAssetsFile), platform);
  final compiled = compiledPackages(_read(a.option('instruction-sizes')!));
  final plugins = pluginsFor(
    _read('$app/.flutter-plugins-dependencies'),
    platform,
  );

  final shipped = shippedPackages(
    lock: lock,
    compiled: compiled,
    plugins: plugins,
    assetPackages: contents.assetPackages,
    nativeAssets: native,
  );
  final licenseSource = PubDevLicenses();
  final licenses = <String, List<String>>{};
  try {
    for (final name in shipped) {
      final p = lock[name]!;
      if (p.source == 'hosted') {
        licenses[name] = await licenseSource.licenses(name, p.version);
      }
    }
  } finally {
    licenseSource.close();
  }

  final bom = buildBom(
    BomInput(
      platform: platform,
      version: version,
      artifactName: _basename(artifact),
      artifactSha256: sha256OfFile(artifact),
      flutterVersion: a.option('flutter-version') ?? await _flutterVersion(),
      lock: lock,
      compiled: compiled,
      plugins: plugins,
      assetPackages: contents.assetPackages,
      nativeAssets: native,
      nativeFileHashes: contents.fileHashes,
      pubDependencies: pubDependencies(
        a.option('pub-deps') != null
            ? _read(a.option('pub-deps')!)
            : await _pubDeps(app),
      ),
      licenses: licenses,
      build: a.option('build'),
      commit: a.option('commit'),
      gradleBom: a.option('gradle-bom') == null
          ? null
          : jsonDecode(_read(a.option('gradle-bom')!)) as Map<String, Object?>,
      extraComponents: a.option('extra-components') == null
          ? const []
          : [
              for (final c
                  in jsonDecode(_read(a.option('extra-components')!)) as List)
                Map<String, Object?>.from(c as Map),
            ],
    ),
  );
  final output = a.option('output') ?? '$artifact.cdx.json';
  File(
    output,
  ).writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(bom)}\n');
  stdout.writeln(
    'sbom: $output (${(bom['components'] as List).length} components)',
  );
}

Future<void> _generateServer(ArgResults a) async {
  final arch = a.option('arch')!;
  final platform = Platform.parse('server-linux-$arch');
  final app = a.option('app')!;
  final artifact = a.option('artifact')!;
  final contents = readArchive(artifact);
  final lock = parseLock(_read('$app/pubspec.lock'));
  final version =
      a.option('version') ?? pubspecVersion(_read('$app/pubspec.yaml'));
  final compiled = compiledPackagesFromSourceMap(
    _read(a.option('web-source-map')!),
    lock,
  );
  final plugins = pluginsFor(
    _read('$app/.flutter-plugins-dependencies'),
    platform,
  );
  final shipped = shippedPackages(
    lock: lock,
    compiled: compiled,
    plugins: plugins,
    assetPackages: contents.assetPackages,
    nativeAssets: const {},
  );
  final go = parseGoBuildInfo(_read(a.option('go-buildinfo')!));

  final licenses = <String, List<String>>{};
  final pub = PubDevLicenses();
  final depsDev = DepsDevLicenses();
  final goLicenses = <String, List<String>>{};
  try {
    for (final name in shipped) {
      final p = lock[name]!;
      if (p.source == 'hosted') {
        licenses[name] = await pub.licenses(name, p.version);
      }
    }
    for (final m in [go.main, ...go.deps]) {
      goLicenses[m.path] = await depsDev.licenses(m.path, m.version);
    }
  } finally {
    pub.close();
    depsDev.close();
  }

  final parts = serverParts(
    arch: arch,
    go: go,
    goLicenses: goLicenses,
    fileHashes: contents.fileHashes,
    lock: lock,
  );
  final bom = buildBom(
    BomInput(
      platform: platform,
      version: version,
      artifactName: _basename(artifact),
      artifactSha256: sha256OfFile(artifact),
      flutterVersion: a.option('flutter-version') ?? await _flutterVersion(),
      lock: lock,
      compiled: compiled,
      plugins: plugins,
      assetPackages: contents.assetPackages,
      nativeAssets: const {},
      nativeFileHashes: contents.fileHashes,
      pubDependencies: pubDependencies(
        a.option('pub-deps') != null
            ? _read(a.option('pub-deps')!)
            : await _pubDeps(app),
      ),
      licenses: licenses,
      build: a.option('build'),
      commit: a.option('commit'),
      extraComponents: parts.components,
      extraDependencies: parts.dependencies,
    ),
  );
  _write(a.option('output') ?? '$artifact.cdx.json', bom);
}

void _generateImage(ArgResults a) {
  final sboms = a.multiOption('bundle-sbom');
  if (sboms.isEmpty) throw SbomException('no --bundle-sbom');
  final bom = buildImageBom(
    bundleBoms: [
      for (final s in sboms) jsonDecode(_read(s)) as Map<String, Object?>,
    ],
    version: a.option('version')!,
    repository: a.option('repository')!,
    digest: a.option('digest')!,
    baseImage: a.option('base')!,
    build: a.option('build'),
    commit: a.option('commit'),
  );
  _write(a.option('output')!, bom);
}

void _write(String output, Map<String, Object?> bom) {
  File(
    output,
  ).writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(bom)}\n');
  stdout.writeln(
    'sbom: $output (${(bom['components'] as List).length} components)',
  );
}

void _check(ArgResults a) {
  final sbom = a.option('sbom')!;
  final digest = a.option('digest');
  final artifact = a.option('artifact');
  if ((digest == null) == (artifact == null)) {
    throw SbomException('check needs either --artifact or --digest');
  }
  final problems = checkBom(
    jsonDecode(_read(sbom)) as Map<String, Object?>,
    version: a.option('version')!,
    artifactName: digest != null
        ? (a.option('artifact-name') ??
              (throw SbomException('--digest needs --artifact-name')))
        : _basename(artifact!),
    artifactSha256: digest != null
        ? digest.replaceFirst('sha256:', '')
        : sha256OfFile(artifact!),
    componentType: digest != null ? 'container' : 'application',
  );
  if (problems.isNotEmpty) {
    throw SbomException('$sbom:\n  ${problems.join('\n  ')}');
  }
  stdout.writeln('sbom: $sbom OK');
}

String _read(String path) {
  final file = File(path);
  if (!file.existsSync()) throw SbomException('$path does not exist');
  return file.readAsStringSync();
}

String _basename(String path) => path.replaceAll(r'\', '/').split('/').last;

/// The newest native_assets.json of [platform] that Flutter wrote for a build.
String? _findNativeAssets(String app, Platform platform) {
  final dir = Directory('$app/.dart_tool/flutter_build');
  if (!dir.existsSync()) return null;
  final candidates = [
    for (final f in dir.listSync(recursive: true))
      if (f is File &&
          f.path.endsWith('native_assets.json') &&
          f.readAsStringSync().contains('"${platform.nativeAssetsKey}"'))
        f,
  ]..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
  return candidates.isEmpty ? null : candidates.first.path;
}

Future<String> _flutterVersion() async {
  final result = await Process.run('flutter', [
    '--version',
    '--machine',
  ], runInShell: true);
  final out = result.stdout as String;
  if (result.exitCode != 0 || !out.contains('{')) {
    throw SbomException('flutter --version failed: ${result.stderr}');
  }
  return (jsonDecode(out.substring(out.indexOf('{')))
          as Map)['frameworkVersion']
      as String;
}

Future<String> _pubDeps(String app) async {
  final result = await Process.run(
    'flutter',
    ['pub', 'deps', '--json'],
    workingDirectory: app,
    runInShell: true,
  );
  if (result.exitCode != 0) {
    throw SbomException('flutter pub deps failed: ${result.stderr}');
  }
  final out = result.stdout as String;
  return out.substring(out.indexOf('{'));
}

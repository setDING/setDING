import 'bom.dart';

/// Checks that [bom] identifies the release asset: CycloneDX, the
/// application's name, the release [version], the asset's file name and its
/// SHA-256 ([artifactSha256]). Returns the problems; empty means valid.
List<String> checkBom(
  Map<String, Object?> bom, {
  required String version,
  required String artifactName,
  required String artifactSha256,
}) {
  final problems = <String>[];
  if (bom['bomFormat'] != 'CycloneDX') {
    problems.add('bomFormat is not CycloneDX');
  }
  if (bom['specVersion'] != specVersion) {
    problems.add('specVersion is ${bom['specVersion']}, expected $specVersion');
  }
  final component = (bom['metadata'] as Map?)?['component'] as Map?;
  if (component == null) return [...problems, 'metadata.component is missing'];

  if (component['type'] != 'application') {
    problems.add('metadata.component.type is ${component['type']}');
  }
  if (component['name'] != appName) {
    problems.add(
      'metadata.component.name is ${component['name']}, expected $appName',
    );
  }
  if (component['version'] != version) {
    problems.add(
      'metadata.component.version is ${component['version']}, expected $version',
    );
  }
  final hashes = [
    for (final h in (component['hashes'] as List? ?? const []))
      if ((h as Map)['alg'] == 'SHA-256') h['content'],
  ];
  if (!hashes.contains(artifactSha256)) {
    problems.add(
      'metadata.component SHA-256 ${hashes.join(', ')} does not match '
      '$artifactName ($artifactSha256)',
    );
  }
  final artifact = [
    for (final p in (component['properties'] as List? ?? const []))
      if ((p as Map)['name'] == 'setding:artifact') p['value'],
  ];
  if (artifact.length != 1 || artifact.single != artifactName) {
    problems.add(
      'setding:artifact is ${artifact.join(', ')}, expected $artifactName',
    );
  }
  final components = bom['components'] as List? ?? const [];
  if (components.isEmpty) problems.add('no components');
  final refs = <String>{};
  for (final c in components) {
    final ref = (c as Map)['bom-ref'];
    if (ref is! String || !refs.add(ref)) {
      problems.add('bad or duplicate bom-ref $ref');
    }
  }
  return problems;
}

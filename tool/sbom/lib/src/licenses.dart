import 'dart:convert';
import 'dart:io';

import 'inputs.dart';

/// pub.dev licence tags (`license:<id>`) → SPDX identifiers. Tags that are not
/// licences (`fsf-libre`, `osi-approved`) are ignored; an unknown licence fails
/// the SBOM, so the table is extended deliberately.
const spdxIds = {
  '0bsd': '0BSD',
  'apache-2.0': 'Apache-2.0',
  'bsd-2-clause': 'BSD-2-Clause',
  'bsd-3-clause': 'BSD-3-Clause',
  'cc0-1.0': 'CC0-1.0',
  'isc': 'ISC',
  'mit': 'MIT',
  'mit-0': 'MIT-0',
  'mpl-2.0': 'MPL-2.0',
  'unlicense': 'Unlicense',
  'zlib': 'Zlib',
};

const _notLicences = {'fsf-libre', 'osi-approved'};

/// SPDX identifiers from pub.dev score tags of [package].
List<String> spdxFromTags(String package, List<String> tags) {
  final ids = <String>[];
  for (final tag in tags) {
    if (!tag.startsWith('license:')) continue;
    final key = tag.substring('license:'.length);
    if (_notLicences.contains(key)) continue;
    final id = spdxIds[key];
    if (id == null) {
      throw SbomException(
        '$package: unknown licence "$key" on pub.dev; '
        'add it to spdxIds in tool/sbom/lib/src/licenses.dart',
      );
    }
    ids.add(id);
  }
  return ids;
}

/// Looks up the licences of a hosted package version.
abstract interface class LicenseSource {
  Future<List<String>> licenses(String package, String version);
}

/// Licences from pub.dev's analysis: the tags of the version, or of the
/// package if the version has none (older versions are not analysed).
class PubDevLicenses implements LicenseSource {
  PubDevLicenses({this.baseUrl = 'https://pub.dev'});

  final String baseUrl;
  final _client = HttpClient();

  @override
  Future<List<String>> licenses(String package, String version) async {
    final base = '$baseUrl/api/packages/${Uri.encodeComponent(package)}';
    for (final url in [
      '$base/versions/${Uri.encodeComponent(version)}/score',
      '$base/score',
    ]) {
      final ids = spdxFromTags(package, await _tags(url));
      if (ids.isNotEmpty) return ids;
    }
    throw SbomException('$package $version: pub.dev reports no licence');
  }

  Future<List<String>> _tags(String url) async {
    final request = await _client.getUrl(Uri.parse(url));
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode == 404) return const [];
    if (response.statusCode != 200) {
      throw SbomException('$url: HTTP ${response.statusCode}');
    }
    return [
      for (final tag
          in ((jsonDecode(body) as Map)['tags'] as List? ?? const []))
        tag as String,
    ];
  }

  void close() => _client.close();
}

/// Licences of Go modules from deps.dev (Open Source Insights), as SPDX ids;
/// an id that is not in [spdxIds] fails the SBOM, like an unknown pub.dev tag.
class DepsDevLicenses {
  DepsDevLicenses({this.baseUrl = 'https://api.deps.dev'});

  final String baseUrl;
  final _client = HttpClient();

  Future<List<String>> licenses(String module, String version) async {
    final url =
        '$baseUrl/v3/systems/go/packages/${Uri.encodeComponent(module)}'
        '/versions/${Uri.encodeComponent(version)}';
    final request = await _client.getUrl(Uri.parse(url));
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode != 200) {
      throw SbomException(
        '$module $version: deps.dev answered HTTP ${response.statusCode}',
      );
    }
    return spdxFromDepsDev('$module $version', [
      for (final l
          in ((jsonDecode(body) as Map)['licenses'] as List? ?? const []))
        l as String,
    ]);
  }

  void close() => _client.close();
}

/// Checks deps.dev's licences of [what] against the known SPDX ids.
List<String> spdxFromDepsDev(String what, List<String> licenses) {
  final known = spdxIds.values.toSet();
  final ids = <String>[];
  for (final expression in licenses) {
    for (final id in expression.split(RegExp(r'\s+(?:AND|OR)\s+'))) {
      final clean = id.replaceAll(RegExp(r'[()]'), '').trim();
      if (!known.contains(clean)) {
        throw SbomException(
          '$what: unknown licence "$clean" on deps.dev; add it to spdxIds in '
          'tool/sbom/lib/src/licenses.dart',
        );
      }
      ids.add(clean);
    }
  }
  if (ids.isEmpty) throw SbomException('$what: deps.dev reports no licence');
  return ids;
}

/// Comparing app versions by Semantic Versioning (ADR-0028), like the
/// server's `lib/compat.js` (ADR-0029).
library;

final _pattern = RegExp(
  r'^v?(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?(?:\+[0-9A-Za-z.-]+)?$',
);

/// Negative, zero or positive like a comparator, by SemVer precedence:
/// `1.0.0-beta.1` < `1.0.0` < `1.0.1`; build metadata (`+…`) is ignored.
/// Versions that cannot be parsed count as `0.0.0`.
int compareVersions(String a, String b) {
  final x = _parse(a);
  final y = _parse(b);
  for (var i = 0; i < 3; i++) {
    final d = (x.$1[i]).compareTo(y.$1[i]);
    if (d != 0) return d.sign;
  }
  final p = x.$2;
  final q = y.$2;
  // A version without prerelease ranks above one with.
  if (p.isEmpty || q.isEmpty) return (q.length - p.length).sign;
  for (var i = 0; i < p.length && i < q.length; i++) {
    final pn = int.tryParse(p[i]);
    final qn = int.tryParse(q[i]);
    final d = switch ((pn, qn)) {
      (final int a, final int b) => a.compareTo(b),
      (int(), null) => -1,
      (null, int()) => 1,
      _ => p[i].compareTo(q[i]),
    };
    if (d != 0) return d.sign;
  }
  return (p.length - q.length).sign;
}

/// Whether [version] is older than [minimum].
bool isOlderThan(String version, String minimum) =>
    compareVersions(version, minimum) < 0;

(List<int>, List<String>) _parse(String version) {
  final m = _pattern.firstMatch(version.trim());
  if (m == null) return (const [0, 0, 0], const []);
  return (
    [for (var i = 1; i <= 3; i++) int.parse(m.group(i)!)],
    m.group(4)?.split('.') ?? const [],
  );
}

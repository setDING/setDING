import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Layering of the client: data, sync and settings never depend on the UI
/// (docs/architecture/README.md, building block view).
void main() {
  test('data, sync and settings do not import the UI', () {
    final files = [
      for (final dir in ['lib/data', 'lib/sync', 'lib/settings'])
        ...Directory(dir).listSync(recursive: true).whereType<File>(),
      File('lib/providers.dart'),
    ].where((f) => f.path.endsWith('.dart'));
    final offending = [
      for (final f in files)
        for (final line in f.readAsLinesSync())
          if (RegExp(r'''^(import|export) '(\.\./)+ui/''').hasMatch(line))
            '${f.path}: $line',
    ];
    expect(offending, isEmpty);
  });

  // ADR-0018: the web build shares all code with the apps, so `dart:io` is
  // only used in native-only files (`*_io.dart`). Those are reached through
  // a conditional import or export, or from other native-only files.
  test('dart:io is used only in native-only files', () {
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('_io.dart'));
    final offending = [
      for (final f in files)
        for (final line in f.readAsLinesSync())
          if (RegExp(r"""^import 'dart:io'""").hasMatch(line) ||
              RegExp(r"""^(import|export) '[^']*_io\.dart';""").hasMatch(line))
            '${f.path}: $line',
    ];
    expect(offending, isEmpty);
  });
}

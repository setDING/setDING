import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The UI design rules that can be checked in the source
/// (docs/development/ui-design.md, issue #743). Each test names the rule
/// and the shared widget or helper to use instead.
void main() {
  final files = Directory('lib/ui')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  /// The lines of [files] matching [pattern], except in [allowed] paths.
  List<String> offending(RegExp pattern, {List<String> allowed = const []}) => [
    for (final f in files)
      if (!allowed.any((a) => f.path.replaceAll(r'\', '/').contains(a)))
        for (final (i, line) in f.readAsLinesSync().indexed)
          if (pattern.hasMatch(line)) '${f.path}:${i + 1}: ${line.trim()}',
  ];

  test('messages use showMessage, showMessageOn or showUndo', () {
    expect(
      offending(RegExp(r'\bSnackBar\('), allowed: ['widgets/dialogs.dart']),
      isEmpty,
    );
  });

  test('colours come from the colour scheme or StatusColors', () {
    // Black, white and transparent are no hues; the song renderer and the
    // stage theme have their own palettes (ADR-0007, ADR-0033).
    expect(
      offending(
        RegExp(r'\bColors\.(?!black|white|transparent)[a-z]'),
        allowed: ['ui/render/', 'live/live_theme.dart'],
      ),
      isEmpty,
    );
  });

  test('section headers use SectionHeader', () {
    // A titleSmall in the primary colour is the section header style.
    final offenders = <String>[];
    for (final f in files) {
      if (f.path.endsWith('section_header.dart')) continue;
      final lines = f.readAsLinesSync();
      for (final (i, line) in lines.indexed) {
        if (!line.contains('textTheme.titleSmall')) continue;
        final block = lines.skip(i).take(4).join(' ');
        if (RegExp(
          r'copyWith\(\s*color: (theme|Theme\.of\(context\))\.colorScheme\.primary',
        ).hasMatch(block)) {
          offenders.add('${f.path}:${i + 1}');
        }
      }
    }
    expect(offenders, isEmpty);
  });

  test('destructive confirmations use destructiveButtonStyle', () {
    expect(
      offending(
        RegExp(r'backgroundColor: .*colorScheme\.error\b'),
        allowed: ['widgets/dialogs.dart'],
      ),
      isEmpty,
    );
  });

  test('page widths use PageWidth', () {
    expect(
      offending(
        RegExp(r'maxWidth: (720|480)\b'),
        allowed: ['widgets/page_width.dart'],
      ),
      isEmpty,
    );
  });
}

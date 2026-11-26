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

  test('screens open through the router, with a path (ADR-0065)', () {
    // `context.push(AppPaths.…)`; only full-screen dialogs that return a
    // value (pickers) keep a page route of their own.
    final offenders = <String>[];
    for (final f in files) {
      final lines = f.readAsLinesSync();
      for (final (i, line) in lines.indexed) {
        if (!RegExp(r'\b(MaterialPageRoute|PageRouteBuilder)\b')
            .hasMatch(line)) {
          continue;
        }
        final block = lines.skip(i).take(4).join(' ');
        if (!block.contains('fullscreenDialog: true')) {
          offenders.add('${f.path}:${i + 1}: ${line.trim()}');
        }
      }
    }
    expect(offenders, isEmpty);
  });

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

  test('icon buttons have a tooltip', () {
    // The tooltip is also the button's accessible name. A deliberate
    // exception says why in a "No tooltip:" comment just above the button.
    final offenders = <String>[];
    for (final f in files) {
      final source = f.readAsStringSync();
      for (final m in RegExp(r'\bIconButton(\.\w+)?\(').allMatches(source)) {
        if (m.group(1) == '.styleFrom') continue;
        final call = source.substring(m.start, _callEnd(source, m.end - 1));
        final before = source.substring(0, m.start).split('\n');
        final above = before.skip(before.length - 8).join('\n');
        if (!RegExp(r'\btooltip:').hasMatch(call) &&
            !above.contains('No tooltip:')) {
          offenders.add('${f.path}:${before.length}');
        }
      }
    }
    expect(offenders, isEmpty);
  });

  test('spacing follows the scale in steps of 4', () {
    // Literal paddings, gaps and spacings are 0, 2 (the inner padding of
    // small badges and key caps) or a multiple of 4. The song renderer and
    // the PDF scale with their font size and paper (ADR-0007).
    bool onScale(String n) {
      final v = double.parse(n);
      return v == 0 || v == 2 || v % 4 == 0;
    }

    final literal = RegExp(r'(?<=[(,:]\s*)(\d+(?:\.\d+)?)(?=\s*[,)])');
    final offenders = <String>[];
    for (final f in files) {
      final path = f.path.replaceAll(r'\', '/');
      if (path.contains('ui/render/') || path.endsWith('set_list_pdf.dart')) {
        continue;
      }
      final source = f.readAsStringSync();
      void check(int start, Iterable<String> values) {
        for (final v in values) {
          if (!onScale(v)) {
            final line = source.substring(0, start).split('\n').length;
            offenders.add('$path:$line: $v');
          }
        }
      }

      for (final m in RegExp(
        r'\bEdgeInsets(Directional)?\.\w+\(',
      ).allMatches(source)) {
        final call = source.substring(m.end - 1, _callEnd(source, m.end - 1));
        check(m.start, literal.allMatches(call).map((l) => l.group(1)!));
      }
      for (final m in RegExp(
        r'\b(?:spacing|runSpacing): (\d+(?:\.\d+)?)\b',
      ).allMatches(source)) {
        check(m.start, [m.group(1)!]);
      }
      // A SizedBox with one dimension and no child is a gap.
      for (final m in RegExp(
        r'\bSizedBox\((?:width|height): (\d+(?:\.\d+)?)\)',
      ).allMatches(source)) {
        check(m.start, [m.group(1)!]);
      }
    }
    expect(offenders, isEmpty);
  });

  test('menu actions use MenuAction with an icon', () {
    // A PopupMenuItem with a plain text label is an action without an icon
    // (#835); a disabled item is a group header and keeps its text.
    final offenders = <String>[];
    for (final f in files) {
      if (f.path.endsWith('menu_action.dart')) continue;
      final source = f.readAsStringSync();
      for (final m in RegExp(
        r'\bPopupMenuItem(<[^>]*>)?\(',
      ).allMatches(source)) {
        final call = source.substring(m.start, _callEnd(source, m.end - 1));
        if (RegExp(r'^\s*child: Text\(', multiLine: true).hasMatch(call) &&
            !call.contains('enabled: false')) {
          final line = '\n'.allMatches(source.substring(0, m.start)).length;
          offenders.add('${f.path}:${line + 1}');
        }
      }
    }
    expect(offenders, isEmpty);
  });

  test('menu actions that delete or remove are destructive', () {
    // A MenuAction with a delete or remove icon draws in the error colour
    // (#839).
    final offenders = <String>[];
    for (final f in files) {
      if (f.path.endsWith('menu_action.dart')) continue;
      final source = f.readAsStringSync();
      for (final m in RegExp(r'\bMenuAction(<[^>]*>)?\(').allMatches(source)) {
        final call = source.substring(m.start, _callEnd(source, m.end - 1));
        if (RegExp(r'icon: Icons\.(delete|person_remove|remove_circle)')
                .hasMatch(call) &&
            !call.contains('destructive: true')) {
          final line = '\n'.allMatches(source.substring(0, m.start)).length;
          offenders.add('${f.path}:${line + 1}');
        }
      }
    }
    expect(offenders, isEmpty);
  });

  test('destructive menu actions come last, after a divider', () {
    // A destructive MenuAction is the last entry of its menu, set apart
    // from the others by a PopupMenuDivider (#1031).
    final offenders = <String>[];
    for (final f in files) {
      if (f.path.endsWith('menu_action.dart')) continue;
      final source = f.readAsStringSync();
      for (final m in RegExp(r'\bMenuAction(<[^>]*>)?\(').allMatches(source)) {
        final end = _callEnd(source, m.end - 1);
        final call = source.substring(m.start, end);
        if (!call.contains('destructive: true')) continue;
        final before = source.substring(0, m.start).trimRight();
        final after = source
            .substring(end)
            .replaceFirst(RegExp(r'^\s*,?\s*'), '');
        if (!before.endsWith('PopupMenuDivider(),') || !after.startsWith(']')) {
          final line = '\n'.allMatches(source.substring(0, m.start)).length;
          offenders.add('${f.path}:${line + 1}');
        }
      }
    }
    expect(offenders, isEmpty);
  });

  test('checkboxes lead their row', () {
    // A checkbox stands in front of its label, in lists and in dialogs; a
    // switch stays at the end (#881). CheckboxListTile puts it at the end
    // by default.
    final offenders = <String>[];
    for (final f in files) {
      final source = f.readAsStringSync();
      for (final m in RegExp(r'\bCheckboxListTile\(').allMatches(source)) {
        final call = source.substring(m.start, _callEnd(source, m.end - 1));
        if (!call.contains(
          'controlAffinity: ListTileControlAffinity.leading',
        )) {
          final line = '\n'.allMatches(source.substring(0, m.start)).length;
          offenders.add('${f.path}:${line + 1}');
        }
      }
      for (final m in RegExp(r'trailing:\s*Checkbox\(').allMatches(source)) {
        final line = '\n'.allMatches(source.substring(0, m.start)).length;
        offenders.add('${f.path}:${line + 1}');
      }
    }
    expect(offenders, isEmpty);
  });
}

/// The index after the parenthesis closing the one at [open] in [source].
int _callEnd(String source, int open) {
  var depth = 0;
  for (var i = open; i < source.length; i++) {
    if (source[i] == '(') depth++;
    if (source[i] == ')' && --depth == 0) return i + 1;
  }
  return source.length;
}

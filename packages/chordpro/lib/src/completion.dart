/// Autocompletion of directives and chords in the ChordPro editor (#38).
library;

import 'chord.dart';
import 'directive_names.dart';
import 'highlight.dart';

/// A directive the parser knows.
class DirectiveInfo {
  const DirectiveInfo(this.name, {required this.argument, this.short = false});

  /// Lower-case name, e.g. `start_of_chorus`.
  final String name;

  /// Whether the directive takes an argument (`{title: …}`).
  final bool argument;

  /// Short form of another directive, e.g. `soc`, `t`.
  final bool short;

  /// Highlighting kind of the name.
  SourceTokenKind get kind => directiveKind(name);

  @override
  String toString() => name;
}

/// All directives the parser knows, long forms first, most common first.
/// Built from the parser's own name tables, so it matches the parser
/// (ADR-0012).
final List<DirectiveInfo> chordProDirectives = () {
  final sections = [...sectionKindNames.keys, ...delegateSectionNames.keys];
  final long = <DirectiveInfo>[
    for (final MapEntry(:key, :value) in metaDirectiveAliases.entries)
      if (key == value) DirectiveInfo(key, argument: true),
    for (final s in sections) ...[
      DirectiveInfo('start_of_$s', argument: false),
      DirectiveInfo('end_of_$s', argument: false),
    ],
    const DirectiveInfo('chorus', argument: false),
    for (final name in commentDirectives.keys)
      if (name.length > 2) DirectiveInfo(name, argument: true),
    const DirectiveInfo('meta', argument: true),
    for (final MapEntry(:key, :value) in otherDirectives.entries)
      if (!_shortOther.contains(key)) DirectiveInfo(key, argument: value),
    for (final name in formatDirectives.keys)
      if (name.length > 2) DirectiveInfo(name, argument: true),
    for (final name in customDirectives) DirectiveInfo(name, argument: true),
  ];
  final short = <DirectiveInfo>[
    for (final MapEntry(:key, :value) in metaDirectiveAliases.entries)
      if (key != value) DirectiveInfo(key, argument: true, short: true),
    for (final name in [...shortSectionStarts.keys, ...shortSectionEnds.keys])
      DirectiveInfo(name, argument: false, short: true),
    for (final name in commentDirectives.keys)
      if (name.length <= 2) DirectiveInfo(name, argument: true, short: true),
    for (final name in _shortOther)
      DirectiveInfo(name, argument: otherDirectives[name]!, short: true),
    for (final name in formatDirectives.keys)
      if (name.length <= 2) DirectiveInfo(name, argument: true, short: true),
  ];
  return List<DirectiveInfo>.unmodifiable([...long, ...short]);
}();

const _shortOther = {'col', 'colb', 'np', 'npp', 'ns'};

/// One suggestion: [label] replaces the range of its [CompletionResult].
class Completion {
  const Completion(this.label, {required this.text, required this.cursor});

  /// What the list shows, e.g. `title` or `Am`.
  final String label;

  /// Replacement text for the range of the result.
  final String text;

  /// Cursor position after inserting, relative to the start of [text].
  final int cursor;

  @override
  String toString() => label;
}

enum CompletionKind { directive, chord }

/// Suggestions for the word at the cursor, which is [start]..[end].
class CompletionResult {
  const CompletionResult({
    required this.kind,
    required this.start,
    required this.end,
    required this.items,
  });

  final CompletionKind kind;
  final int start;
  final int end;
  final List<Completion> items;

  /// [source] with [item] inserted and the cursor after it.
  (String, int) apply(String source, Completion item) =>
      (source.replaceRange(start, end, item.text), start + item.cursor);
}

final _directiveStart = RegExp(r'^\s*\{\s*([A-Za-z_][A-Za-z0-9_]*)?$');
final _chordStart = RegExp(r'\[([^\[\]\s]*)$');

bool _isNameChar(int c) =>
    (c >= 0x30 && c <= 0x39) ||
    (c >= 0x41 && c <= 0x5a) ||
    (c >= 0x61 && c <= 0x7a) ||
    c == 0x5f;

/// Suggestions at [cursor] in [source]: directive names after `{`
/// (including short forms, sections and `x_` directives) and chords after
/// `[` (chords already used in the song and common chords in the song's
/// key, sorted alphabetically). Null if there is nothing to suggest. [tokens] are the
/// highlighting tokens of [source], if already known.
CompletionResult? completeChordPro(
  String source,
  int cursor, {
  List<SourceToken>? tokens,
}) {
  if (cursor < 0 || cursor > source.length) return null;
  final lineStart = cursor == 0 ? 0 : source.lastIndexOf('\n', cursor - 1) + 1;
  var lineEnd = source.indexOf('\n', cursor);
  if (lineEnd < 0) lineEnd = source.length;
  final before = source.substring(lineStart, cursor);
  tokens ??= highlightChordPro(source);
  final kind = _kindAt(tokens, cursor - 1);
  if (kind == SourceTokenKind.delegate ||
      kind == SourceTokenKind.comment ||
      kind == SourceTokenKind.tab) {
    return null;
  }

  final directive = _directiveStart.firstMatch(before);
  if (directive != null) {
    final partial = directive.group(1) ?? '';
    var end = cursor;
    while (end < lineEnd && _isNameChar(source.codeUnitAt(end))) {
      end++;
    }
    final items = _directives(partial.toLowerCase(), source, end, lineEnd);
    return items.isEmpty
        ? null
        : CompletionResult(
            kind: CompletionKind.directive,
            start: cursor - partial.length,
            end: end,
            items: items,
          );
  }

  final chord = _chordStart.firstMatch(before);
  if (chord != null && !before.substring(0, chord.start).endsWith(r'\')) {
    final partial = chord.group(1)!;
    final start = cursor - partial.length;
    var end = cursor;
    while (end < lineEnd && !' \t[]'.contains(source[end])) {
      end++;
    }
    // An existing `]` is replaced too, so the cursor ends up after it.
    if (end < lineEnd && source[end] == ']') end++;
    final items = [
      for (final name in _chords(source, tokens, start, partial))
        Completion(name, text: '$name]', cursor: name.length + 1),
    ];
    return items.isEmpty
        ? null
        : CompletionResult(
            kind: CompletionKind.chord,
            start: start,
            end: end,
            items: items,
          );
  }
  return null;
}

List<Completion> _directives(
  String partial,
  String source,
  int end,
  int lineEnd,
) {
  final rest = source.substring(end, lineEnd);
  // `{tit|: x}` – the argument is already there; only the name changes.
  final hasArgument = RegExp(r'^\s*:').hasMatch(rest);
  final closed = rest.trimLeft().startsWith('}');
  final matches = chordProDirectives.where((d) => d.name.startsWith(partial));
  final sorted = [
    ...matches.where((d) => d.name == partial),
    ...matches.where((d) => d.name != partial),
  ];
  return [
    for (final d in sorted)
      if (hasArgument)
        Completion(d.name, text: d.name, cursor: d.name.length)
      else if (d.argument)
        Completion(
          d.name,
          text: closed ? '${d.name}: ' : '${d.name}: }',
          cursor: d.name.length + 2,
        )
      else
        Completion(
          d.name,
          text: closed ? d.name : '${d.name}}',
          // After the closing brace, which may already be there.
          cursor: closed
              ? d.name.length + rest.indexOf('}') + 1
              : d.name.length + 1,
        ),
  ];
}

/// Chords for a partial name, sorted alphabetically: the song's chords and
/// common chords in the song's key.
List<String> _chords(
  String source,
  List<SourceToken> tokens,
  int start,
  String partial,
) {
  final used = <String>{};
  for (final t in tokens) {
    if (t.kind != SourceTokenKind.chord) continue;
    // Neighbouring chords are merged into one token: `[C][G]`.
    for (final m in RegExp(
      r'\[([^\]]*)\]',
    ).allMatches(source.substring(t.start, t.end))) {
      if (t.start + m.start + 1 == start) continue;
      final name = m.group(1)!.trim();
      if (Chord.tryParse(name) == null) continue;
      used.add(name);
    }
  }
  final keyText = RegExp(
    r'^\s*\{\s*key\s*:\s*([^}]*)\}',
    multiLine: true,
  ).firstMatch(source)?.group(1);
  final key = keyText == null ? null : Key.tryParse(keyText);
  final names = <String>{...used, ...commonChords(key)};
  final lower = partial.toLowerCase();
  return [
    for (final name in names)
      if (name.toLowerCase().startsWith(lower)) name,
  ]..sort(_compareChordNames);
}

/// Alphabetical order of chord names, ignoring case; names that differ only
/// in case keep a fixed order.
int _compareChordNames(String a, String b) {
  final c = a.toLowerCase().compareTo(b.toLowerCase());
  return c != 0 ? c : a.compareTo(b);
}

/// Common chords of [key] (diatonic triads and the dominant seventh), or
/// of C major without a key.
List<String> commonChords(Key? key) {
  final k = key ?? Key(const Note(0));
  final (degrees, qualities) = k.minor
      ? ([0, 3, 5, 7, 8, 10, 7], ['m', '', 'm', 'm', '', '', '7'])
      : ([0, 2, 4, 5, 7, 9, 7], ['', 'm', 'm', '', '', 'm', '7']);
  return [
    for (var i = 0; i < degrees.length; i++)
      Note(
            (k.tonic.pitch + degrees[i]) % 12,
          ).spell(ChordNotation.international, useFlats: k.usesFlats) +
          qualities[i],
  ];
}

SourceTokenKind? _kindAt(List<SourceToken> tokens, int offset) {
  if (offset < 0) return null;
  for (final t in tokens) {
    if (t.end > offset) return t.start <= offset ? t.kind : null;
  }
  return null;
}

/// Directive syntax: names, selectors, arguments and attributes.
library;

/// A parsed directive line such as `{start_of_verse-alto: label="Verse 1"}`.
class Directive {
  const Directive({
    required this.name,
    this.selector,
    this.negated = false,
    this.argument = '',
    this.attributes = const {},
  });

  /// Lower-case directive name.
  final String name;

  /// Selector of a conditional directive (`-guitar`), if any.
  final String? selector;

  /// `-selector!`: selection is reversed.
  final bool negated;

  /// The argument as written (trimmed).
  final String argument;

  /// Attributes like `label="Verse 1"`; empty if the argument is plain text.
  final Map<String, String> attributes;

  /// The label: `label` attribute, otherwise the plain argument.
  /// `\n` sequences become line breaks.
  String? get label {
    final value = attributes['label'] ?? (attributes.isEmpty ? argument : '');
    final text = value.trim();
    return text.isEmpty ? null : text.replaceAll(r'\n', '\n');
  }

  /// The argument without surrounding quotes.
  String get plainArgument => unquote(argument);
}

final _directive = RegExp(
  r'^\{\s*([A-Za-z_][A-Za-z0-9_]*)(?:-([A-Za-z0-9_.]+)(!)?)?(?:\s*:\s*|\s+|(?=\}))(.*?)\s*\}$',
);

/// A line that starts with a complete directive and goes on after its
/// closing `}`, such as `{comment: Chorus} (a cappella)` (#309).
///
/// ChordPro defines directives as lines that start with `{` and end with
/// `}`, so this is not a directive: like the reference implementation,
/// the parser shows the whole line as lyrics.
class TrailingText {
  const TrailingText({
    required this.directive,
    required this.directiveEnd,
    required this.textStart,
    required this.text,
  });

  /// The directive part, from `{` to `}`.
  final String directive;

  /// Offsets in the line: just after the `}`, and where the trailing text
  /// starts.
  final int directiveEnd;
  final int textStart;

  /// The trailing text, trimmed.
  final String text;
}

/// Splits [line] into a directive and the text after it, or returns null
/// if [line] is not such a line.
TrailingText? splitTrailingText(String line) {
  final start = line.indexOf('{');
  if (start < 0 || line.substring(0, start).trim().isNotEmpty) return null;
  if (parseDirective(line) != null) return null;
  final close = line.indexOf('}', start);
  if (close < 0) return null;
  final directive = line.substring(start, close + 1);
  if (parseDirective(directive) == null) return null;
  final rest = line.substring(close + 1);
  final text = rest.trim();
  if (text.isEmpty) return null;
  return TrailingText(
    directive: directive,
    directiveEnd: close + 1,
    textStart: close + 1 + rest.indexOf(text),
    text: text,
  );
}

final _attribute = RegExp(
  r'''([A-Za-z_][\w-]*)\s*=\s*(?:"([^"]*)"|'([^']*)'|(\S+))''',
);

/// Parses a directive line, or returns null if [line] is not a directive.
Directive? parseDirective(String line) {
  final m = _directive.firstMatch(line.trim());
  if (m == null) return null;
  final argument = (m.group(4) ?? '').trim();
  return Directive(
    name: m.group(1)!.toLowerCase(),
    selector: m.group(2)?.toLowerCase(),
    negated: m.group(3) != null,
    argument: argument,
    attributes: parseAttributes(argument),
  );
}

/// Parses `key="value"` pairs. Returns an empty map unless the whole
/// [text] consists of attributes.
Map<String, String> parseAttributes(String text) {
  if (text.isEmpty) return const {};
  final result = <String, String>{};
  var rest = text;
  for (final m in _attribute.allMatches(text)) {
    result[m.group(1)!.toLowerCase()] = m.group(2) ?? m.group(3) ?? m.group(4)!;
    rest = rest.replaceFirst(m.group(0)!, '');
  }
  return rest.trim().isEmpty ? result : const {};
}

/// The `key="value"` pairs in [text] with their positions; group 1 is the
/// key, groups 2–4 the value (double-quoted, single-quoted, bare).
Iterable<RegExpMatch> attributeMatches(String text) =>
    _attribute.allMatches(text);

/// Removes one pair of surrounding quotes.
String unquote(String text) {
  final t = text.trim();
  if (t.length >= 2 &&
      ((t.startsWith('"') && t.endsWith('"')) ||
          (t.startsWith("'") && t.endsWith("'")))) {
    return t.substring(1, t.length - 1);
  }
  return t;
}

/// Context for conditional directives (ADR-0012): instrument and user from
/// the settings. Metadata is checked by the parser.
class SelectorContext {
  const SelectorContext({this.instrument, this.user});

  final String? instrument;
  final String? user;
}

/// Whether a metadata value counts as "true" for selection.
bool isTruthy(String? value) {
  if (value == null) return false;
  final v = value.trim().toLowerCase();
  return v.isNotEmpty && v != '0' && v != 'false' && v != 'null';
}

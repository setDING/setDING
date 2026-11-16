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

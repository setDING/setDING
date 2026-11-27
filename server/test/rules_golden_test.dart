import 'dart:io';

import 'package:setding_server/pocketbase_harness.dart';
import 'package:test/test.dart';

/// The golden file of the effective API rules and fields (issue #1201).
const _golden = 'test/golden/rules.txt';

/// Set to `1` to rewrite the golden file instead of comparing
/// (`make rules-golden`).
final _update = Platform.environment['SETDING_UPDATE_GOLDEN'] == '1';

const _rules = [
  'listRule',
  'viewRule',
  'createRule',
  'updateRule',
  'deleteRule',
];
const _authRules = ['authRule', 'manageRule'];

/// The API rules and fields of every non-system collection after all
/// migrations, as a stable, diff-friendly text: collections sorted by name,
/// one rule per entry, wrapped before every `&&` and `||` and indented by
/// the depth of the parentheses. Fields keep the server's order unless
/// [sortFields] (a down migration that re-adds a field appends it).
String render(
  List<Map<String, dynamic>> collections, {
  bool sortFields = false,
}) {
  final names = {
    for (final c in collections) c['id'] as String: c['name'] as String,
  };
  final out = StringBuffer(
    '# Effective API rules and fields of every non-system collection after\n'
    '# all migrations (issue #1201). Generated; update with\n'
    '# `make rules-golden` and review the diff.\n'
    '# A rule `null` is for superusers only, `""` for everyone.\n',
  );
  final sorted = collections.where((c) => c['system'] != true).toList()
    ..sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
  for (final c in sorted) {
    out.write('\n## ${c['name']} (${c['type']})\n');
    for (final rule in [..._rules, if (c['type'] == 'auth') ..._authRules]) {
      out.write('\n$rule:\n${formatRule(c[rule] as String?)}\n');
    }
    out.write('\nfields:\n');
    final fields = [
      for (final f in (c['fields'] as List).cast<Map<String, dynamic>>())
        _field(f, names),
    ];
    if (sortFields) fields.sort();
    for (final f in fields) {
      out.write('  $f\n');
    }
  }
  return '$out';
}

/// A field as `name type key=value …`, without its id and without options
/// that are false, zero or empty; relations name their target collection.
String _field(Map<String, dynamic> f, Map<String, String> names) {
  final options = <String>[];
  final keys =
      f.keys.where((k) => !const {'id', 'name', 'type'}.contains(k)).toList()
        ..sort();
  for (final key in keys) {
    var value = f[key];
    if (value == null ||
        value == false ||
        value == 0 ||
        value == '' ||
        (value is List && value.isEmpty)) {
      continue;
    }
    if (key == 'collectionId') value = names[value] ?? value;
    options.add('$key=${value is String ? value : '$value'}');
  }
  return [f['name'], f['type'], ...options].join(' ');
}

/// [rule] on lines of two spaces plus two per open parenthesis, a new line
/// before every `&&` and `||` outside string literals.
String formatRule(String? rule) {
  if (rule == null) return '  null';
  if (rule.isEmpty) return '  ""';
  final out = StringBuffer('  ');
  var depth = 0;
  String? quote;
  for (var i = 0; i < rule.length; i++) {
    final ch = rule[i];
    if (quote != null) {
      if (ch == '\\' && i + 1 < rule.length) {
        out.write(ch + rule[++i]);
        continue;
      }
      if (ch == quote) quote = null;
      out.write(ch);
      continue;
    }
    if (ch == '"' || ch == "'") {
      quote = ch;
    } else if (ch == '(') {
      depth++;
    } else if (ch == ')') {
      depth--;
    } else if (ch == ' ' &&
        (rule.startsWith(' && ', i) || rule.startsWith(' || ', i))) {
      out.write('\n${'  ' * (depth + 1)}');
      continue;
    }
    out.write(ch);
  }
  return '$out';
}

void main() {
  test('the effective API rules and fields match the golden file '
      '(#1201; `make rules-golden` updates it)', () async {
    final pb = await PocketBase.start();
    addTearDown(pb.stop);
    final r = await pb.superuser.send('GET', '/api/collections?perPage=500');
    r.expectStatus(200);
    expect(r.json['totalPages'], 1);
    final actual = render(
      (r.json['items'] as List).cast<Map<String, dynamic>>(),
    );
    final file = File(_golden);
    if (_update) {
      file
        ..createSync(recursive: true)
        ..writeAsStringSync(actual);
      return;
    }
    expect(
      file.existsSync() ? file.readAsStringSync() : '',
      actual,
      reason:
          'The effective rules differ from $_golden; if the change is '
          'intended, run `make rules-golden` and review the diff.',
    );
  });

  test('the down migrations restore the rules of the older migrations, '
      'and upgrading again gives the golden file (#1201)', () async {
    // The earliest migration with a down migration that edits a rule.
    const first = '1795800000_invite_token.js';
    Future<String> rules(PocketBase pb, {bool sortFields = true}) async {
      final r = await pb.superuser.send('GET', '/api/collections?perPage=500');
      r.expectStatus(200);
      return render(
        (r.json['items'] as List).cast<Map<String, dynamic>>(),
        sortFields: sortFields,
      );
    }

    final older = await PocketBase.start(migrationsBefore: first);
    final expected = await rules(older);
    await older.stop();

    var pb = await PocketBase.start();
    try {
      pb = await pb.downgrade(first);
      expect(await rules(pb), expected);
      pb = await pb.upgrade();
      if (!_update) {
        expect(
          await rules(pb, sortFields: false),
          File(_golden).readAsStringSync(),
        );
      }
    } finally {
      await pb.stop();
    }
  });

  group('formatRule', () {
    test('wraps before && and || by the depth of the parentheses', () {
      expect(
        formatRule('a = 1 && (b = 2 || c = 3)'),
        '  a = 1\n'
        '  && (b = 2\n'
        '    || c = 3)',
      );
    });

    test('keeps operators inside string literals', () {
      expect(
        formatRule('a = "x && (y" && b = 1'),
        '  a = "x && (y"\n  && b = 1',
      );
    });

    test('shows superuser-only and public rules', () {
      expect(formatRule(null), '  null');
      expect(formatRule(''), '  ""');
    });
  });
}

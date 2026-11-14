/// Grid sections (`{start_of_grid}`): chord grids in the style of jazz grilles.
library;

import 'chord.dart';
import 'song.dart' show ChordToken;

/// Shape of a grid: margin cells, measures × beats, margin cells.
class GridShape {
  const GridShape({
    this.left = 1,
    this.measures = 4,
    this.beats = 4,
    this.right = 1,
  });

  final int left;
  final int measures;
  final int beats;
  final int right;

  int get cells => measures * beats;

  static const fallback = GridShape();

  static final _pattern = RegExp(
    r'^\s*(?:(\d+)\s*\+\s*)?(\d+)(?:\s*x\s*(\d+))?(?:\s*\+\s*(\d+))?\s*$',
  );

  /// Parses `cells`, `measures x beats`, optionally with `left+…+right`.
  static GridShape? tryParse(String? text) {
    if (text == null) return null;
    final m = _pattern.firstMatch(text);
    if (m == null) return null;
    final a = int.parse(m.group(2)!);
    final b = m.group(3) == null ? null : int.parse(m.group(3)!);
    return GridShape(
      left: int.tryParse(m.group(1) ?? '') ?? 0,
      measures: b == null ? 1 : a,
      beats: b ?? a,
      right: int.tryParse(m.group(4) ?? '') ?? 0,
    );
  }
}

/// One line of a grid.
class GridRow {
  const GridRow({
    this.leftMargin,
    required this.tokens,
    this.rightMargin,
    this.strum = false,
    this.hideBars = false,
  });

  /// Text before the first bar line.
  final String? leftMargin;
  final List<GridToken> tokens;

  /// Text after the last bar line.
  final String? rightMargin;

  /// A strum line (`S` or `s` after the first bar line).
  final bool strum;

  /// With `s`: bar symbols and cell lines are not shown.
  final bool hideBars;
}

/// An element of a grid line.
sealed class GridToken {
  const GridToken();
}

/// Bar line symbols, e.g. `|`, `||`, `|.`, `|:`, `:|`, `:|:`, `|1`, `:|2>`.
class GridBar extends GridToken {
  const GridBar(this.symbol);

  final String symbol;

  /// Volta number, if this bar starts a volta.
  int? get volta {
    final m = RegExp(r'(\d+)').firstMatch(symbol);
    return m == null ? null : int.parse(m.group(1)!);
  }
}

/// A cell with one or more chords (`C~G` puts two chords in one cell).
class GridChords extends GridToken {
  const GridChords(this.chords);

  final List<ChordToken> chords;
}

/// `.` (empty cell), `/` (play the chord again), `%` and `%%` (repeat
/// the previous one or two measures).
enum GridSymbol { empty, slash, repeat1, repeat2 }

class GridMark extends GridToken {
  const GridMark(this.symbol);

  final GridSymbol symbol;
}

/// Strum pseudo-chords in strum lines.
class GridStrum extends GridToken {
  const GridStrum(this.code);

  /// Code as written, e.g. `dn`, `u+`, `ux`.
  final String code;

  static const _arrows = {
    'up': '↑',
    'u': '↑',
    'dn': '↓',
    'd': '↓',
    'u+': '↑>',
    'd+': '↓>',
    'ua': '⇡',
    'da': '⇣',
    'ua+': '⇡>',
    'da+': '⇣>',
    'ux': '↑×',
    'dx': '↓×',
    'ux+': '↑×>',
    'dx+': '↓×>',
    'us': '↑·',
    'ds': '↓·',
    'us+': '↑·>',
    'ds+': '↓·>',
    'x': '×',
  };

  static bool isStrum(String code) => _arrows.containsKey(code.toLowerCase());

  /// Symbol for display.
  String get symbol => _arrows[code.toLowerCase()] ?? code;
}

final _bar = RegExp(r'^(?:\|\||\|\.|:\|:|\|:|:\|\d*>?|\|\d+>?|\|)$');

bool _isBar(String token) => _bar.hasMatch(token);

/// Parses one grid input line. Chords get the transposition and key
/// that are in effect.
GridRow parseGridRow(
  String line, {
  int transpose = 0,
  bool? preferFlats,
  Key? key,
}) {
  final words = line.trim().split(RegExp(r'\s+'));
  final firstBar = words.indexWhere(_isBar);
  if (firstBar < 0) {
    return GridRow(leftMargin: line.trim(), tokens: const []);
  }
  final lastBar = words.lastIndexWhere(_isBar);
  final left = words.sublist(0, firstBar).join(' ');
  final right = words.sublist(lastBar + 1).join(' ');

  var strum = false;
  var hideBars = false;
  final tokens = <GridToken>[];
  for (var i = firstBar; i <= lastBar; i++) {
    final w = words[i];
    if (i == firstBar + 1 && (w == 'S' || w == 's')) {
      strum = true;
      hideBars = w == 's';
      continue;
    }
    if (_isBar(w)) {
      tokens.add(GridBar(w));
    } else if (w == '.') {
      tokens.add(const GridMark(GridSymbol.empty));
    } else if (w == '/') {
      tokens.add(const GridMark(GridSymbol.slash));
    } else if (w == '%') {
      tokens.add(const GridMark(GridSymbol.repeat1));
    } else if (w == '%%') {
      tokens.add(const GridMark(GridSymbol.repeat2));
    } else if (strum && GridStrum.isStrum(w)) {
      tokens.add(GridStrum(w));
    } else {
      tokens.add(
        GridChords([
          for (final c in w.split('~'))
            if (c.isNotEmpty)
              ChordToken(
                c,
                transpose: transpose,
                preferFlats: preferFlats,
                key: key,
              ),
        ]),
      );
    }
  }
  return GridRow(
    leftMargin: left.isEmpty ? null : left,
    tokens: tokens,
    rightMargin: right.isEmpty ? null : right,
    strum: strum,
    hideBars: hideBars,
  );
}

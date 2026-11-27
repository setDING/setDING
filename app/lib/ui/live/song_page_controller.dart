import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:material_ui/material_ui.dart';

/// Page of a song that live mode splits into pages (ADR-0007).
class SongPageController extends ChangeNotifier {
  int _page = 0;
  int _count = 1;
  List<int?> _sections = const [];

  /// Shown page, 0-based.
  int get page => _page;

  /// Number of pages; 1 when the song is not split.
  int get count => _count;

  /// The source line of the first section on the shown page, which the
  /// lyrics projection follows (ADR-0068 §6); null when unknown (a PDF, a
  /// song that scrolls).
  int? get section => _page < _sections.length ? _sections[_page] : null;

  /// Sets the number of pages while the page is built, and the source line
  /// of the first section on each ([sections]); listeners (the page
  /// indicator, the projection) are told after the frame.
  void attach(int count, {List<int?> sections = const []}) {
    final changed =
        count != _count || _page >= count || !listEquals(sections, _sections);
    _sections = sections;
    _count = math.max(1, count);
    _page = math.min(_page, _count - 1);
    if (changed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_disposed) notifyListeners();
      });
    }
  }

  /// The page that shows the section starting at [sourceLine]: the last
  /// page whose first section starts at or before it; null when the pages
  /// are unknown.
  int? pageOf(int sourceLine) {
    int? found;
    for (var p = 0; p < _sections.length; p++) {
      final line = _sections[p];
      if (line != null && line <= sourceLine) found = p;
    }
    return found;
  }

  /// Shows [page] when the song has it.
  void show(int page) {
    if (page == _page || page < 0 || page >= _count) return;
    _page = page;
    notifyListeners();
  }

  /// Shows the first page.
  void first() {
    if (_page == 0) return;
    _page = 0;
    notifyListeners();
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  bool next() {
    if (_page + 1 >= _count) return false;
    _page++;
    notifyListeners();
    return true;
  }

  bool previous() {
    if (_page <= 0) return false;
    _page--;
    notifyListeners();
    return true;
  }
}

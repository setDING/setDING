import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:pdfrx/pdfrx.dart';

import '../theme.dart';
import 'live_chordpro_page.dart';
import 'live_item.dart';
import 'live_preparation.dart';
import 'pdf_spread_view.dart';
import 'set_progress_bar.dart';
import 'song_page_controller.dart';

/// Where each item of live mode stands (scroll offset, page of the song,
/// PDF page or spread) and how a turn moves on (ADR-0007): within the item
/// first, then to the next or previous one. Feeds the progress bar.
class LiveStagePages {
  LiveStagePages({
    required this.items,
    required int initialIndex,
    required this._current,
    required this._preparation,
    required this._step,
    required this._turnSlide,
    required this._onSongPage,
  }) : pageView = PageController(initialPage: initialIndex);

  /// The items of live mode as shown.
  final List<LiveItem> items;

  /// The pages of the set.
  final PageController pageView;

  /// The item on stage.
  int get current => _current();
  final int Function() _current;
  final LivePreparation _preparation;

  /// How far a turn scrolls, as a part of the screen.
  final double Function() _step;

  /// Lets the projection take a turn first (#1181); true when it did.
  final bool Function({required bool forward}) _turnSlide;

  /// The page of the song [index] changed.
  final void Function(int index) _onSongPage;

  final _scroll = <int, ScrollController>{};
  final _pdf = <int, PdfViewerController>{};
  final _spread = <int, PdfSpreadController>{};
  final _fit = <int, LiveFitController>{};
  final _songPages = <int, SongPageController>{};
  bool _disposed = false;

  /// Whether a turn goes to the next song, never scrolls (drummer mode,
  /// ADR-0026): on phones, and in the drum panel while it shows the set
  /// (#974).
  bool compact = false;

  /// The scroll controller of item [index], if it was built.
  ScrollController? scroll(int index) => _scroll[index];

  /// The page controller of song [index], if it was built.
  SongPageController? songPage(int index) => _songPages[index];

  // Every position of a song (scroll offset, page, PDF page or spread)
  // moves the progress bar.
  ScrollController scrollFor(int index) => _scroll.putIfAbsent(
    index,
    () => ScrollController()..addListener(scheduleProgress),
  );
  PdfViewerController pdfFor(int index) => _pdf.putIfAbsent(index, () {
    final controller = PdfViewerController()..addListener(scheduleProgress);
    controller.visibleRenderState.addListener(scheduleProgress);
    return controller;
  });
  PdfSpreadController spreadFor(int index) => _spread.putIfAbsent(
    index,
    () => PdfSpreadController()..addListener(scheduleProgress),
  );
  LiveFitController fitFor(int index) =>
      _fit.putIfAbsent(index, LiveFitController.new);
  SongPageController songPageFor(int index) => _songPages.putIfAbsent(
    index,
    () => SongPageController()
      ..addListener(scheduleProgress)
      ..addListener(() => _onSongPage(index)),
  );

  /// Where the set and the current song stand, for the progress bar
  /// (ADR-0007).
  late final progress = ValueNotifier<StageProgress>((
    index: current,
    pages: 1,
    page: 0,
    scroll: null,
  ));
  bool _progressScheduled = false;

  /// Updates [progress] after the frame, once the song is laid out (the
  /// scroll extent and the PDF pages are known only then).
  void scheduleProgress() {
    if (_progressScheduled) return;
    _progressScheduled = true;
    WidgetsBinding.instance
      ..addPostFrameCallback((_) {
        _progressScheduled = false;
        if (!_disposed) progress.value = currentProgress();
      })
      ..ensureVisualUpdate();
  }

  /// The position within the current item, in the order [next] turns.
  StageProgress currentProgress() {
    StageProgress pages(int count, int page) =>
        (index: current, pages: count, page: page, scroll: null);
    if (items[current].song == null) return pages(1, 0);
    final sc = _scroll[current];
    if (sc != null && sc.hasClients && sc.position.hasContentDimensions) {
      final pos = sc.position;
      if (pos.maxScrollExtent > 2) {
        // Seen so far: up to the bottom of the screen, in steps of 1 %.
        final seen =
            (pos.pixels + pos.viewportDimension) /
            (pos.maxScrollExtent + pos.viewportDimension);
        return (
          index: current,
          pages: 1,
          page: 0,
          scroll: (seen.clamp(0.0, 1.0) * 100).round() / 100,
        );
      }
    }
    final songPages = _songPages[current];
    if (songPages != null && songPages.count > 1) {
      return pages(songPages.count, songPages.page);
    }
    final spread = _spread[current];
    if (spread != null && spread.isReady) {
      return pages((spread.pageCount + 1) ~/ 2, (spread.firstPage - 1) ~/ 2);
    }
    final pdf = _pdf[current];
    if (pdf != null && pdf.isReady) {
      return pages(pdf.pageCount, (pdf.pageNumber ?? 1) - 1);
    }
    return pages(1, 0);
  }

  void next() {
    if (_turnSlide(forward: true)) return;
    // Small screens show no song (ADR-0026): every turn is a song.
    if (compact) {
      if (current < items.length - 1) jumpTo(current + 1);
      return;
    }
    final sc = _scroll[current];
    if (sc != null && sc.hasClients) {
      final pos = sc.position;
      if (pos.pixels < pos.maxScrollExtent - 2) {
        sc.animateTo(
          math.min(
            pos.pixels + pos.viewportDimension * _step(),
            pos.maxScrollExtent,
          ),
          duration: shortAnimation,
          curve: Curves.easeOut,
        );
        return;
      }
    }
    if (_songPages[current]?.next() ?? false) return;
    if (_spread[current]?.next() ?? false) return;
    final pdf = _pdf[current];
    if (pdf != null && pdf.isReady) {
      final page = pdf.pageNumber ?? 1;
      if (page < pdf.pageCount) {
        pdf.goToPage(pageNumber: page + 1);
        return;
      }
    }
    if (current < items.length - 1) {
      // The next song starts at its first page. It is built already, unless
      // the turns are faster than the preparation.
      _songPages[current + 1]?.first();
      _preparation.complete(current + 1);
      pageView.nextPage(duration: pageAnimation, curve: Curves.easeOut);
    }
  }

  void previous() {
    if (_turnSlide(forward: false)) return;
    if (compact) {
      if (current > 0) jumpTo(current - 1);
      return;
    }
    final sc = _scroll[current];
    if (sc != null && sc.hasClients && sc.position.pixels > 2) {
      final pos = sc.position;
      sc.animateTo(
        math.max(pos.pixels - pos.viewportDimension * _step(), 0),
        duration: shortAnimation,
        curve: Curves.easeOut,
      );
      return;
    }
    if (_songPages[current]?.previous() ?? false) return;
    if (_spread[current]?.previous() ?? false) return;
    final pdf = _pdf[current];
    if (pdf != null && pdf.isReady && (pdf.pageNumber ?? 1) > 1) {
      pdf.goToPage(pageNumber: pdf.pageNumber! - 1);
      return;
    }
    if (current > 0) {
      _preparation.complete(current - 1);
      pageView.previousPage(duration: pageAnimation, curve: Curves.easeOut);
    }
  }

  /// Turns to item [target] of the set at once (set overview, set list of
  /// the wide song map).
  void jumpTo(int target) {
    if (target == current) return;
    _preparation.complete(target);
    pageView.jumpToPage(target);
  }

  void dispose() {
    _disposed = true;
    pageView.dispose();
    progress.dispose();
    for (final c in _scroll.values) {
      c.dispose();
    }
    for (final c in _spread.values) {
      c.dispose();
    }
    for (final c in _songPages.values) {
      c.dispose();
    }
  }
}

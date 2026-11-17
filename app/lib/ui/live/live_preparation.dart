import 'dart:async';
import 'dart:developer' show Timeline;

import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

import '../render/song_view.dart';

/// How far a page of live mode is built (issue #296, ADR-0007).
///
/// A page starts as an empty placeholder. [LivePreparation] builds the
/// neighbours of the current page in idle time, in steps that each fit into
/// a frame: first the header, then the fit (outside of frames, see
/// [pending]), then the song a few lines per frame ([body]). The page on
/// stage and the target of a turn are always [complete].
class PagePreparation extends ChangeNotifier {
  bool _started = false;
  bool _complete = false;

  /// Something of the page is built; otherwise it is an empty placeholder.
  bool get started => _started;

  /// Everything is built, as if the page had been built at once.
  bool get complete => _complete;

  /// The blocks of the song body that are built.
  final body = BodyProgress();

  /// Work the page needs before it can be built further (fitting the song):
  /// run by [LivePreparation] outside of frames. Set while the page is laid
  /// out; the page shows nothing below the header until it has run.
  VoidCallback? pending;

  /// Whether the page is built (it listens).
  bool get _mounted => hasListeners;

  void _changed() => notifyListeners();

  @override
  void dispose() {
    body.dispose();
    super.dispose();
  }
}

/// Prepares the pages of live mode around the current one (issue #296,
/// ADR-0007): the direct neighbours are built before the next turn, but not
/// in the frames of a turn animation, where a long frame would be a visible
/// stutter.
///
/// The work runs when no animation is running, one step per frame: a step
/// starts a page (its header), runs its fit (outside of frames, it measures
/// every line of the song), or builds the next [linesPerStep] lines of its
/// song. Pages that are no neighbours any more are kept until idle time and
/// then taken down the same way, so the frames of a turn neither build nor
/// dispose a song. [complete] builds a page at once, for the page a turn
/// goes to: if the musician turns faster than the preparation, the turn
/// still shows the whole song.
class LivePreparation {
  LivePreparation({
    required this.length,
    required int current,
    this.linesPerStep = 4,
  }) : _current = current {
    complete(current);
  }

  /// Number of pages.
  final int length;

  /// Lines of a song built (or taken down) per step and frame.
  final int linesPerStep;

  int _current;
  final _pages = <int, PagePreparation>{};
  bool _scheduled = false;
  bool _disposed = false;

  /// Lines of a body that is complete.
  static const _all = 1 << 30;

  /// The preparation of page [index].
  PagePreparation operator [](int index) =>
      _pages.putIfAbsent(index, PagePreparation.new);

  /// The page on stage is now [index]: it is built at once, its neighbours
  /// are prepared in idle time and pages further away taken down.
  void focus(int index) {
    _current = index;
    complete(index);
    _schedule();
  }

  /// Builds page [index] at once (the page on stage or a turn's target).
  void complete(int index) {
    final page = this[index];
    if (page._complete) return;
    // Timeline marker for profiling (docs/development/performance.md): a
    // page built at once, not prepared in idle time.
    Timeline.instantSync(
      'LivePreparation.complete',
      arguments: {'index': '$index', 'started': '${page._started}'},
    );
    page
      .._started = true
      .._complete = true
      ..pending = null;
    page.body.value = _all;
    page._changed();
    _schedule();
  }

  /// Whether [index] should be built: the page on stage and its neighbours.
  bool wanted(int index) => (index - _current).abs() <= 1;

  /// Whether some page still needs a step.
  bool get busy =>
      _pages.entries.any((e) => _stepFor(e.key, e.value, dryRun: true));

  void _schedule() {
    if (_scheduled || _disposed) return;
    _scheduled = true;
    final binding = SchedulerBinding.instance;
    binding.addPostFrameCallback((_) {
      if (_disposed) return;
      // Not while an animation runs (a turn): the next frame comes anyway.
      if (binding.transientCallbackCount > 0) {
        _scheduled = false;
        _schedule();
        return;
      }
      if (!busy) {
        _scheduled = false;
        return;
      }
      // Between frames, so a long fit is not part of a frame. A frame is
      // scheduled for the step's result (and for tests, which pump while a
      // frame is scheduled).
      Timer.run(() {
        _scheduled = false;
        if (_disposed) return;
        Timeline.timeSync('LivePreparation.step', step);
        if (busy) _schedule();
      });
      binding.scheduleFrame();
    });
    binding.ensureVisualUpdate();
  }

  /// Runs one step of the preparation; false when there was nothing to do.
  /// Neighbours first (the next page before the previous one), then pages
  /// to take down.
  @visibleForTesting
  bool step() {
    final order = [
      _current + 1,
      _current - 1,
      for (final i in _pages.keys)
        if (!wanted(i)) i,
    ];
    for (final i in order) {
      final page = _pages[i];
      if (page != null && _stepFor(i, page)) return true;
    }
    return false;
  }

  /// Does one step on page [index]; with [dryRun] only tells whether there
  /// is one.
  bool _stepFor(int index, PagePreparation page, {bool dryRun = false}) {
    // Only pages that are built (mounted) can make progress.
    if (!page._mounted && !(page._started && !wanted(index))) {
      return false;
    }
    if (index < 0 || index >= length) return false;
    final body = page.body;
    if (wanted(index)) {
      if (page._complete) return false;
      if (dryRun) return true;
      if (!page._started) {
        page._started = true;
        body.value = linesPerStep;
        page._changed();
      } else if (page.pending case final work?) {
        page.pending = null;
        work();
        page._changed();
      } else if (body.total == null || body.value >= body.total!) {
        // All lines built (or nothing to build in steps, e.g. a PDF).
        page._complete = true;
        body.value = _all;
        return step();
      } else {
        body.value += linesPerStep;
      }
      return true;
    }
    if (!page._started) return false;
    if (dryRun) return true;
    // Taken down from the end, then released.
    page._complete = false;
    page.pending = null;
    final built = body.total == null
        ? 0
        : (body.value < body.total! ? body.value : body.total!);
    if (built > linesPerStep) {
      body.value = built - linesPerStep;
    } else {
      page._started = false;
      body
        ..value = 0
        ..total = null;
      page._changed();
    }
    return true;
  }

  void dispose() {
    _disposed = true;
    for (final page in _pages.values) {
      page.dispose();
    }
  }
}

/// A page of live mode as far as [preparation] says: an empty placeholder
/// until it is started. A started page is kept while it is taken down, also
/// when it is no longer in the page view's cache, so a turn never disposes
/// a song in its frames.
class PreparedPage extends StatefulWidget {
  const PreparedPage({
    super.key,
    required this.preparation,
    required this.child,
  });

  final PagePreparation preparation;
  final Widget child;

  @override
  State<PreparedPage> createState() => _PreparedPageState();
}

class _PreparedPageState extends State<PreparedPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => widget.preparation.started;

  @override
  void initState() {
    super.initState();
    widget.preparation.addListener(_changed);
  }

  @override
  void didUpdateWidget(PreparedPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.preparation != widget.preparation) {
      oldWidget.preparation.removeListener(_changed);
      widget.preparation.addListener(_changed);
    }
  }

  @override
  void dispose() {
    widget.preparation.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    setState(() {});
    updateKeepAlive();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.preparation.started
        ? widget.child
        : const SizedBox.expand(key: Key('live-page-placeholder'));
  }
}

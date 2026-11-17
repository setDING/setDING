import 'dart:math' as math;

import 'package:chordpro/chordpro.dart' hide Key;
import 'package:drift/drift.dart' show Value;
import 'package:chordpro/chordpro.dart' as cp show Key;
import 'package:flutter/gestures.dart' show Drag;
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../platform/stage_wake_lock.dart';
import '../../sync/sync_controller.dart';
import '../../data/attachment_lookup.dart';
import '../../data/attachment_storage.dart';
import '../../data/database.dart';
import '../../data/song_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../providers.dart';
import '../../settings/settings.dart';
import '../platform/stored_file_view.dart';
import '../render/song_header.dart';
import '../render/chord_diagram.dart';
import '../render/render_cache.dart';
import '../render/song_image.dart';
import '../render/song_view.dart';
import '../sets/set_item_label.dart';
import '../widgets/key_picker.dart';
import 'live_preparation.dart';
import '../../audio/metronome.dart';
import 'live_beat.dart';
import 'live_theme.dart';
import 'set_progress_bar.dart';
import 'pdf_spread_view.dart';

/// One entry of the live sequence.
class LiveItem {
  const LiveItem.song(
    SongEntry this.song, {
    this.arrangement,
    this.setTranspose = 0,
    this.setSequence,
    this.setItemId,
  }) : type = SetItemType.song,
       label = null;

  const LiveItem.marker(this.type, this.label)
    : song = null,
      arrangement = null,
      setTranspose = 0,
      setSequence = null,
      setItemId = null;

  final SetItemType type;
  final SongEntry? song;

  /// The band's arrangement of the song (ADR-0025): key, sequence and tempo
  /// between the song and the set item.
  final BandArrangement? arrangement;

  /// The band's key as semitones relative to the song.
  int get bandTranspose => arrangement?.transpose ?? 0;

  /// Transposition from the set item (layer 2, ADR-0006).
  final int setTranspose;

  /// Song sequence from the set item (layer 2, ADR-0006).
  final String? setSequence;

  /// The set item this entry comes from; null when a single song is played.
  final String? setItemId;
  final String? label;

  LiveItem withSetTranspose(int value) => LiveItem.song(
    song!,
    arrangement: arrangement,
    setTranspose: value,
    setSequence: setSequence,
    setItemId: setItemId,
  );

  /// The song title, or the name of a pause or text item: its own note,
  /// otherwise its type label in the current language (#289).
  String title(AppLocalizations l10n) => song == null
      ? markerTitle(l10n, type, label)
      : (song!.title.isEmpty ? l10n.untitled : song!.title);
}

/// Keys that turn forward / back, exactly like the right / left tap zones
/// (ADR-0007). Bluetooth page turners register as keyboards and send these;
/// some can be switched to send Arrow Down / Arrow Up instead. Like the tap
/// zones, the arrows up/down scroll a song that does not fit before turning.
final _nextKeys = {
  LogicalKeyboardKey.arrowRight,
  LogicalKeyboardKey.arrowDown,
  LogicalKeyboardKey.pageDown,
  LogicalKeyboardKey.space,
};
final _previousKeys = {
  LogicalKeyboardKey.arrowLeft,
  LogicalKeyboardKey.arrowUp,
  LogicalKeyboardKey.pageUp,
};

/// Performance mode (ADR-0007): full screen, screen stays on, page turning
/// by tap, swipe, page turner or keyboard. The items are loaded once when
/// live mode starts, so incoming changes never alter what is on stage.
class LiveScreen extends ConsumerStatefulWidget {
  const LiveScreen({super.key, required this.items, this.initialIndex = 0});

  final List<LiveItem> items;
  final int initialIndex;

  static Future<void> openSet(
    BuildContext context,
    String setId, {
    int index = 0,
  }) async {
    final container = ProviderScope.containerOf(context, listen: false);
    final sets = container.read(setRepositoryProvider);
    final views = await sets.getItems(setId);
    final set = await sets.getSet(setId);
    // The arrangements of the set's band (ADR-0025).
    final arrangements = set == null
        ? const <String, BandArrangement>{}
        : await container
              .read(arrangementRepositoryProvider)
              .forBand(set.bandId);
    final items = [
      for (final v in views)
        if (v.item.type != SetItemType.song)
          LiveItem.marker(v.item.type, v.item.note)
        else if (v.song != null)
          LiveItem.song(
            v.song!,
            arrangement: arrangements[v.song!.id],
            setTranspose: v.item.transpose,
            setSequence: v.item.sequence,
            setItemId: v.item.id,
          ),
    ];
    if (items.isEmpty || !context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => LiveScreen(items: items, initialIndex: index),
      ),
    );
  }

  static Future<void> openSong(BuildContext context, String songId) async {
    final container = ProviderScope.containerOf(context, listen: false);
    final song = await container.read(songRepositoryProvider).getSong(songId);
    if (song == null) return;
    // Outside a set the song is played as written; band arrangements
    // apply in sets only (ADR-0025).
    if (!context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => LiveScreen(items: [LiveItem.song(song)]),
      ),
    );
  }

  @override
  ConsumerState<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends ConsumerState<LiveScreen> {
  late final PageController _pages = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;
  final _scroll = <int, ScrollController>{};
  final _pdf = <int, PdfViewerController>{};
  final _spread = <int, PdfSpreadController>{};
  final _fit = <int, _FitController>{};
  final _songPages = <int, SongPageController>{};
  bool _controls = false;

  /// Builds the neighbours of the page on stage in idle time (issue #296).
  late final LivePreparation _preparation = LivePreparation(
    length: widget.items.length,
    current: widget.initialIndex,
  );

  /// The pages as built, so that rebuilding the live screen (e.g. when the
  /// page changes) does not build the songs again.
  final _pageWidgets = <int, Widget>{};

  /// The route of live mode: keys are handled only while it is on top.
  ModalRoute<Object?>? _route;

  /// Items as shown; the key of a set item can be changed during live mode.
  late final List<LiveItem> _items = [...widget.items];

  /// Sync is paused on stage: nothing changes what is shown (ADR-0007).
  late final SyncController _sync = ref.read(syncControllerProvider.notifier);

  /// Beat, count-in and click of this device (ADR-0026).
  late final LiveBeat _beat = LiveBeat(
    metronome: ref.read(metronomeProvider),
    items: _items,
    settings: () => ref.read(settingsProvider),
  );

  /// The screen stays on while live mode is open (ADR-0007).
  late final StageWakeLock _wakeLock = ref.read(stageWakeLockProvider);

  /// Sets the wake lock again when the app returns to the foreground: not
  /// every platform keeps it while the app is in the background.
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _wakeLock
      ..addListener(_onWakeLockChanged)
      ..acquire();
    _lifecycle = AppLifecycleListener(onResume: _wakeLock.reassert);
    _setFullScreen(true);
    _sync.pause();
    FocusManager.instance.addEarlyKeyEventHandler(_onKey);
    _preparation.focus(_index);
    // With the automatic start the first song counts in.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _beat.onItemShown(_index);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
  }

  @override
  void dispose() {
    FocusManager.instance.removeEarlyKeyEventHandler(_onKey);
    _sync.resume();
    _lifecycle.dispose();
    _wakeLock
      ..removeListener(_onWakeLockChanged)
      ..release();
    _setFullScreen(false);
    _pages.dispose();
    _progress.dispose();
    for (final c in _scroll.values) {
      c.dispose();
    }
    for (final c in _spread.values) {
      c.dispose();
    }
    for (final c in _songPages.values) {
      c.dispose();
    }
    _preparation.dispose();
    _beat.dispose();
    super.dispose();
  }

  /// Shows or hides the wake lock notice in the bottom bar.
  void _onWakeLockChanged() => setState(() {});

  Future<void> _setFullScreen(bool on) async {
    await SystemChrome.setEnabledSystemUIMode(
      on ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
  }

  // Every position of a song (scroll offset, page, PDF page or spread)
  // moves the progress bar.
  ScrollController _scrollFor(int index) => _scroll.putIfAbsent(
    index,
    () => ScrollController()..addListener(_scheduleProgress),
  );
  PdfViewerController _pdfFor(int index) => _pdf.putIfAbsent(index, () {
    final controller = PdfViewerController()..addListener(_scheduleProgress);
    controller.visibleRenderState.addListener(_scheduleProgress);
    return controller;
  });
  PdfSpreadController _spreadFor(int index) => _spread.putIfAbsent(
    index,
    () => PdfSpreadController()..addListener(_scheduleProgress),
  );
  _FitController _fitFor(int index) =>
      _fit.putIfAbsent(index, _FitController.new);
  SongPageController _songPageFor(int index) => _songPages.putIfAbsent(
    index,
    () => SongPageController()..addListener(_scheduleProgress),
  );

  /// Where the set and the current song stand, for the progress bar
  /// (ADR-0007).
  late final _progress = ValueNotifier<StageProgress>((
    index: _index,
    pages: 1,
    page: 0,
    scroll: null,
  ));
  bool _progressScheduled = false;

  /// Updates [_progress] after the frame, once the song is laid out (the
  /// scroll extent and the PDF pages are known only then).
  void _scheduleProgress() {
    if (_progressScheduled) return;
    _progressScheduled = true;
    WidgetsBinding.instance
      ..addPostFrameCallback((_) {
        _progressScheduled = false;
        if (mounted) _progress.value = _currentProgress();
      })
      ..ensureVisualUpdate();
  }

  /// The position within the current item, in the order [_next] turns.
  StageProgress _currentProgress() {
    StageProgress pages(int count, int page) =>
        (index: _index, pages: count, page: page, scroll: null);
    if (_items[_index].song == null) return pages(1, 0);
    final sc = _scroll[_index];
    if (sc != null && sc.hasClients && sc.position.hasContentDimensions) {
      final pos = sc.position;
      if (pos.maxScrollExtent > 2) {
        // Seen so far: up to the bottom of the screen, in steps of 1 %.
        final seen =
            (pos.pixels + pos.viewportDimension) /
            (pos.maxScrollExtent + pos.viewportDimension);
        return (
          index: _index,
          pages: 1,
          page: 0,
          scroll: (seen.clamp(0.0, 1.0) * 100).round() / 100,
        );
      }
    }
    final songPages = _songPages[_index];
    if (songPages != null && songPages.count > 1) {
      return pages(songPages.count, songPages.page);
    }
    final spread = _spread[_index];
    if (spread != null && spread.isReady) {
      return pages((spread.pageCount + 1) ~/ 2, (spread.firstPage - 1) ~/ 2);
    }
    final pdf = _pdf[_index];
    if (pdf != null && pdf.isReady) {
      return pages(pdf.pageCount, (pdf.pageNumber ?? 1) - 1);
    }
    return pages(1, 0);
  }

  double get _step =>
      ref.read(settingsProvider).pageTurn == PageTurnMode.half ? 0.5 : 0.85;

  void _next() {
    final sc = _scroll[_index];
    if (sc != null && sc.hasClients) {
      final pos = sc.position;
      if (pos.pixels < pos.maxScrollExtent - 2) {
        sc.animateTo(
          math.min(
            pos.pixels + pos.viewportDimension * _step,
            pos.maxScrollExtent,
          ),
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
        return;
      }
    }
    if (_songPages[_index]?.next() ?? false) return;
    if (_spread[_index]?.next() ?? false) return;
    final pdf = _pdf[_index];
    if (pdf != null && pdf.isReady) {
      final page = pdf.pageNumber ?? 1;
      if (page < pdf.pageCount) {
        pdf.goToPage(pageNumber: page + 1);
        return;
      }
    }
    if (_index < _items.length - 1) {
      // The next song starts at its first page. It is built already, unless
      // the turns are faster than the preparation.
      _songPages[_index + 1]?.first();
      _preparation.complete(_index + 1);
      _pages.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _previous() {
    final sc = _scroll[_index];
    if (sc != null && sc.hasClients && sc.position.pixels > 2) {
      final pos = sc.position;
      sc.animateTo(
        math.max(pos.pixels - pos.viewportDimension * _step, 0),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
      return;
    }
    if (_songPages[_index]?.previous() ?? false) return;
    if (_spread[_index]?.previous() ?? false) return;
    final pdf = _pdf[_index];
    if (pdf != null && pdf.isReady && (pdf.pageNumber ?? 1) > 1) {
      pdf.goToPage(pageNumber: pdf.pageNumber! - 1);
      return;
    }
    if (_index > 0) {
      _preparation.complete(_index - 1);
      _pages.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  /// Page turner and keyboard (ADR-0007). An early handler of the focus
  /// manager: it sees every key before the focused widget, so the keys work
  /// whichever widget of live mode has the focus (a button of the control
  /// bar, the PDF viewer) or none, and Space never presses a focused button.
  KeyEventResult _onKey(KeyEvent event) {
    // Dialogs, sheets and menus opened from live mode are routes on top of
    // it: their keys, text fields included, stay theirs.
    if (!mounted || !(_route?.isCurrent ?? true)) {
      return KeyEventResult.ignored;
    }
    final focus = FocusManager.instance.primaryFocus?.context;
    if (focus?.findAncestorStateOfType<EditableTextState>() != null) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final next = _nextKeys.contains(key);
    if (next || _previousKeys.contains(key)) {
      // One press turns once. A held key (key repeat) does not turn again,
      // so it never races through the pages and songs of the set.
      if (event is KeyDownEvent) next ? _next() : _previous();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      if (event is KeyDownEvent) Navigator.maybePop(context);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// Width of the page area, for the tap zones.
  double _width = 0;

  void _onTap(Offset position) {
    final x = position.dx;
    final width = _width;
    if (x < width * 0.3) {
      _previous();
    } else if (x > width * 0.7) {
      _next();
    } else {
      setState(() => _controls = !_controls);
    }
  }

  /// Horizontal distance of the current swipe.
  double _swipe = 0;

  /// A swipe to the left turns forward, to the right back: when it is fast
  /// enough or long enough (a fifth of the page width).
  void _onSwipeEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final distance = _swipe;
    _swipe = 0;
    if (velocity.abs() > 300 ? velocity < 0 : distance < -_width * 0.2) {
      _next();
    } else if (velocity.abs() > 300 ? velocity > 0 : distance > _width * 0.2) {
      _previous();
    }
  }

  /// [context] is below the stage theme, which the sheet follows.
  Future<void> _showOverview(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final target = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (context, controller) => ListView(
          controller: controller,
          children: [
            ListTile(
              title: Text(
                l10n.liveSetOverview,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            for (var i = 0; i < _items.length; i++)
              ListTile(
                selected: i == _index,
                leading: Text('${i + 1}'),
                title: Text(_items[i].title(l10n)),
                subtitle: _items[i].song?.songKey == null
                    ? null
                    : Text(_items[i].song!.songKey!),
                onTap: () => Navigator.pop(context, i),
              ),
          ],
        ),
      ),
    );
    if (target != null) {
      _preparation.complete(target);
      _pages.jumpToPage(target);
    }
  }

  /// Changes the key of the current set item. It is stored on the set item,
  /// so the song itself stays unchanged.
  Future<void> _setKey(int transpose) async {
    final item = _items[_index];
    final id = item.setItemId;
    if (id == null) return;
    setState(() {
      _items[_index] = item.withSetTranspose(transpose);
      _pageWidgets.remove(_index);
    });
    await ref.read(setRepositoryProvider).setItemTranspose(id, transpose);
  }

  Future<void> _adjust(SongOverlay Function(SongOverlay) change) async {
    final song = _items[_index].song;
    if (song == null) return;
    final repo = ref.read(songRepositoryProvider);
    await repo.saveOverlay(change(await repo.getOverlay(song.id)));
  }

  /// Fits the current song to the page: with fitting on, 100 % is the fitted
  /// size (ADR-0007); without, the font scale that fits the page is measured.
  Future<void> _fitToPage() async {
    final scale = ref.read(settingsProvider).autoFit
        ? 1.0
        : _fitFor(_index).fontScale?.call();
    if (scale == null) return;
    await _adjust((o) => o.copyWith(fontScale: scale));
  }

  @override
  Widget build(BuildContext context) {
    final (appearance, accent) = ref.watch(
      settingsProvider.select((s) => (s.liveAppearance, s.accent)),
    );
    // The stage appearance is independent of the app theme (ADR-0007); the
    // control bar, the bottom bar and the sheets follow it too.
    return Theme(
      data: liveTheme(Theme.of(context), appearance, accent),
      child: LiveBeatScope(
        beat: _beat,
        child: Builder(builder: _buildStage),
      ),
    );
  }

  Widget _buildStage(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final items = _items;
    final next = _index < items.length - 1 ? items[_index + 1] : null;
    final theme = Theme.of(context);
    final showProgress = ref.watch(
      settingsProvider.select((s) => s.setProgress),
    );
    if (showProgress) _scheduleProgress();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // The control bar overlays the page, so showing it does not
            // change the page size (and does not fit the song again).
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        _width = constraints.maxWidth;
                        return GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTapUp: (d) => _onTap(d.localPosition),
                          // Swipes turn pages like taps: the pages of a
                          // song first, then the next/previous song.
                          onHorizontalDragStart: (_) => _swipe = 0,
                          onHorizontalDragUpdate: (d) =>
                              _swipe += d.primaryDelta ?? 0,
                          onHorizontalDragEnd: _onSwipeEnd,
                          // A song laid out anew (e.g. larger text) may
                          // scroll further or no longer scroll at all.
                          child: NotificationListener<ScrollMetricsNotification>(
                            onNotification: (_) {
                              if (showProgress) _scheduleProgress();
                              return false;
                            },
                            child: PageView.builder(
                              controller: _pages,
                              physics: const NeverScrollableScrollPhysics(),
                              // The direct neighbours are built ahead (one
                              // page of cache on each side): the next song is
                              // fitted and its PDF opened (landscape: its
                              // pages rendered) before the turn, in idle
                              // time after the previous turn (issue #296).
                              // Items further away are not kept, so memory
                              // stays bounded in long sets.
                              allowImplicitScrolling: true,
                              itemCount: items.length,
                              onPageChanged: (i) => setState(() {
                                // A song turned to from the front starts at
                                // its first page.
                                if (i > _index) _songPageFor(i).first();
                                _index = i;
                                _preparation.focus(i);
                                // Another item stops the beat (ADR-0026).
                                _beat.onItemShown(i);
                              }),
                              itemBuilder: (context, i) =>
                                  _pageWidgets.putIfAbsent(
                                    i,
                                    () => PreparedPage(
                                      preparation: _preparation[i],
                                      child: _LiveItemPage(
                                        item: items[i],
                                        index: i,
                                        scrollController: _scrollFor(i),
                                        pdfController: _pdfFor(i),
                                        spreadController: _spreadFor(i),
                                        fitController: _fitFor(i),
                                        songPageController: _songPageFor(i),
                                        preparation: _preparation[i],
                                        onTap: _onTap,
                                      ),
                                    ),
                                  ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // Beat of the drummer mode (ADR-0026); take no taps.
                  const Positioned.fill(child: EdgeFlash()),
                  const Positioned.fill(child: CountInOverlay()),
                  if (_controls)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: _ControlBar(
                        item: items[_index],
                        index: _index,
                        onExit: () => Navigator.pop(context),
                        onOverview: () => _showOverview(context),
                        onAdjust: items[_index].song == null ? null : _adjust,
                        onFit: _fitToPage,
                        onSetKey: _setKey,
                      ),
                    ),
                ],
              ),
            ),
            // Where the set stands and whether more of the song follows,
            // seen at a glance; below the page, so it never covers text.
            if (showProgress)
              ValueListenableBuilder(
                valueListenable: _progress,
                builder: (context, progress, _) => SetProgressBar(
                  markers: [for (final item in items) item.song == null],
                  progress: progress,
                ),
              ),
            Container(
              color: theme.colorScheme.surfaceContainer,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      next == null
                          ? l10n.liveEnd
                          : l10n.liveNext(_nextLabel(next, l10n)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  // Web: no offline guarantee (ADR-0018).
                  if (ref.watch(webClientProvider)) ...[
                    const SizedBox(width: 12),
                    Icon(
                      Icons.cloud_off,
                      size: 18,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        l10n.liveWebNotice,
                        key: const Key('live-web-notice'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  // The click was asked for but there is no audio.
                  ValueListenableBuilder<bool>(
                    valueListenable: _beat.metronome.clickUnavailable,
                    builder: (context, unavailable, _) => !unavailable
                        ? const SizedBox.shrink()
                        : Flexible(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: Text(
                                l10n.clickNoAudioLive,
                                key: const Key('live-click-notice'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.error,
                                ),
                              ),
                            ),
                          ),
                  ),
                  // The screen may turn off: say so, so the band can
                  // check the device's power settings before the show.
                  if (_wakeLock.failed) ...[
                    Icon(
                      Icons.screen_lock_portrait,
                      size: 18,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        l10n.liveWakeLockNotice,
                        key: const Key('live-wakelock-notice'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  ListenableBuilder(
                    listenable: _songPageFor(_index),
                    builder: (context, _) {
                      final pages = _songPageFor(_index);
                      if (pages.count <= 1) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: Text(
                          l10n.liveSongPage(pages.page + 1, pages.count),
                          key: const Key('live-song-page'),
                          style: theme.textTheme.titleSmall,
                        ),
                      );
                    },
                  ),
                  Text(
                    l10n.livePosition(_index + 1, items.length),
                    style: theme.textTheme.titleSmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _nextLabel(LiveItem item, AppLocalizations l10n) {
    final key = item.song?.songKey;
    final title = item.title(l10n);
    if (key == null) return title;
    final parsed = cp.Key.tryParse(key);
    final shown = parsed == null
        ? key
        : parsed
              .transpose(item.bandTranspose + item.setTranspose)
              .format(ref.read(settingsProvider).notation);
    return '$title ($shown)';
  }
}

/// Minimum width for the Nashville toggle in the same row as the controls.
const _wideControlBar = 720.0;

class _ControlBar extends ConsumerWidget {
  const _ControlBar({
    required this.item,
    required this.index,
    required this.onExit,
    required this.onOverview,
    required this.onAdjust,
    required this.onFit,
    required this.onSetKey,
  });

  final LiveItem item;
  final int index;
  final VoidCallback onExit;
  final VoidCallback onOverview;
  final Future<void> Function(SongOverlay Function(SongOverlay))? onAdjust;
  final VoidCallback onFit;
  final ValueChanged<int> onSetKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final adjust = onAdjust;
    final song = item.song;
    final overlay = song == null
        ? null
        : ref.watch(overlayProvider(song.id)).value;
    // In a set, the key is stored on the set item (the song stays
    // unchanged); a single song uses the personal transposition.
    final inSet = item.setItemId != null;
    // The band's key is the reference (ADR-0025).
    final originalKey = song?.songKey == null
        ? null
        : cp.Key.tryParse(song!.songKey!)?.transpose(item.bandTranspose);
    final deviceNashville = ref.watch(
      settingsProvider.select((s) => s.nashville),
    );
    final toggle = adjust == null || song == null
        ? null
        : _NashvilleToggle(
            selected: overlay?.nashville ?? deviceNashville,
            hasKey:
                parseChordProCached(
                  song.chordproSource,
                  selectors: ref.watch(selectorsProvider),
                ).key !=
                null,
            onChanged: (selected) => adjust(
              (o) => o.copyWith(
                nashville: Value(selected == deviceNashville ? null : selected),
              ),
            ),
          );
    final leading = <Widget>[
      IconButton(
        tooltip: l10n.liveExit,
        icon: const Icon(Icons.close),
        onPressed: onExit,
      ),
      IconButton(
        tooltip: l10n.liveSetOverview,
        icon: const Icon(Icons.format_list_numbered),
        onPressed: onOverview,
      ),
    ];
    final trailing = <Widget>[
      if (adjust != null) ...[
        KeyPicker(
          baseKey: originalKey,
          transpose: inSet ? item.setTranspose : overlay?.transpose ?? 0,
          notation: ref.watch(settingsProvider.select((s) => s.notation)),
          tooltip: inSet ? l10n.keyPickerSet : l10n.keyPickerPersonal,
          onChanged: (value) => inSet
              ? onSetKey(value)
              : adjust((o) => o.copyWith(transpose: value)),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: l10n.fontSmaller,
          icon: const Icon(Icons.text_decrease),
          onPressed: () => adjust(
            (o) => o.copyWith(
              fontScale: (o.fontScale - 0.1).clamp(
                _minFontScale,
                _maxFontScale,
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: l10n.fontLarger,
          icon: const Icon(Icons.text_increase),
          onPressed: () => adjust(
            (o) => o.copyWith(
              fontScale: (o.fontScale + 0.1).clamp(
                _minFontScale,
                _maxFontScale,
              ),
            ),
          ),
        ),
        // With fitting on, 100 % is the fitted size (ADR-0007).
        IconButton(
          tooltip: l10n.fitToPage,
          icon: const Icon(Icons.fit_screen),
          onPressed:
              ref.watch(settingsProvider.select((s) => s.autoFit)) &&
                  (overlay == null || overlay.fontScale == 1.0)
              ? null
              : onFit,
        ),
      ],
    ];
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        // The toggle sits in the middle, easy to reach on stage; on narrow
        // screens it gets a row of its own above the other controls.
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= _wideControlBar;
            final row = Row(
              children: [
                ...leading,
                const Spacer(),
                if (toggle != null && wide) ...[toggle, const Spacer()],
                ...trailing,
              ],
            );
            // Tempo on stage (ADR-0026) in a row of its own.
            final beat = LiveBeatScope.of(context);
            final tempo = beat != null && beat.canBeat(index)
                ? StageTempoControls(index: index)
                : null;
            if ((toggle == null || wide) && tempo == null) return row;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [?tempo, if (toggle != null && !wide) toggle, row],
            );
          },
        ),
      ),
    );
  }
}

/// Switches the current song between chord names and Nashville numbers;
/// stored as the personal Nashville overlay of the song (ADR-0006).
class _NashvilleToggle extends StatelessWidget {
  const _NashvilleToggle({
    required this.selected,
    required this.hasKey,
    required this.onChanged,
  });

  final bool selected;

  /// Nashville numbers need a key in the song.
  final bool hasKey;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Tooltip(
      message: hasKey ? '' : l10n.noKeyForNashville,
      child: SegmentedButton<bool>(
        key: const Key('live-nashville'),
        showSelectedIcon: false,
        style: const ButtonStyle(visualDensity: VisualDensity.compact),
        segments: [
          ButtonSegment(value: false, label: Text(l10n.liveChordNames)),
          ButtonSegment(value: true, label: Text(l10n.liveNashville)),
        ],
        selected: {hasKey && selected},
        onSelectionChanged: hasKey ? (s) => onChanged(s.single) : null,
      ),
    );
  }
}

class _LiveItemPage extends ConsumerWidget {
  const _LiveItemPage({
    required this.item,
    required this.index,
    required this.scrollController,
    required this.pdfController,
    required this.spreadController,
    required this.fitController,
    required this.songPageController,
    required this.preparation,
    required this.onTap,
  });

  final LiveItem item;

  /// Position of the item in the set.
  final int index;
  final ScrollController scrollController;
  final PdfViewerController pdfController;

  /// How far the page is built (issue #296).
  final PagePreparation preparation;

  /// Position when the PDF is shown as two pages side by side (landscape).
  final PdfSpreadController spreadController;

  /// Tap at a position of the page; the viewer of a PDF handles taps itself,
  /// so it forwards them to the tap zones of the live screen.
  final ValueChanged<Offset> onTap;

  /// Measures the font scale that fits the song to the page.
  final _FitController fitController;

  /// Page of a song split into pages.
  final SongPageController songPageController;

  /// Portrait: one page at a time, fit to width.
  /// The background around the pages follows the stage appearance.
  Widget _portraitPdf(StoredFile file, Key key, Color background) =>
      storedPdfViewer(
        file,
        key: key,
        controller: pdfController,
        params: PdfViewerParams(
          backgroundColor: background,
          // No text selection on stage: drags and long presses would
          // select text instead of moving the sheet.
          textSelectionParams: const PdfTextSelectionParams(enabled: false),
          onGeneralTap: (context, controller, details) {
            if (details.type != PdfViewerGeneralTapType.tap) return false;
            onTap(details.localPosition);
            return true;
          },
        ),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final song = item.song;
    if (song == null) return _MarkerPage(item: item);

    final overlay =
        ref.watch(overlayProvider(song.id)).value ??
        SongRepository.defaultOverlay(song.id);
    final attachments =
        ref.watch(attachmentsProvider(song.id)).value ??
        const <AttachmentEntry>[];
    final parsed = parseChordProCached(
      song.chordproSource,
      selectors: ref.watch(selectorsProvider),
    );

    // Set again below when the song is shown as ChordPro.
    fitController.fontScale = null;
    final pdf = livePdfFor(
      attachments,
      overlay.liveView,
      hasChordPro: parsed.hasContent,
    );
    if (pdf != null) {
      songPageController.attach(1);
      var file = ref.watch(attachmentStorageProvider).file(pdf.fileName);
      if (!file.existsSync()) {
        // The web client loads the PDF now (ADR-0018); the apps show it
        // once the sync has downloaded it (ADR-0009).
        final fetched = ref.watch(attachmentFileProvider(pdf.id));
        if (fetched.isLoading) {
          return const Center(
            key: Key('pdf-loading'),
            child: CircularProgressIndicator(),
          );
        }
        if (fetched.value case final loaded?) {
          file = loaded;
        } else {
          final l10n = AppLocalizations.of(context);
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                fetched.hasError ? l10n.pdfLoadFailed : l10n.pdfMissing,
                key: const Key('pdf-missing'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          );
        }
      }
      // Landscape: two pages side by side, fitted to the screen (ADR-0009).
      final stored = file;
      final pdfKey = ValueKey(pdf.id);
      return LayoutBuilder(
        builder: (context, constraints) =>
            constraints.maxWidth > constraints.maxHeight
            ? PdfSpreadView(
                key: pdfKey,
                documentRef: storedPdfDocumentRef(stored),
                controller: spreadController,
              )
            : _portraitPdf(
                stored,
                pdfKey,
                Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
      );
    }
    // In a set only the parts of the sequence are shown; which ones are
    // hidden is shown in the header.
    final sequence = item.setItemId == null
        ? null
        : item.setSequence ??
              item.arrangement?.sequence ??
              parsed.metaValue('x_sequence');
    final selection = sequence == null
        ? SequenceSelection(parsed, const [])
        : filterBySequenceCached(parsed, sequence);
    final storage = ref.watch(attachmentStorageProvider);
    return _ChordProPage(
      index: index,
      song: song,
      parsed: selection.song,
      hiddenParts: selection.hidden,
      overlay: overlay,
      setTranspose: item.bandTranspose + item.setTranspose,
      setSequence: item.setSequence,
      bandSequence: item.arrangement?.sequence,
      bandTempo: item.arrangement?.tempo,
      scrollController: scrollController,
      fitController: fitController,
      songPageController: songPageController,
      preparation: preparation,
      attachments: attachments,
      imageLookup: (src) {
        final image = imageAttachmentFor(attachments, src);
        return image == null ? null : storage.file(image.fileName);
      },
    );
  }
}

class _ChordProPage extends ConsumerWidget {
  const _ChordProPage({
    required this.index,
    required this.song,
    required this.parsed,
    required this.hiddenParts,
    required this.overlay,
    required this.setTranspose,
    required this.setSequence,
    required this.bandSequence,
    required this.bandTempo,
    required this.scrollController,
    required this.fitController,
    required this.songPageController,
    required this.preparation,
    required this.attachments,
    required this.imageLookup,
  });

  /// Position of the item in the set.
  final int index;
  final SongEntry song;
  final Song parsed;

  /// Parts hidden because they are not in the set's sequence.
  final List<String> hiddenParts;
  final SongOverlay overlay;

  /// Band arrangement and set item together (semitones to the song).
  final int setTranspose;
  final String? setSequence;
  final String? bandSequence;
  final int? bandTempo;
  final ScrollController scrollController;
  final _FitController fitController;
  final SongPageController songPageController;

  /// How far the page is built: a page that is not complete fits the song
  /// outside of frames and builds it in steps (issue #296).
  final PagePreparation preparation;

  /// Attachments of the song; [imageLookup] finds images among them.
  final List<AttachmentEntry> attachments;
  final ImageLookup imageLookup;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final l10n = AppLocalizations.of(context);
    final formatter = ChordFormatter.forSong(
      parsed,
      transpose: setTranspose + overlay.transpose,
      capo: overlay.capoFret,
      notation: settings.notation,
      nashville: overlay.nashville ?? settings.nashville,
      style: settings.chordStyle,
      superscript: settings.chordSuperscript,
    );
    final lyricsOnly = settings.displayMode == DisplayMode.lyricsOnly;
    final resolver = DiagramResolver(
      parsed,
      formatter,
      diagramInstrumentFor(settings.instrument),
    );
    final diagrams = diagramsPosition(parsed.diagrams, settings.diagrams);
    // The margins belong to the scroll view (and the header to the drag
    // area below), so drags on empty areas scroll the song too.
    return _DragToScroll(
      controller: scrollController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(_margin, 12, _margin, 12),
            child: SongHeader(
              title: song.title.isEmpty ? l10n.untitled : song.title,
              artist: song.artist,
              song: parsed,
              formatter: formatter,
              compact: true,
              stage: true,
              setSequence: setSequence,
              bandSequence: bandSequence,
              bandTempo: bandTempo,
              hiddenParts: hiddenParts,
              // Drummer mode (ADR-0026): the tempo as played tonight
              // starts the beat; the dots follow it.
              stageTempo: (bandTempo ?? parsed.tempo) == null
                  ? null
                  : StageTempoChip(index: index),
              stageBeat: BeatDots(index: index),
            ),
          ),
          Expanded(
            // Rebuilt when the preparation goes on, e.g. once the fit is
            // there.
            child: ListenableBuilder(
              listenable: preparation,
              builder: (context, _) => LayoutBuilder(
                builder: (context, constraints) {
                  final size = Size(
                    constraints.maxWidth - 2 * _margin,
                    constraints.maxHeight,
                  );
                  final scale = overlay.fontScale;
                  final textScaler = MediaQuery.textScalerOf(context);
                  final baseStyle = DefaultTextStyle.of(context).style;
                  // By content: the list is loaded anew after the page was
                  // disposed.
                  final attachmentsKey = [
                    for (final a in attachments)
                      '${a.id}/${a.name}/${a.fileName}',
                  ].join('\n');
                  final locale = Localizations.localeOf(context);
                  if (!settings.autoFit) {
                    songPageController.attach(1);
                    final columns = settings.columns == ColumnMode.auto
                        ? 1
                        : settings.maxColumns;
                    final collapse =
                        settings.chorusRepeat == ChorusRepeat.label;
                    // Fit to page keeps the columns and the chorus display and
                    // only measures the font scale (on demand: it measures
                    // every line of the song).
                    fitController.fontScale = () {
                      final fit = fitSong(
                        parsed,
                        formatter: formatter,
                        lyricsOnly: lyricsOnly,
                        labeler: sectionLabeler(l10n),
                        notes: overlay.notes,
                        baseFontSize: settings.fontSize,
                        maxFontSize: settings.fontSize * _maxFontScale,
                        minFontSize: settings.fontSize * _minFontScale,
                        size: size,
                        textScaler: textScaler,
                        baseStyle: baseStyle,
                        minColumns: columns,
                        maxColumns: columns,
                        chorusRepeat: collapse
                            ? ChorusRepeat.label
                            : ChorusRepeat.full,
                        diagramResolver: resolver,
                        diagramsPosition: diagrams,
                        imageLookup: imageLookup,
                      );
                      return fit.fits
                          // A small margin for measurement differences, which
                          // the fitted view absorbs with a FittedBox.
                          ? fit.fontSize / settings.fontSize * 0.98
                          : _minFontScale;
                    };
                    // Several columns are measured to split the song; the
                    // measurement does not depend on the font size.
                    final layoutKey = (
                      parsed,
                      formatter.transpose,
                      formatter.capo,
                      formatter.notation,
                      formatter.nashville,
                      formatter.style,
                      formatter.superscript,
                      lyricsOnly,
                      overlay.notes,
                      collapse,
                      diagrams,
                      settings.instrument,
                      textScaler,
                      baseStyle,
                      attachmentsKey,
                      locale,
                    );
                    SongLayout measure() => layoutSong(
                      parsed,
                      formatter: formatter,
                      lyricsOnly: lyricsOnly,
                      labeler: sectionLabeler(l10n),
                      notes: overlay.notes,
                      collapseRecalls: collapse,
                      diagramResolver: resolver,
                      diagramsPosition: diagrams,
                      textScaler: textScaler,
                      baseStyle: baseStyle,
                      imageLookup: imageLookup,
                    );
                    SongLayout? layout;
                    if (columns > 1) {
                      layout = preparation.complete
                          ? _layouts.get(layoutKey, measure)
                          : _layouts.lookup(layoutKey);
                      if (layout == null) {
                        return _later(() => _layouts.get(layoutKey, measure));
                      }
                    }
                    return _scrolling(
                      size,
                      _options(
                        formatter,
                        lyricsOnly,
                        settings.fontSize * scale,
                        columns,
                        collapse,
                        resolver,
                        diagrams,
                        layout: layout,
                      ),
                    );
                  }
                  final songColumns =
                      settings.columns == ColumnMode.auto &&
                          parsed.columns != null
                      ? parsed.columns!.clamp(1, 4)
                      : null;
                  // Rebuilds (page changes, overlay events) reuse the fit:
                  // fitting measures every line of the song.
                  final fitKey = (
                    parsed,
                    formatter.transpose,
                    formatter.capo,
                    formatter.notation,
                    formatter.nashville,
                    formatter.style,
                    formatter.superscript,
                    lyricsOnly,
                    overlay.notes,
                    settings.fontSize,
                    songColumns,
                    settings.maxColumns,
                    settings.chorusRepeat,
                    diagrams,
                    settings.instrument,
                    size,
                    textScaler,
                    baseStyle,
                    attachmentsKey,
                    locale,
                  );
                  SongFit fitNow() => fitSong(
                    parsed,
                    formatter: formatter,
                    lyricsOnly: lyricsOnly,
                    labeler: sectionLabeler(l10n),
                    notes: overlay.notes,
                    baseFontSize: settings.fontSize,
                    maxFontSize: settings.fontSize * 2,
                    minFontSize: AppSettings.minFontSize,
                    size: size,
                    textScaler: textScaler,
                    baseStyle: baseStyle,
                    // {columns} in the song wins over the automatic choice.
                    minColumns: songColumns ?? 1,
                    maxColumns: songColumns ?? settings.maxColumns,
                    chorusRepeat: settings.chorusRepeat,
                    diagramResolver: resolver,
                    diagramsPosition: diagrams,
                    imageLookup: imageLookup,
                    maxPages: _maxSongPages,
                  );
                  // A page that is prepared ahead fits the song outside of
                  // frames (issue #296); the page on stage at once.
                  final fit = preparation.complete
                      ? _fits.get(fitKey, fitNow)
                      : _fits.lookup(fitKey);
                  if (fit == null) {
                    return _later(() => _fits.get(fitKey, fitNow));
                  }
                  if (!fit.fits) {
                    songPageController.attach(1);
                    return _scrolling(
                      size,
                      _options(
                        formatter,
                        lyricsOnly,
                        fit.fontSize * scale,
                        fit.columns,
                        fit.collapseRecalls,
                        resolver,
                        diagrams,
                      ),
                    );
                  }
                  final pages = _songPages(fit, scale, size);
                  // Measured at the reference size: valid for any scale.
                  SongRenderOptions options(SongLayout? layout) => _options(
                    formatter,
                    lyricsOnly,
                    fit.fontSize * scale,
                    pages?.columns ?? fit.columns,
                    fit.collapseRecalls,
                    resolver,
                    diagrams,
                    layout: layout,
                  );
                  // Does not fit on pages (e.g. a section taller than the
                  // page at a large personal font scale): scrolling.
                  if (pages == null) {
                    songPageController.attach(1);
                    return _scrolling(size, options(fit.layout));
                  }
                  songPageController.attach(pages.ends.length);
                  // All pages of the song are built (and prepared ahead),
                  // so turning a page of the song only shows another one.
                  // Fits: no scrolling. FittedBox only shrinks, as a safety
                  // net for small measurement differences (e.g. wrapped
                  // notes).
                  final layout = fit.layout;
                  final pageBodies = <Widget>[];
                  var firstLine = 0;
                  for (final (page, end) in pages.ends.indexed) {
                    final start = page == 0 ? 0 : pages.ends[page - 1];
                    final pageLayout = layout == null || pages.ends.length == 1
                        ? layout
                        : (
                            blocks: layout.blocks.sublist(start, end),
                            metrics: layout.metrics.sublist(start, end),
                          );
                    pageBodies.add(
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.topLeft,
                        child: SizedBox(
                          width: size.width,
                          child: SongBody(
                            key: ValueKey(('song-page', page)),
                            song: parsed,
                            options: options(pageLayout),
                            progress: preparation.body,
                            firstLine: firstLine,
                          ),
                        ),
                      ),
                    );
                    for (final b in pageLayout?.blocks ?? const <SongBlock>[]) {
                      firstLine += songBlockLines(b);
                    }
                  }
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: _margin),
                    child: ListenableBuilder(
                      listenable: songPageController,
                      builder: (context, _) => IndexedStack(
                        index: math.min(
                          songPageController.page,
                          pageBodies.length - 1,
                        ),
                        sizing: StackFit.expand,
                        children: pageBodies,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Nothing below the header yet: [work] (fitting or measuring the song)
  /// runs outside of frames first (issue #296).
  Widget _later(VoidCallback work) {
    preparation
      ..pending = work
      ..body.total = null;
    return const SizedBox.shrink();
  }

  SongRenderOptions _options(
    ChordFormatter formatter,
    bool lyricsOnly,
    double fontSize,
    int columns,
    bool collapseRecalls,
    DiagramResolver resolver,
    DiagramsPosition diagrams, {
    SongLayout? layout,
  }) => SongRenderOptions(
    formatter: formatter,
    lyricsOnly: lyricsOnly,
    fontSize: fontSize,
    columns: columns,
    notes: overlay.notes,
    collapseRecalls: collapseRecalls,
    diagramResolver: resolver,
    diagramsPosition: diagrams,
    imageLookup: imageLookup,
    layout: layout,
  );

  /// Columns and pages of a fitted song at the personal font [scale]; null
  /// when it does not fit on pages and must scroll.
  ({int columns, List<int> ends})? _songPages(
    SongFit fit,
    double scale,
    Size size,
  ) {
    final layout = fit.layout;
    if (layout == null || layout.blocks.isEmpty) {
      return (columns: fit.columns, ends: [layout?.blocks.length ?? 0]);
    }
    // Breaks in the song decide the columns: one page, as fitted.
    if (forcedColumns(layout.blocks) != null) {
      return scale <= 1.0
          ? (columns: fit.columns, ends: [layout.blocks.length])
          : null;
    }
    final font = fit.fontSize * scale;
    // Larger text may need fewer columns: chord lines must fit.
    final widest = layout.metrics.fold<double>(
      0,
      (w, m) => math.max(w, m.minWidth),
    );
    var columns = fit.columns;
    while (columns > 1 &&
        columnWidth(size.width, columns, font) < widest * font) {
      columns--;
    }
    final width = columnWidth(size.width, columns, font);
    final ends = songPages(
      [for (final m in layout.metrics) m.height(font, width)],
      columns,
      size.height,
    );
    return ends == null ? null : (columns: columns, ends: ends);
  }

  Widget _scrolling(Size size, SongRenderOptions options) =>
      SingleChildScrollView(
        controller: scrollController,
        padding: EdgeInsets.fromLTRB(_margin, 0, _margin, size.height * 0.25),
        child: SongBody(
          song: parsed,
          options: options,
          progress: preparation.body,
        ),
      );
}

/// Results of [fitSong] for the songs of live mode.
final _fits = LruCache<Object, SongFit>(16);

/// Measured songs for scrolling with several columns.
final _layouts = LruCache<Object, SongLayout>(16);

/// Most pages a song is split into to fit it in live mode (ADR-0007).
const _maxSongPages = 4;

/// Page of a song that live mode splits into pages (ADR-0007).
class SongPageController extends ChangeNotifier {
  int _page = 0;
  int _count = 1;

  /// Shown page, 0-based.
  int get page => _page;

  /// Number of pages; 1 when the song is not split.
  int get count => _count;

  /// Sets the number of pages while the page is built; listeners (the page
  /// indicator) are told after the frame.
  void attach(int count) {
    final changed = count != _count || _page >= count;
    _count = math.max(1, count);
    _page = math.min(_page, _count - 1);
    if (changed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_disposed) notifyListeners();
      });
    }
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

/// Range of the personal font scale (ADR-0006).
const _minFontScale = 0.5;
const _maxFontScale = 2.5;

/// Lets the control bar fit the song of a page to the page.
class _FitController {
  /// Font scale at which the song fits the page; null when the page cannot
  /// be fitted (e.g. a PDF).
  double Function()? fontScale;
}

/// Horizontal page margin of a song in live mode.
const _margin = 20.0;

/// Lets vertical drags outside the scroll view (e.g. on the header) scroll
/// the song, with the same physics as a drag inside it. Drags that start in
/// the scroll view are handled there, as it wins the gesture arena.
class _DragToScroll extends StatefulWidget {
  const _DragToScroll({required this.controller, required this.child});

  final ScrollController controller;
  final Widget child;

  @override
  State<_DragToScroll> createState() => _DragToScrollState();
}

class _DragToScrollState extends State<_DragToScroll> {
  Drag? _drag;
  ScrollHoldController? _hold;

  ScrollPosition? get _position =>
      widget.controller.hasClients ? widget.controller.position : null;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.translucent,
    onVerticalDragDown: (_) => _hold = _position?.hold(() => _hold = null),
    onVerticalDragStart: (details) =>
        _drag = _position?.drag(details, () => _drag = null),
    onVerticalDragUpdate: (details) => _drag?.update(details),
    onVerticalDragEnd: (details) => _drag?.end(details),
    onVerticalDragCancel: () {
      _hold?.cancel();
      _drag?.cancel();
    },
    child: widget.child,
  );
}

class _MarkerPage extends StatelessWidget {
  const _MarkerPage({required this.item});

  final LiveItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              item.type == SetItemType.pause
                  ? Icons.local_cafe_outlined
                  : Icons.campaign_outlined,
              size: 72,
              color: theme.colorScheme.secondary,
            ),
            const SizedBox(height: 16),
            Text(
              item.title(AppLocalizations.of(context)),
              textAlign: TextAlign.center,
              style: theme.textTheme.displaySmall,
            ),
          ],
        ),
      ),
    );
  }
}

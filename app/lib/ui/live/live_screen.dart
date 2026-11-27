import 'dart:async';
import 'dart:math' as math;

import 'package:drift/drift.dart' show Value;
import 'package:chordpro/chordpro.dart' as cp show Key;
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../platform/stage_wake_lock.dart';
import '../../projection/projection_controller.dart';
import '../../projection/projection_token_store.dart';
import '../../sync/sync_controller.dart';
import '../../data/database.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../midi/live_midi_sender.dart';
import '../../midi/midi_connection.dart';
import '../../providers.dart';
import '../routes.dart' show AppPaths;
import '../../settings/settings.dart';
import '../../data/song_review.dart' show SongReportLocation;
import '../songs/song_reports.dart' show reportMistake;
import '../annotations/annotation_editor.dart';
import '../annotations/annotation_toolbar.dart';
import '../render/render_cache.dart';
import '../widgets/dialogs.dart';
import 'live_midi_sheet.dart';
import 'live_preparation.dart';
import '../../audio/metronome.dart';
import 'live_beat.dart';
import 'page_turner.dart';
import 'live_theme.dart';
import 'set_progress_bar.dart';
import 'projection_bar.dart';
import 'live_control_bar.dart';
import 'live_item_page.dart';
import 'live_projection.dart';
import 'live_stage_pages.dart';
import 'live_item.dart';

export 'live_item.dart' show LiveItem;
export 'song_page_controller.dart' show SongPageController;

/// Keys that turn forward / back, exactly like the right / left tap zones
/// (ADR-0007); see [pageTurnNextKeys]. Like the tap zones, the arrows
/// up/down scroll a song that does not fit before turning.
final _nextKeys = pageTurnNextKeys;
final _previousKeys = pageTurnPreviousKeys;

/// Keys that start and stop the beat (ADR-0026); Space too when
/// [AppSettings.spaceStartsBeat] is on (#969).
final _beatKeys = {LogicalKeyboardKey.enter, LogicalKeyboardKey.numpadEnter};

/// A forward key held this long starts or stops the beat instead of
/// turning (ADR-0026).
const beatLongPress = Duration(milliseconds: 600);

/// Performance mode (ADR-0007): full screen, screen stays on, page turning
/// by tap, swipe, page turner or keyboard. The items are loaded once when
/// live mode starts, so incoming changes never alter what is on stage.
class LiveScreen extends ConsumerStatefulWidget {
  const LiveScreen({super.key, required this.items, this.initialIndex = 0});

  final List<LiveItem> items;
  final int initialIndex;

  /// Opens the set [setId] at its item [index], or with [firstSong] at its
  /// first song, skipping pauses and texts before it (the overview's *Start
  /// live*, ADR-0045). The route loads the set ([loadSet], ADR-0065).
  static Future<void> openSet(
    BuildContext context,
    String setId, {
    int index = 0,
    bool firstSong = false,
  }) async {
    final container = ProviderScope.containerOf(context, listen: false);
    final loaded = await loadSet(
      container,
      setId,
      index: index,
      firstSong: firstSong,
    );
    if (loaded.items.isEmpty || !context.mounted) return;
    final location = AppPaths.setLive(setId, index: loaded.start);
    _loaded[location] = loaded.items;
    await context.push<void>(location);
  }

  /// Items [openSet] and [openSong] loaded before opening the route, so
  /// [LiveRoute] does not load them again; taken once.
  static final _loaded = <String, List<LiveItem>>{};

  /// The items loaded for [location] by [openSet] or [openSong], once.
  static List<LiveItem>? takeLoaded(String location) =>
      _loaded.remove(location);

  /// The items of the set [setId] and the index to start at: [index], or
  /// with [firstSong] its first song. Empty when the set has no items.
  static Future<({List<LiveItem> items, int start})> loadSet(
    ProviderContainer container,
    String setId, {
    int index = 0,
    bool firstSong = false,
  }) async {
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
          LiveItem.marker(v.item.icon, v.item.note)
        else if (v.song != null)
          LiveItem.song(
            v.song!,
            arrangement: arrangements[v.song!.id],
            setTranspose: v.item.transpose,
            setSequence: v.item.sequence,
            setItemId: v.item.id,
          ),
    ];
    if (items.isEmpty) return (items: items, start: 0);
    final start = firstSong
        ? items.indexWhere((i) => i.song != null).clamp(0, items.length - 1)
        : index.clamp(0, items.length - 1);
    return (items: items, start: start);
  }

  /// Opens a song by itself; [attachmentId] shows that PDF attachment
  /// instead of the personal live view choice (#507).
  static Future<void> openSong(
    BuildContext context,
    String songId, {
    String? attachmentId,
  }) async {
    final container = ProviderScope.containerOf(context, listen: false);
    final items = await loadSong(container, songId, attachmentId: attachmentId);
    if (items.isEmpty || !context.mounted) return;
    final location = AppPaths.songLive(songId, attachmentId: attachmentId);
    _loaded[location] = items;
    await context.push<void>(location);
  }

  /// The song [songId] alone as a live item, or no item if it is missing.
  static Future<List<LiveItem>> loadSong(
    ProviderContainer container,
    String songId, {
    String? attachmentId,
  }) async {
    final song = await container.read(songRepositoryProvider).getSong(songId);
    if (song == null) return const [];
    // Outside a set the song keeps its own key and tempo; only the sequence
    // of the band chosen on the sets tab applies (ADR-0025, #552).
    final band = container.read(arrangementBandProvider(song.libraryId));
    final arrangement = band == null
        ? null
        : await container
              .read(arrangementRepositoryProvider)
              .get(band.id, song.id);
    final sequenceOnly = arrangement?.sequence == null
        ? null
        : arrangement!.copyWith(transpose: 0, tempo: const Value(null));
    return [
      LiveItem.song(
        song,
        arrangement: sequenceOnly,
        attachmentId: attachmentId,
      ),
    ];
  }

  @override
  ConsumerState<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends ConsumerState<LiveScreen> {
  late int _index = widget.initialIndex;

  /// Where each item stands and how turns move on (ADR-0007).
  late final LiveStagePages _stage = LiveStagePages(
    items: _items,
    initialIndex: widget.initialIndex,
    current: () => _index,
    preparation: _preparation,
    step: () => _step,
    turnSlide: _turnSlide,
    onSongPage: _followSongPage,
  );

  /// What the person sees, for the screenshot of a report (ADR-0060).
  final _view = GlobalKey();
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
    loadOverlay: (songId) =>
        ref.read(songRepositoryProvider).getOverlay(songId),
  );

  /// Sends the keyboard program of the current song (ADR-0039).
  late final LiveMidiSender _midi = LiveMidiSender(
    enabled: () => ref.read(midiConnectionProvider).enabled,
    // The program of this device's profile (ADR-0042).
    program: (songId) => ref
        .read(songRepositoryProvider)
        .midiProgram(songId, ref.read(midiProfileProvider).id),
    send: (program) => ref.read(midiConnectionProvider.notifier).send(program),
  );

  /// The screen stays on while live mode is open (ADR-0007).
  late final StageWakeLock _wakeLock = ref.read(stageWakeLockProvider);

  /// Drawing mode for freehand annotations (ADR-0032); the pages share it.
  late final AnnotationEditor _annotations =
      AnnotationEditor(ref.read(annotationRepositoryProvider))
        ..fingerDraws = ref.read(settingsProvider).annotationFinger
        ..addListener(_onAnnotations);

  void _onAnnotations() {
    // Drawing with a finger is a device setting (ADR-0032).
    final finger = _annotations.fingerDraws;
    if (finger != ref.read(settingsProvider).annotationFinger) {
      ref
          .read(settingsProvider.notifier)
          .update((s) => s.copyWith(annotationFinger: finger));
    }
    if (_drawing != _annotations.active) {
      setState(() => _drawing = _annotations.active);
    }
  }

  bool _drawing = false;

  /// Deletes all annotations of a song, with "Undo" (#267).
  Future<void> _deleteAnnotations(String songId) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(annotationRepositoryProvider);
    final removed = await repo.deleteAll(songId);
    if (removed.isEmpty) return;
    showUndo(
      messenger,
      l10n.annotationsDeleted,
      undoLabel: l10n.undo,
      onUndo: () => repo.restoreAll(songId, removed),
    );
  }

  /// Sets the wake lock again when the app returns to the foreground: not
  /// every platform keeps it while the app is in the background. Stops the
  /// beat when the app is hidden, unless the settings keep it (#424).
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _wakeLock
      ..addListener(_onWakeLockChanged)
      ..acquire();
    _lifecycle = AppLifecycleListener(
      onResume: _wakeLock.reassert,
      onHide: _onHide,
    );
    _setFullScreen(true);
    _sync.pause();
    FocusManager.instance.addEarlyKeyEventHandler(_onKey);
    _preparation.focus(_index);
    // Created with the screen: it reads providers, which dispose must not.
    _projection;
    _midi.show(_index, _items[_index].song?.id);
    // With the automatic start the first song counts in.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _beat.onItemShown(_index);
    });
  }

  /// The app went to the background (minimised, another app, the screen
  /// locked; not a split screen, where it stays visible).
  void _onHide() {
    if (_beat.settings.clickInBackground == ClickInBackground.stop) {
      _beat.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
  }

  @override
  void dispose() {
    FocusManager.instance.removeEarlyKeyEventHandler(_onKey);
    _longPress?.cancel();
    _sync.resume();
    _lifecycle.dispose();
    _wakeLock
      ..removeListener(_onWakeLockChanged)
      ..release();
    _setFullScreen(false);
    _stage.dispose();
    _preparation.dispose();
    _projection
      ..removeListener(_onProjection)
      ..dispose();
    _midi.dispose();
    _beat.dispose();
    _annotations
      ..removeListener(_onAnnotations)
      ..dispose();
    super.dispose();
  }

  /// Shows or hides the wake lock notice in the bottom bar.
  void _onWakeLockChanged() => setState(() {});

  Future<void> _setFullScreen(bool on) async {
    await SystemChrome.setEnabledSystemUIMode(
      on ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
  }

  /// The lyrics projection (ADR-0068).
  late final LiveProjection _projection = LiveProjection(
    host: ref.read(projectionHostProvider),
    items: _items,
    settings: () => ref.read(settingsProvider),
    l10n: () => AppLocalizations.of(context),
    token: () => ref.read(projectionTokenProvider).token,
    renewToken: () => ref.read(projectionTokenProvider).renew(),
    languageVersions: (songId) =>
        ref.read(songRepositoryProvider).languageVersions(songId),
    parse: (chordpro) =>
        parseChordProCached(chordpro, selectors: ref.read(selectorsProvider)),
    section: (index) => _stage.songPage(index)?.section,
  )..addListener(_onProjection);

  /// Starts the projection and shows its links.
  Future<void> _startProjection(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    try {
      await _projection.start(lang: lang);
    } catch (_) {
      showMessageOn(messenger, l10n.projectionStartFailed);
      return;
    }
    _projection.show(_index);
    if (context.mounted) await _showProjectionLinks(context);
  }

  Future<void> _showProjectionLinks(BuildContext context) =>
      showProjectionSheet(
        context,
        _projection.controller!,
        onRenew: _projection.renew,
      );

  void _onProjection() {
    if (mounted) setState(() {});
  }

  /// The page of the song on stage changed: the projection follows the
  /// section at its top.
  void _followSongPage(int index) {
    if (index != _index) return;
    _projection.followSection(_stage.songPage(index)?.section);
  }

  double get _step =>
      ref.read(settingsProvider).pageTurn == PageTurnMode.half ? 0.5 : 0.85;

  /// With *Turning pages moves the slides* (#1181), a turn while projecting
  /// moves the projected slide first; true when it did. Live mode shows the
  /// page of the slide's section.
  bool _turnSlide({required bool forward}) =>
      _projection.turnSlide(forward: forward, pages: _stage.songPage(_index));

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
    // Space starts and stops the beat instead of turning, when chosen
    // (#969).
    final spaceBeat =
        key == LogicalKeyboardKey.space &&
        ref.read(settingsProvider).spaceStartsBeat;
    final next = !spaceBeat && _nextKeys.contains(key);
    // For the readiness tile of the overview (#911).
    if (event is KeyDownEvent && !spaceBeat && isPageTurnKey(key)) {
      ref.read(pageTurnerProvider.notifier).used();
    }
    if (next && _beat.canBeat(_index)) {
      // With a beat, a forward key held for [beatLongPress] starts or stops
      // it and does not turn (ADR-0026); a shorter press turns when it is
      // released. Key repeat is ignored as before.
      if (event is KeyDownEvent) {
        _longPress?.cancel();
        _longPressed = false;
        final index = _index;
        _longPress = Timer(beatLongPress, () {
          _longPressed = true;
          if (mounted) _beat.toggle(index);
        });
      } else if (event is KeyUpEvent) {
        final pending = _longPress?.isActive ?? false;
        _longPress?.cancel();
        _longPress = null;
        if (pending && !_longPressed) _stage.next();
      }
      return KeyEventResult.handled;
    }
    if (next || _previousKeys.contains(key)) {
      // One press turns once. A held key (key repeat) does not turn again,
      // so it never races through the pages and songs of the set.
      if (event is KeyDownEvent) next ? _stage.next() : _stage.previous();
      return KeyEventResult.handled;
    }
    if (spaceBeat || _beatKeys.contains(key)) {
      if (event is KeyDownEvent && _beat.canBeat(_index)) {
        _beat.toggle(_index);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      if (event is KeyDownEvent) {
        if (_annotations.active) {
          _annotations.active = false;
        } else {
          Navigator.maybePop(context);
        }
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// The pages of the set, kept when the wide song map's panel comes or goes.
  final _pageAreaKey = GlobalKey();

  /// Long press of a forward key (ADR-0026).
  Timer? _longPress;
  bool _longPressed = false;

  /// Width of the page area, for the tap zones.
  double _width = 0;

  void _onTap(Offset position) => _onStageTap(position.dx + _pageLeft);

  /// Left edge of the page area on the stage: the width of the panel of the
  /// wide song map, otherwise 0.
  double _pageLeft = 0;

  /// Width of the whole stage, for the tap zones.
  double _stageWidth = 0;

  /// The tap zones are thirds of the whole stage (ADR-0007), also beside the
  /// panel of the wide song map (ADR-0026, #363).
  void _onStageTap(double x) {
    final width = _stageWidth > 0 ? _stageWidth : _width;
    if (x < width * 0.3) {
      _stage.previous();
    } else if (x > width * 0.7) {
      _stage.next();
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
      _stage.next();
    } else if (velocity.abs() > 300 ? velocity > 0 : distance > _width * 0.2) {
      _stage.previous();
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
    if (target != null) _stage.jumpTo(target);
  }

  /// The keyboard program of the current song (#607); [context] is below
  /// the stage theme, which the sheet follows.
  Future<void> _editProgram(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final song = _items[_index].song!;
    return showLiveMidiSheet(
      context,
      ref,
      songId: song.id,
      earlier: [
        for (var i = _index - 1; i >= 0; i--)
          if (_items[i].song case final s?)
            (id: s.id, title: _items[i].title(l10n)),
      ],
      sendAgain: _midi.sendAgain,
    );
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
        : _stage.fitFor(_index).fontScale?.call();
    if (scale == null) return;
    await _adjust((o) => o.copyWith(fontScale: scale));
  }

  @override
  Widget build(BuildContext context) {
    // The projection follows its settings (ADR-0068 §11).
    ref.listen(
      settingsProvider,
      (previous, next) => _projection.settingsChanged(previous, next, _index),
    );
    // The current song's grouping and subdivisions of the click (#698).
    final currentSong = _items[_index].song;
    if (currentSong != null) {
      ref.listen(overlayProvider(currentSong.id), (_, next) {
        final overlay = next.value;
        if (overlay != null) _beat.overlayChanged(overlay);
      });
    }
    final (appearance, accent) = ref.watch(
      settingsProvider.select((s) => (s.liveAppearance, s.accent)),
    );
    _annotations.repository = ref.watch(annotationRepositoryProvider);
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
    if (showProgress) _stage.scheduleProgress();
    final showSongMap = ref.watch(
      settingsProvider.select((s) => s.showSongMap),
    );
    // Set or song map beside the beat on small screens (#952).
    final drumView = ref.watch(settingsProvider.select((s) => s.drumPanelView));
    final web = ref.watch(webClientProvider);
    final midi = ref.watch(midiConnectionProvider);
    // Small screens in landscape (ADR-0026): the set list shows what comes
    // next; the line below only shows for its notices, so the set has room.
    final screen = MediaQuery.sizeOf(context);
    final compactLandscape =
        showSongMap &&
        screen.shortestSide < _compactDrums &&
        screen.width > screen.height;

    return Scaffold(
      // The on-screen keyboard of a text annotation (#570) covers the page
      // instead of shrinking it: a smaller page would lay the song out
      // anew. The text field lifts itself above the keyboard.
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          children: [
            // The control bar overlays the page, so showing it does not
            // change the page size (and does not fit the song again).
            // Below the page the progress bar of the set: where the set
            // stands, seen at a glance, and held to jump (#979); below the
            // page, so it never covers text.
            Expanded(
              child: SetProgressScrubber(
                showBar: showProgress,
                // The control bar and the drawing tools cover the bottom of
                // the page and have their own long presses.
                enabled: !_controls && !_drawing,
                markers: [for (final item in items) item.song == null],
                progress: _stage.progress,
                labelOf: (i) => _nextLabel(i, l10n),
                onJump: _stage.jumpTo,
                child: LayoutBuilder(
                  builder: (context, outer) {
                    // Phones (ADR-0026): every turn is a song.
                    final phone =
                        showSongMap &&
                        math.min(outer.maxWidth, outer.maxHeight) <
                            _compactDrums;
                    // Wide song map (ADR-0026): the beat large and the set on
                    // the left, the song on the right.
                    final wide =
                        showSongMap && !phone && outer.maxWidth >= _wideSongMap;
                    // Below the wide song map (phones, tablets in portrait):
                    // the drum panel fills the stage, the beat with the set
                    // or the song map (#421, #952, #974).
                    final compact = showSongMap && !wide;
                    final panelWidth = (outer.maxWidth * 0.36).clamp(
                      300.0,
                      480.0,
                    );
                    _stageWidth = outer.maxWidth;
                    // The drum panel shows the song map of the current song
                    // instead of the set on demand (#952); the beat stays.
                    final compactMap =
                        compact && drumView == DrumPanelView.songMap;
                    // On tablets the pedal scrolls the song map and turns at
                    // its end (#974); on phones and beside the set it turns
                    // songs.
                    _stage.compact = phone || (compact && !compactMap);
                    final compactLandscapeStage =
                        outer.maxWidth > outer.maxHeight;
                    // The divider after the panel is one pixel wide; on a
                    // small screen in landscape the beat takes half of it.
                    _pageLeft = wide
                        ? panelWidth + 1
                        : compactMap && compactLandscapeStage
                        ? (outer.maxWidth + 1) / 2
                        : 0;
                    final largeBeat = wide || compact;
                    if (_beat.largeBeat != largeBeat) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) _beat.largeBeat = largeBeat;
                      });
                    }
                    // Keeps the pages (and their state) when the panel comes
                    // or goes, e.g. when the tablet is turned.
                    final page = KeyedSubtree(
                      key: _pageAreaKey,
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
                                if (showProgress) _stage.scheduleProgress();
                                return false;
                              },
                              child: RepaintBoundary(
                                key: _view,
                                child: PageView.builder(
                                  controller: _stage.pageView,
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
                                    if (i > _index) {
                                      _stage.songPageFor(i).first();
                                    }
                                    // Small screens turn songs only: the song
                                    // map of each starts at the top (#952).
                                    if (_stage.compact) {
                                      final sc = _stage.scroll(i);
                                      if (sc != null && sc.hasClients) {
                                        sc.jumpTo(0);
                                      }
                                    }
                                    final back = i < _index;
                                    _index = i;
                                    _preparation.focus(i);
                                    // The projection follows (ADR-0068);
                                    // turning back into a song whose slides
                                    // the turns move ends at its last slide
                                    // (#1181).
                                    _projection.itemShown(i, back: back);
                                    // Only another set item sends its
                                    // keyboard program, never a page within a
                                    // song or a prepared neighbour (ADR-0039).
                                    _midi.show(i, items[i].song?.id);
                                    // Another item stops the beat (ADR-0026).
                                    _beat.onItemShown(i);
                                  }),
                                  itemBuilder: (context, i) =>
                                      _pageWidgets.putIfAbsent(
                                        i,
                                        () => PreparedPage(
                                          preparation: _preparation[i],
                                          child: LiveItemPage(
                                            item: items[i],
                                            index: i,
                                            scrollController: _stage.scrollFor(
                                              i,
                                            ),
                                            pdfController: _stage.pdfFor(i),
                                            spreadController: _stage.spreadFor(
                                              i,
                                            ),
                                            fitController: _stage.fitFor(i),
                                            songPageController: _stage
                                                .songPageFor(i),
                                            preparation: _preparation[i],
                                            onTap: _onTap,
                                            annotations: _annotations,
                                          ),
                                        ),
                                      ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                    return Stack(
                      children: [
                        Positioned.fill(
                          child: compact
                              ? Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    // The pages stay built for the page
                                    // controller and the preparation, unseen
                                    // unless they show the song map.
                                    if (!compactMap) Offstage(child: page),
                                    // Empty areas of the panel are the tap
                                    // zones; the set list and the buttons keep
                                    // their taps.
                                    GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTapUp: (d) =>
                                          _onStageTap(d.localPosition.dx),
                                      child: DrumPanel(
                                        items: items,
                                        current: _index,
                                        onSelect: _stage.jumpTo,
                                        direction: compactLandscapeStage
                                            ? Axis.horizontal
                                            : Axis.vertical,
                                        view: drumView,
                                        onView: (view) => ref
                                            .read(settingsProvider.notifier)
                                            .update(
                                              (s) => s.copyWith(
                                                drumPanelView: view,
                                              ),
                                            ),
                                        songMap: compactMap ? page : null,
                                      ),
                                    ),
                                  ],
                                )
                              : !wide
                              ? page
                              : Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    SizedBox(
                                      width: panelWidth,
                                      // Empty areas of the panel are part of the tap zones;
                                      // the set list and the buttons keep their taps.
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTapUp: (d) =>
                                            _onStageTap(d.localPosition.dx),
                                        child: DrumPanel(
                                          items: items,
                                          current: _index,
                                          onSelect: _stage.jumpTo,
                                        ),
                                      ),
                                    ),
                                    const VerticalDivider(width: 1),
                                    Expanded(child: page),
                                  ],
                                ),
                        ),
                        // Beat of the drummer mode (ADR-0026); take no taps.
                        const Positioned.fill(child: EdgeFlash()),
                        const Positioned.fill(child: CountInOverlay()),
                        // The projection bar while projecting (ADR-0068), at
                        // the bottom centre, clear of the song's header
                        // (key, tempo, time); the controls take its place
                        // while they are open.
                        if (_projection.controller case final projection?
                            when projection.running && !_controls && !_drawing)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 8,
                            child: SafeArea(
                              child: Center(
                                child: ProjectionBar(
                                  controller: projection,
                                  onShowLinks: () =>
                                      _showProjectionLinks(context),
                                ),
                              ),
                            ),
                          ),
                        // Drawing mode (ADR-0032): the tools instead of the
                        // controls, until "Done".
                        if (_drawing)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: AnnotationToolbar(
                              editor: _annotations,
                              onDone: () => _annotations.active = false,
                              onDeleteAll: switch (items[_index].song) {
                                final song? => () => _deleteAnnotations(
                                  song.id,
                                ),
                                null => null,
                              },
                            ),
                          )
                        else if (_controls)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: LiveControlBar(
                              item: items[_index],
                              index: _index,
                              onExit: () => Navigator.pop(context),
                              onOverview: () => _showOverview(context),
                              // Key, font and Nashville change the song,
                              // which phones and the set do not show
                              // (ADR-0026, #974).
                              onAdjust:
                                  items[_index].song == null ||
                                      phone ||
                                      (compact && !compactMap)
                                  ? null
                                  : _adjust,
                              // The click also on small screens (#698).
                              onAdjustClick: items[_index].song == null
                                  ? null
                                  : _adjust,
                              onFit: _fitToPage,
                              onSetKey: _setKey,
                              onDraw: items[_index].song == null || showSongMap
                                  ? null
                                  : () => _annotations.active = true,
                              // Everyone may report a mistake (ADR-0060);
                              // stored now, synced after the set.
                              onReport: switch (items[_index].song) {
                                null => null,
                                final song => () => reportMistake(
                                  context,
                                  ref,
                                  songId: song.id,
                                  location: SongReportLocation(
                                    page: _stage.songPageFor(_index).page + 1,
                                  ),
                                  captureKey: _view,
                                ),
                              },
                              // Only while MIDI program changes are on
                              // (ADR-0039).
                              onSendProgram:
                                  midi.enabled && items[_index].song != null
                                  ? _midi.sendAgain
                                  : null,
                              onEditProgram:
                                  midi.enabled && items[_index].song != null
                                  ? () => _editProgram(context)
                                  : null,
                              // Native apps only (ADR-0068); while on, the
                              // button shows the links.
                              onProject: !ref.watch(projectionSupportedProvider)
                                  ? null
                                  : _projection.running
                                  ? () => _showProjectionLinks(context)
                                  : () => _startProjection(context),
                              projecting: _projection.running,
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: _beat.metronome.clickUnavailable,
              builder: (context, clickUnavailable, bar) =>
                  compactLandscape &&
                      !web &&
                      !(midi.enabled && !midi.connected) &&
                      !clickUnavailable &&
                      !_wakeLock.failed
                  ? const SizedBox.shrink(key: Key('live-info-hidden'))
                  : bar!,
              child: Container(
                key: const Key('live-info'),
                color: theme.colorScheme.surfaceContainer,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    if (compactLandscape)
                      const Spacer()
                    else
                      Expanded(
                        child: Text(
                          next == null
                              ? l10n.liveEnd
                              : l10n.liveNext(_nextLabel(_index + 1, l10n)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                    // Web: no offline guarantee (ADR-0018).
                    if (web) ...[
                      const SizedBox(width: 12),
                      Icon(
                        Icons.cloud_off,
                        size: 18,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(width: 8),
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
                      const SizedBox(width: 8),
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
                      listenable: _stage.songPageFor(_index),
                      builder: (context, _) {
                        final pages = _stage.songPageFor(_index);
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
                    // The keyboard (ADR-0039), only while MIDI program
                    // changes are on, with the program the current song
                    // wants on it, if it has one (#605).
                    if (midi.enabled)
                      Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Tooltip(
                              message: midi.connected
                                  ? l10n.liveMidiConnected(
                                      midi.deviceName ?? '',
                                    )
                                  : l10n.liveMidiNotConnected,
                              child: Icon(
                                midi.connected ? Icons.piano : Icons.piano_off,
                                key: Key(
                                  midi.connected
                                      ? 'live-midi-connected'
                                      : 'live-midi-not-connected',
                                ),
                                size: 18,
                                semanticLabel: midi.connected
                                    ? l10n.liveMidiConnected(
                                        midi.deviceName ?? '',
                                      )
                                    : l10n.liveMidiNotConnected,
                                color: midi.connected
                                    ? null
                                    : theme.colorScheme.error,
                              ),
                            ),
                            if (items[_index].song case final song?)
                              LiveMidiProgramLabel(songId: song.id),
                          ],
                        ),
                      ),
                    Text(
                      l10n.livePosition(_index + 1, items.length),
                      style: theme.textTheme.titleSmall,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _nextLabel(int index, AppLocalizations l10n) {
    final item = _items[index];
    final key = item.song?.songKey;
    final title = item.title(l10n);
    // For the drums the next song's tempo and time signature (ADR-0026).
    final tempo = _beat.settings.showSongMap ? _beat.tempoOf(index) : null;
    final beat = tempo == null
        ? ''
        : ' · ${l10n.bpm(tempo)} · ${_beat.meterOf(index)}';
    if (key == null) return '$title$beat';
    final parsed = cp.Key.tryParse(key);
    final shown = parsed == null
        ? key
        : parsed
              .transpose(item.bandTranspose + item.setTranspose)
              .format(ref.read(settingsProvider).notation);
    return '$title ($shown)$beat';
  }
}

/// Minimum width of the stage for the wide song map: beat and set on the
/// left, the song on the right (ADR-0026; the breakpoint of the app's other
/// two-column layouts).
const _wideSongMap = 900.0;

/// Below this shortest side of the stage (phones), drummer mode shows only
/// the beat and the set, no song map (ADR-0026, #421).
const _compactDrums = 600.0;

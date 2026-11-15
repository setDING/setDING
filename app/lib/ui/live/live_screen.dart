import 'dart:math' as math;

import 'package:chordpro/chordpro.dart' hide Key;
import 'package:chordpro/chordpro.dart' as cp show Key;
import 'package:flutter/gestures.dart' show Drag;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../sync/sync_controller.dart';
import '../../data/attachment_lookup.dart';
import '../../data/attachment_storage.dart';
import '../../data/database.dart';
import '../../data/song_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../providers.dart';
import '../../settings/settings.dart';
import '../render/song_header.dart';
import '../render/chord_diagram.dart';
import '../render/render_cache.dart';
import '../render/song_image.dart';
import '../render/song_view.dart';
import '../widgets/key_picker.dart';

/// One entry of the live sequence.
class LiveItem {
  const LiveItem.song(
    SongEntry this.song, {
    this.setTranspose = 0,
    this.setSequence,
    this.setItemId,
  }) : type = SetItemType.song,
       label = null;

  const LiveItem.marker(this.type, this.label)
    : song = null,
      setTranspose = 0,
      setSequence = null,
      setItemId = null;

  final SetItemType type;
  final SongEntry? song;

  /// Transposition from the set item (layer 2, ADR-0006).
  final int setTranspose;

  /// Song sequence from the set item (layer 2, ADR-0006).
  final String? setSequence;

  /// The set item this entry comes from; null when a single song is played.
  final String? setItemId;
  final String? label;

  LiveItem withSetTranspose(int value) => LiveItem.song(
    song!,
    setTranspose: value,
    setSequence: setSequence,
    setItemId: setItemId,
  );

  String title(AppLocalizations l10n) => song == null
      ? (label ?? '')
      : (song!.title.isEmpty ? l10n.untitled : song!.title);
}

/// Keys that turn forward / backward (Bluetooth page turners send these).
final _nextKeys = {
  LogicalKeyboardKey.arrowRight,
  LogicalKeyboardKey.arrowDown,
  LogicalKeyboardKey.pageDown,
  LogicalKeyboardKey.space,
  LogicalKeyboardKey.enter,
};
final _prevKeys = {
  LogicalKeyboardKey.arrowLeft,
  LogicalKeyboardKey.arrowUp,
  LogicalKeyboardKey.pageUp,
  LogicalKeyboardKey.backspace,
};

/// Performance mode (ADR-0007): full screen, screen stays on, page turning
/// via pedal, keyboard, tap or swipe. The items are loaded once when live
/// mode starts, so incoming changes never alter what is on stage.
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
    final views = await container.read(setRepositoryProvider).getItems(setId);
    final items = [
      for (final v in views)
        if (v.item.type != SetItemType.song)
          LiveItem.marker(v.item.type, v.item.note)
        else if (v.song != null)
          LiveItem.song(
            v.song!,
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
    if (song == null || !context.mounted) return;
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
  final _focus = FocusNode();
  bool _controls = false;

  /// Items as shown; the key of a set item can be changed during live mode.
  late final List<LiveItem> _items = [...widget.items];

  /// Sync is paused on stage: nothing changes what is shown (ADR-0007).
  late final SyncController _sync = ref.read(syncControllerProvider.notifier);

  @override
  void initState() {
    super.initState();
    _setStageMode(true);
    _sync.pause();
  }

  @override
  void dispose() {
    _sync.resume();
    _setStageMode(false);
    _pages.dispose();
    for (final c in _scroll.values) {
      c.dispose();
    }
    _focus.dispose();
    super.dispose();
  }

  Future<void> _setStageMode(bool on) async {
    try {
      await (on ? WakelockPlus.enable() : WakelockPlus.disable());
    } catch (_) {
      // Not available on this platform (e.g. tests).
    }
    await SystemChrome.setEnabledSystemUIMode(
      on ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
  }

  ScrollController _scrollFor(int index) =>
      _scroll.putIfAbsent(index, ScrollController.new);
  PdfViewerController _pdfFor(int index) =>
      _pdf.putIfAbsent(index, PdfViewerController.new);

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
    final pdf = _pdf[_index];
    if (pdf != null && pdf.isReady) {
      final page = pdf.pageNumber ?? 1;
      if (page < pdf.pageCount) {
        pdf.goToPage(pageNumber: page + 1);
        return;
      }
    }
    if (_index < _items.length - 1) {
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
    final pdf = _pdf[_index];
    if (pdf != null && pdf.isReady && (pdf.pageNumber ?? 1) > 1) {
      pdf.goToPage(pageNumber: pdf.pageNumber! - 1);
      return;
    }
    if (_index > 0) {
      _pages.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (_nextKeys.contains(event.logicalKey)) {
      _next();
      return KeyEventResult.handled;
    }
    if (_prevKeys.contains(event.logicalKey)) {
      _previous();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.maybePop(context);
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

  Future<void> _showOverview() async {
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
    if (target != null) _pages.jumpToPage(target);
    _focus.requestFocus();
  }

  /// Changes the key of the current set item. It is stored on the set item,
  /// so the song itself stays unchanged.
  Future<void> _setKey(int transpose) async {
    final item = _items[_index];
    final id = item.setItemId;
    if (id == null) return;
    setState(() => _items[_index] = item.withSetTranspose(transpose));
    await ref.read(setRepositoryProvider).setItemTranspose(id, transpose);
  }

  Future<void> _adjust(SongOverlay Function(SongOverlay) change) async {
    final song = _items[_index].song;
    if (song == null) return;
    final repo = ref.read(songRepositoryProvider);
    await repo.saveOverlay(change(await repo.getOverlay(song.id)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final items = _items;
    final next = _index < items.length - 1 ? items[_index + 1] : null;
    final theme = Theme.of(context);

    return Scaffold(
      body: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: SafeArea(
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
                            child: PageView.builder(
                              controller: _pages,
                              itemCount: items.length,
                              onPageChanged: (i) => setState(() => _index = i),
                              itemBuilder: (context, i) => _LiveItemPage(
                                item: items[i],
                                scrollController: _scrollFor(i),
                                pdfController: _pdfFor(i),
                                onTap: _onTap,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    if (_controls)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: _ControlBar(
                          item: items[_index],
                          onExit: () => Navigator.pop(context),
                          onOverview: _showOverview,
                          onAdjust: items[_index].song == null ? null : _adjust,
                          onSetKey: _setKey,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                color: theme.colorScheme.surfaceContainer,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
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
              .transpose(item.setTranspose)
              .format(ref.read(settingsProvider).notation);
    return '$title ($shown)';
  }
}

class _ControlBar extends ConsumerWidget {
  const _ControlBar({
    required this.item,
    required this.onExit,
    required this.onOverview,
    required this.onAdjust,
    required this.onSetKey,
  });

  final LiveItem item;
  final VoidCallback onExit;
  final VoidCallback onOverview;
  final Future<void> Function(SongOverlay Function(SongOverlay))? onAdjust;
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
    final originalKey = song?.songKey == null
        ? null
        : cp.Key.tryParse(song!.songKey!);
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
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
            const Spacer(),
            if (adjust != null) ...[
              KeyPicker(
                baseKey: originalKey,
                transpose: inSet ? item.setTranspose : overlay?.transpose ?? 0,
                notation: ref.watch(settingsProvider.select((s) => s.notation)),
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
                    fontScale: (o.fontScale - 0.1).clamp(0.5, 2.5),
                  ),
                ),
              ),
              IconButton(
                tooltip: l10n.fontLarger,
                icon: const Icon(Icons.text_increase),
                onPressed: () => adjust(
                  (o) => o.copyWith(
                    fontScale: (o.fontScale + 0.1).clamp(0.5, 2.5),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LiveItemPage extends ConsumerWidget {
  const _LiveItemPage({
    required this.item,
    required this.scrollController,
    required this.pdfController,
    required this.onTap,
  });

  final LiveItem item;
  final ScrollController scrollController;
  final PdfViewerController pdfController;

  /// Tap at a position of the page; the viewer of a PDF handles taps itself,
  /// so it forwards them to the tap zones of the live screen.
  final ValueChanged<Offset> onTap;

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

    AttachmentEntry? pdf;
    if (overlay.liveView != null) {
      pdf = attachments.where((a) => a.id == overlay.liveView).firstOrNull;
    }
    if (pdf == null && !parsed.hasContent) {
      pdf = attachments.where((a) => isPdfFile(a.fileName)).firstOrNull;
    }
    if (pdf != null && !isPdfFile(pdf.fileName)) pdf = null;
    if (pdf != null) {
      final file = ref.watch(attachmentStorageProvider).file(pdf.fileName);
      if (!file.existsSync()) {
        // Synced from the server but not downloaded yet (ADR-0009).
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              AppLocalizations.of(context).pdfMissing,
              key: const Key('pdf-missing'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        );
      }
      return PdfViewer.file(
        file.path,
        key: ValueKey(pdf.id),
        controller: pdfController,
        params: PdfViewerParams(
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
    }
    final storage = ref.watch(attachmentStorageProvider);
    return _ChordProPage(
      song: song,
      parsed: parsed,
      overlay: overlay,
      setTranspose: item.setTranspose,
      setSequence: item.setSequence,
      scrollController: scrollController,
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
    required this.song,
    required this.parsed,
    required this.overlay,
    required this.setTranspose,
    required this.setSequence,
    required this.scrollController,
    required this.attachments,
    required this.imageLookup,
  });

  final SongEntry song;
  final Song parsed;
  final SongOverlay overlay;
  final int setTranspose;
  final String? setSequence;
  final ScrollController scrollController;

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
              capo: formatter.effectiveCapo,
              compact: true,
              setSequence: setSequence,
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(
                  constraints.maxWidth - 2 * _margin,
                  constraints.maxHeight,
                );
                final scale = overlay.fontScale;
                if (!settings.autoFit) {
                  return _scrolling(
                    size,
                    _options(
                      formatter,
                      lyricsOnly,
                      settings.fontSize * scale,
                      settings.columns == ColumnMode.auto
                          ? 1
                          : settings.maxColumns,
                      settings.chorusRepeat == ChorusRepeat.label,
                      resolver,
                      diagrams,
                    ),
                  );
                }
                final songColumns =
                    settings.columns == ColumnMode.auto &&
                        parsed.columns != null
                    ? parsed.columns!.clamp(1, 4)
                    : null;
                final textScaler = MediaQuery.textScalerOf(context);
                final baseStyle = DefaultTextStyle.of(context).style;
                // Rebuilds (page changes, overlay events) reuse the fit:
                // fitting measures every line of the song.
                final fit = _fits.get(
                  (
                    parsed,
                    formatter.transpose,
                    formatter.capo,
                    formatter.notation,
                    formatter.nashville,
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
                    // By content: the list is loaded anew after the page
                    // was disposed.
                    [
                      for (final a in attachments)
                        '${a.id}/${a.name}/${a.fileName}',
                    ].join('\n'),
                    Localizations.localeOf(context),
                  ),
                  () => fitSong(
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
                  ),
                );
                final options = _options(
                  formatter,
                  lyricsOnly,
                  fit.fontSize * scale,
                  fit.columns,
                  fit.collapseRecalls,
                  resolver,
                  diagrams,
                  // Measured at the reference size: valid for any scale.
                  layout: fit.layout,
                );
                // A personal font scale above 100 % may need scrolling.
                if (!fit.fits || scale > 1.0) return _scrolling(size, options);
                // Fits: no scrolling. FittedBox only shrinks, as a safety net
                // for small measurement differences (e.g. wrapped notes).
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: _margin),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width: size.width,
                      child: SongBody(song: parsed, options: options),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
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

  Widget _scrolling(Size size, SongRenderOptions options) =>
      SingleChildScrollView(
        controller: scrollController,
        padding: EdgeInsets.fromLTRB(_margin, 0, _margin, size.height * 0.25),
        child: SongBody(song: parsed, options: options),
      );
}

/// Results of [fitSong] for the songs of live mode.
final _fits = LruCache<Object, SongFit>(16);

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
              item.label ?? '',
              textAlign: TextAlign.center,
              style: theme.textTheme.displaySmall,
            ),
          ],
        ),
      ),
    );
  }
}

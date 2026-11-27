import 'dart:math' as math;

import 'package:chordpro/chordpro.dart' hide Key;
import 'package:flutter/gestures.dart' show Drag;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/annotation.dart' show LayoutFingerprint, textHash;
import '../../data/database.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../settings/settings.dart';
import '../annotations/annotated_page.dart';
import '../annotations/annotation_editor.dart';
import '../render/line_marks.dart';
import '../render/song_header.dart';
import '../render/chord_diagram.dart';
import '../render/render_cache.dart';
import '../render/song_image.dart';
import '../render/song_view.dart';
import 'live_preparation.dart';
import 'live_beat.dart';
import 'song_map_view.dart';
import 'song_page_controller.dart';

/// A song shown as ChordPro in live mode (ADR-0007): the header, then the
/// song fitted to the page, split into pages or scrolling.
class LiveChordProPage extends ConsumerWidget {
  const LiveChordProPage({
    super.key,
    required this.index,
    required this.annotations,
    required this.shownSequence,
    required this.songMap,
    required this.song,
    required this.parsed,
    required this.chorusOnce,
    required this.hiddenParts,
    required this.dimSection,
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

  /// Drawing mode for freehand annotations (ADR-0032).
  final AnnotationEditor annotations;

  /// The sequence shown (set, band or song), empty for all parts: part of
  /// the layout annotations are drawn on.
  final String shownSequence;

  /// The song map instead of the song (drums, ADR-0026); null for the song.
  final List<SongMapEntry>? songMap;
  final SongEntry song;
  final Song parsed;

  /// Whether [parsed] leaves out choruses written out again (#955): part
  /// of the layout annotations are drawn on.
  final bool chorusOnce;

  /// Parts hidden because they are not in the set's sequence.
  final List<String> hiddenParts;

  /// Parts outside the set's sequence, shown dimmed; null for none.
  final bool Function(Section section)? dimSection;
  final SongOverlay overlay;

  /// Band arrangement and set item together (semitones to the song).
  final int setTranspose;
  final String? setSequence;
  final String? bandSequence;
  final int? bandTempo;
  final ScrollController scrollController;
  final LiveFitController fitController;
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
      view: overlay.chordView ?? settings.chordView,
      numeralSpelling: settings.numeralSpelling,
      style: settings.chordStyle,
      superscript: settings.chordSuperscript,
    );
    final lyricsOnly = settings.displayMode == DisplayMode.lyricsOnly;
    final resolver = DiagramResolver(
      parsed,
      formatter,
      diagramInstrumentFor(
        settings.instrument,
        bassStrings: settings.bassStrings,
      ),
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
                  final map = songMap;
                  if (map != null) {
                    songPageController.attach(1);
                    fitController.fontScale = null;
                    return SongMapView(
                      entries: map,
                      scale: scale,
                      controller: scrollController,
                      padding: EdgeInsets.fromLTRB(
                        _margin,
                        0,
                        _margin,
                        size.height * 0.25,
                      ),
                    );
                  }
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
                        maxFontSize: settings.fontSize * maxLiveFontScale,
                        minFontSize: settings.fontSize * minLiveFontScale,
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
                        display: settings.songDisplay,
                      );
                      return fit.fits
                          // A small margin for measurement differences, which
                          // the fitted view absorbs with a FittedBox.
                          ? fit.fontSize / settings.fontSize * 0.98
                          : minLiveFontScale;
                    };
                    // Several columns are measured to split the song; the
                    // measurement does not depend on the font size.
                    final layoutKey = (
                      parsed,
                      formatter.transpose,
                      formatter.capo,
                      formatter.notation,
                      formatter.view,
                      formatter.numeralSpelling,
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
                      settings.songDisplay,
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
                      display: settings.songDisplay,
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
                        settings.songDisplay,
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
                    formatter.view,
                    formatter.numeralSpelling,
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
                    settings.songDisplay,
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
                    display: settings.songDisplay,
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
                        settings.songDisplay,
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
                    settings.songDisplay,
                    layout: layout,
                  );
                  // Does not fit on pages (e.g. a section taller than the
                  // page at a large personal font scale): scrolling.
                  if (pages == null) {
                    songPageController.attach(1);
                    return _scrolling(size, options(fit.layout));
                  }
                  songPageController.attach(
                    pages.ends.length,
                    sections: _firstSections(fit.layout, pages.ends),
                  );
                  // All pages of the song are built (and prepared ahead),
                  // so turning a page of the song only shows another one.
                  // Fits: no scrolling. FittedBox only shrinks, as a safety
                  // net for small measurement differences (e.g. wrapped
                  // notes).
                  final layout = fit.layout;
                  final pageBodies = <Widget>[];
                  var firstLine = 0;
                  final font = fit.fontSize * scale;
                  final content = textHash(song.chordproSource);
                  final songLines = songLineMarks(parsed);
                  for (final (page, end) in pages.ends.indexed) {
                    final start = page == 0 ? 0 : pages.ends[page - 1];
                    final pageLayout = layout == null || pages.ends.length == 1
                        ? layout
                        : (
                            blocks: layout.blocks.sublist(start, end),
                            metrics: layout.metrics.sublist(start, end),
                          );
                    pageBodies.add(
                      // Freehand annotations of this page (ADR-0032).
                      AnnotatedPage(
                        key: ValueKey(('song-page-annotations', page)),
                        songId: song.id,
                        page: page,
                        layout: LayoutFingerprint(
                          mode: 'page',
                          pages: pages.ends.length,
                          width: size.width,
                          height: size.height,
                          font: font,
                          columns: pages.columns,
                          lyricsOnly: lyricsOnly,
                          verseChords: overlay.verseChords.name,
                          stackedChoruses: overlay.stackedChoruses,
                          chorusOnce: chorusOnce,
                          content: content,
                          sequence: shownSequence,
                        ),
                        font: font,
                        songLines: songLines,
                        editor: annotations,
                        hidden: overlay.hideAnnotations,
                        child: FittedBox(
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
    DiagramsPosition diagrams,
    SongDisplay display, {
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
    display: display,
    dimSection: dimSection,
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
        // Freehand annotations of the scrolled song (ADR-0032).
        child: AnnotatedPage(
          songId: song.id,
          page: 0,
          layout: LayoutFingerprint(
            mode: 'scroll',
            width: size.width,
            height: size.height,
            font: options.fontSize,
            columns: options.columns,
            lyricsOnly: options.lyricsOnly,
            verseChords: overlay.verseChords.name,
            stackedChoruses: overlay.stackedChoruses,
            chorusOnce: chorusOnce,
            content: textHash(song.chordproSource),
            sequence: shownSequence,
          ),
          font: options.fontSize,
          songLines: songLineMarks(parsed),
          editor: annotations,
          hidden: overlay.hideAnnotations,
          child: SongBody(
            song: parsed,
            options: options,
            progress: preparation.body,
          ),
        ),
      );
}

/// Results of [fitSong] for the songs of live mode.
final _fits = LruCache<Object, SongFit>(16);

/// Measured songs for scrolling with several columns.
final _layouts = LruCache<Object, SongLayout>(16);

/// Most pages a song is split into to fit it in live mode (ADR-0007).
const _maxSongPages = 4;

/// The source line of the first section on each page of a song split at
/// [ends] (block indices), for the lyrics projection (ADR-0068 §6).
List<int?> _firstSections(SongLayout? layout, List<int> ends) {
  final blocks = layout?.blocks;
  if (blocks == null) return const [];
  return [
    for (var page = 0; page < ends.length; page++)
      () {
        for (var b = page == 0 ? 0 : ends[page - 1]; b < ends[page]; b++) {
          if (blocks[b].shownSection case final section?) {
            return sourceLineOf(section);
          }
        }
        return null;
      }(),
  ];
}

/// Range of the personal font scale (ADR-0006).
const minLiveFontScale = 0.5;
const maxLiveFontScale = 2.5;

/// Lets the control bar fit the song of a page to the page.
class LiveFitController {
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

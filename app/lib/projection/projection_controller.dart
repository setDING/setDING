/// The lyrics projection of live mode (ADR-0068 §2, §5–8): which slide is
/// projected, following live mode or advanced by hand.
library;

import 'package:chordpro/chordpro.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/settings.dart';
import 'projection_server.dart';
import 'projection_state.dart';

/// Where the projection goes: the local web server, or a fake in tests.
abstract interface class ProjectionHost {
  bool get running;

  /// Starts serving [page]; a new token every time.
  Future<void> start(String page);
  Future<void> stop();
  void update(ProjectionState state);

  /// The links of the full-screen page, one per private address.
  Future<List<Uri>> urls();
}

/// [ProjectionHost] on the local web server (ADR-0068 §1).
class ServerProjectionHost implements ProjectionHost {
  ProjectionServer? _server;

  @override
  bool get running => _server?.running ?? false;

  @override
  Future<void> start(String page) async {
    await stop();
    final server = ProjectionServer(page: page);
    await server.start();
    _server = server;
  }

  @override
  Future<void> stop() async {
    final server = _server;
    _server = null;
    await server?.stop();
  }

  @override
  void update(ProjectionState state) => _server?.update(state);

  @override
  Future<List<Uri>> urls() async => await _server?.urls() ?? const [];
}

/// Whether this platform can project (native apps, not the web client).
final projectionSupportedProvider = Provider<bool>(
  (ref) => ProjectionServer.supported,
);

/// Makes the host of a projection; overridden in tests.
final projectionHostProvider = Provider<ProjectionHost Function()>(
  (ref) => ServerProjectionHost.new,
);

/// What live mode shows: a song or a set marker.
sealed class ProjectionItem {
  const ProjectionItem();
}

/// A song with the sequence the band plays (set item, band arrangement or
/// `{x_sequence}`, as in live mode) and optionally a linked language
/// version with its own sequence (ADR-0068 §9).
class ProjectionSong extends ProjectionItem {
  const ProjectionSong(
    this.song, {
    this.sequence = const [],
    this.title,
    this.second,
    this.secondSequence = const [],
  });

  final Song song;
  final List<SequenceItem> sequence;

  /// The title shown in the browser's tab; the song's own when null.
  final String? title;
  final Song? second;
  final List<SequenceItem> secondSequence;
}

/// A set marker (ADR-0047): blank, or its text (ADR-0068 §7).
class ProjectionMarker extends ProjectionItem {
  const ProjectionMarker(this.text);
  final String text;
}

/// The projection settings (ADR-0068 §11).
class ProjectionOptions {
  const ProjectionOptions({
    this.linesPerSlide = 8,
    this.markersAsText = false,
    this.preview = false,
    this.copyright = ProjectionCopyright.everySlide,
    this.style = const ProjectionStyle(),
  });

  /// The options of the device settings.
  factory ProjectionOptions.of(AppSettings s) => ProjectionOptions(
    linesPerSlide: s.projectionLines,
    markersAsText: s.projectionMarkersAsText,
    preview: s.projectionPreview,
    copyright: s.projectionCopyright,
    style: ProjectionStyle(
      theme: s.projectionTheme,
      font: s.projectionFont,
      align: s.projectionAlign,
    ),
  );

  /// On every slide of a song, or on its first and last one only.
  final ProjectionCopyright copyright;

  final int linesPerSlide;
  final bool markersAsText;

  /// The next slide below the current one (a confidence monitor).
  final bool preview;
  final ProjectionStyle style;
}

/// The projection while live mode is open.
///
/// Live mode tells it what it shows ([show], [followSection]); the
/// projection bar advances it by hand ([next], [previous]), which makes the
/// song manual until the next one ([follow] turns that off again).
class ProjectionController extends ChangeNotifier {
  ProjectionController(
    this._host, {
    ProjectionOptions options = const ProjectionOptions(),
  }) : _options = options; // ignore: prefer_initializing_formals

  final ProjectionHost _host;
  ProjectionOptions _options;

  ProjectionItem? _item;
  List<LyricSlide> _slides = const [];
  int _slide = 0;
  bool _blank = false;
  bool _manual = false;
  bool _starting = false;
  int? _followedLine;

  /// Whether the projection is on.
  bool get running => _host.running;

  /// Whether a start is under way.
  bool get starting => _starting;

  /// The black screen, until switched off again.
  bool get blank => _blank;

  /// Whether the current song is advanced by hand (ADR-0068 §6).
  bool get manual => _manual;

  /// The slides of the current song; empty for a marker or no lyrics.
  List<LyricSlide> get slides => _slides;

  /// The slide shown, 0-based.
  int get slide => _slide;

  bool get canPrevious => _slide > 0;
  bool get canNext => _slide + 1 < _slides.length;

  /// A song without `{copyright}` is projected without one; the bar shows
  /// a hint (ADR-0068 §8).
  bool get missingCopyright => switch (_item) {
    ProjectionSong(:final song) =>
      _slides.isNotEmpty && (song.copyright?.trim().isEmpty ?? true),
    _ => false,
  };

  ProjectionOptions get options => _options;
  set options(ProjectionOptions value) {
    _options = value;
    _build();
    _send();
  }

  /// Starts the server with [page] and shows the current item.
  Future<void> start(String page) async {
    if (_starting) return;
    _starting = true;
    notifyListeners();
    try {
      await _host.start(page);
      _send();
    } finally {
      _starting = false;
      notifyListeners();
    }
  }

  Future<void> stop() async {
    await _host.stop();
    _blank = false;
    notifyListeners();
  }

  Future<List<Uri>> urls() => _host.urls();

  /// Live mode shows [item] (null: nothing to project): its first slide,
  /// following live mode again.
  void show(ProjectionItem? item) {
    _item = item;
    _slide = 0;
    _manual = false;
    _followedLine = null;
    _build();
    _send();
  }

  /// Adds the linked language version [second] of [song] to the song on
  /// stage (ADR-0068 §9), found after it was shown; the slide and whether
  /// the song is manual stay. Ignored when another item is shown by now.
  void pairWith(
    Song song,
    Song second, {
    List<SequenceItem> sequence = const [],
  }) {
    final item = _item;
    if (item is! ProjectionSong || !identical(item.song, song)) return;
    _item = ProjectionSong(
      item.song,
      sequence: item.sequence,
      title: item.title,
      second: second,
      secondSequence: sequence,
    );
    _build();
    _send();
  }

  /// Live mode shows the section starting at [sourceLine] at the top of its
  /// page; the projection goes to its first slide unless the song is
  /// manual. A section played more than once is found after the current
  /// slide first.
  void followSection(int? sourceLine) {
    _followedLine = sourceLine;
    if (_manual || sourceLine == null || _slides.isEmpty) return;
    final target = _slideOf(sourceLine);
    if (target == null || target == _slide) return;
    _slide = target;
    _send();
  }

  int? _slideOf(int line) {
    bool matches(LyricSlide s) =>
        s.page == 0 && sourceLineOf(s.source.section) == line;
    for (var i = _slide; i < _slides.length; i++) {
      if (matches(_slides[i])) return i;
    }
    for (var i = 0; i < _slide; i++) {
      if (matches(_slides[i])) return i;
    }
    return null;
  }

  void next() {
    if (!canNext) return;
    _slide++;
    _manual = true;
    _send();
  }

  void previous() {
    if (!canPrevious) return;
    _slide--;
    _manual = true;
    _send();
  }

  /// Follows live mode again, at the section it shows now.
  void follow() {
    if (!_manual) return;
    _manual = false;
    final line = _followedLine;
    if (line != null) {
      final target = _slideOf(line);
      if (target != null) _slide = target;
    }
    _send();
  }

  void toggleBlank() {
    _blank = !_blank;
    _send();
  }

  void _build() {
    final item = _item;
    if (item is! ProjectionSong) {
      _slides = const [];
      return;
    }
    final sections = lyricSections(item.song, sequence: item.sequence);
    final second = item.second;
    _slides = lyricSlides(
      sections,
      linesPerSlide: _options.linesPerSlide,
      second: second == null
          ? null
          : lyricSections(second, sequence: item.secondSequence),
    );
    if (_slide >= _slides.length) _slide = 0;
  }

  /// The state for the browsers.
  @visibleForTesting
  ProjectionState get state {
    final style = _options.style;
    final item = _item;
    if (_blank || item == null) return ProjectionState.blank(style: style);
    switch (item) {
      case ProjectionMarker(:final text):
        return _options.markersAsText && text.trim().isNotEmpty
            ? ProjectionState.marker(text, style: style)
            : ProjectionState.blank(style: style);
      case ProjectionSong(:final song, :final title):
        if (_slides.isEmpty) return ProjectionState.blank(style: style);
        final text = song.copyright?.trim();
        final edge = _slide == 0 || _slide == _slides.length - 1;
        final copyright =
            text == null ||
                text.isEmpty ||
                (_options.copyright == ProjectionCopyright.firstAndLast &&
                    !edge)
            ? null
            : text;
        return ProjectionState.slide(
          _slides[_slide],
          title: title ?? song.title,
          copyright: copyright,
          next: _options.preview && canNext ? _slides[_slide + 1] : null,
          style: style,
        );
    }
  }

  void _send() {
    if (_host.running) _host.update(state);
    notifyListeners();
  }

  @override
  void dispose() {
    _host.stop();
    super.dispose();
  }
}

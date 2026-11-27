import 'package:chordpro/chordpro.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:material_ui/material_ui.dart';

import '../../data/database.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../projection/projection_controller.dart';
import '../../projection/projection_page.dart';
import '../../settings/settings.dart';
import '../render/song_view.dart';
import 'live_item.dart';
import 'song_page_controller.dart';

/// The lyrics projection of live mode (ADR-0068): starts it, tells it what
/// live mode shows and lets page turns move its slides (#1181). Tells its
/// listeners whenever the projection changes.
class LiveProjection extends ChangeNotifier {
  LiveProjection({
    required this._host,
    required this.items,
    required this._settings,
    required this._l10n,
    required this._token,
    required this._renewToken,
    required this._languageVersions,
    required this._parse,
    required this._section,
    Future<String> Function()? template,
  }) : // Small, read once per start: not kept in the asset cache.
       _template =
           template ??
           (() => rootBundle.loadString(projectionPageAsset, cache: false));

  /// The items of live mode as shown.
  final List<LiveItem> items;
  final ProjectionHost Function() _host;
  final AppSettings Function() _settings;
  final AppLocalizations Function() _l10n;

  /// The address of this device (#1183), and a new one.
  final String Function() _token;
  final String Function() _renewToken;
  final Future<List<SongEntry>> Function(String songId) _languageVersions;
  final Song Function(String chordpro) _parse;

  /// The source line of the first section on the shown page of item
  /// [index] (ADR-0068 §6).
  final int? Function(int index) _section;
  final Future<String> Function() _template;

  ProjectionController? _controller;
  bool _disposed = false;

  /// The projection; null until it is started.
  ProjectionController? get controller => _controller;

  /// Whether the projection is on.
  bool get running => _controller?.running ?? false;

  /// Starts the projection; throws when it cannot start. [lang] is the
  /// language of the full-screen page.
  Future<void> start({required String lang}) async {
    final l10n = _l10n();
    final projection = _controller ??= ProjectionController(
      _host(),
      options: ProjectionOptions.of(_settings()),
      // Sections without a label get the name of their kind (#1185).
      labeler: sectionLabeler(l10n),
    )..addListener(notifyListeners);
    final template = await _template();
    await projection.start(
      projectionPage(
        template,
        lang: lang,
        fullScreen: l10n.projectionFullScreen,
      ),
      // The same address at every start (#1183).
      token: _token(),
    );
  }

  /// A new address for this device (#1183); the running projection moves
  /// to it.
  Future<void> renew() async {
    await _controller?.renew(_renewToken());
  }

  /// Tells the projection what live mode shows now (ADR-0068 §6), and
  /// adds the song's version in the second language once it is found
  /// (§9).
  void show(int index) {
    final projection = _controller;
    if (projection == null || !projection.running) return;
    final item = _projectionItem(items[index]);
    projection
      ..show(item)
      ..followSection(_section(index));
    final song = items[index].song;
    final language = _settings().projectionSecondLanguage;
    if (item is! ProjectionSong ||
        song == null ||
        language.isEmpty ||
        song.language == language) {
      return;
    }
    _languageVersions(song.id).then((versions) {
      final version = versions.where((v) => v.language == language).firstOrNull;
      if (version == null || _disposed) return;
      final second = _parse(version.chordproSource);
      // Paired by position in its own played order (ADR-0068 §9).
      projection.pairWith(
        item.song,
        second,
        sequence: parseSequence(second.metaValue('x_sequence') ?? ''),
      );
    });
  }

  /// Live mode turned to item [index]; turning [back] into a song whose
  /// slides the turns move ends at its last slide (#1181).
  void itemShown(int index, {required bool back}) {
    show(index);
    if (back && _settings().projectionTurnsSlides) _controller?.toLast();
  }

  /// The projection settings changed (ADR-0068 §11): the look at once, a
  /// different second language with the item [index] on stage.
  void settingsChanged(AppSettings? previous, AppSettings next, int index) {
    final projection = _controller;
    if (projection == null) return;
    projection.options = ProjectionOptions.of(next);
    if (previous?.projectionSecondLanguage != next.projectionSecondLanguage) {
      show(index);
    }
  }

  /// The page of the song on stage changed: the projection follows the
  /// section at its top.
  void followSection(int? sourceLine) => _controller?.followSection(sourceLine);

  /// With *Turning pages moves the slides* (#1181), a turn while projecting
  /// moves the projected slide first; true when it did. Live mode shows the
  /// page of the slide's section in [pages].
  bool turnSlide({required bool forward, SongPageController? pages}) {
    final projection = _controller;
    if (projection == null ||
        !_settings().projectionTurnsSlides ||
        !projection.turn(forward: forward)) {
      return false;
    }
    final line = projection.sectionLine;
    if (pages != null && line != null) {
      if (pages.pageOf(line) case final page?) pages.show(page);
    }
    return true;
  }

  ProjectionItem? _projectionItem(LiveItem item) {
    final song = item.song;
    if (song == null) return ProjectionMarker(item.title(_l10n()));
    final parsed = _parse(song.chordproSource);
    // The sequence as in live mode: set item, band arrangement, song.
    final sequence =
        item.setSequence ??
        item.arrangement?.sequence ??
        parsed.metaValue('x_sequence');
    return ProjectionSong(
      parsed,
      sequence: parseSequence(sequence ?? ''),
      title: item.title(_l10n()),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _controller
      ?..removeListener(notifyListeners)
      ..dispose();
    super.dispose();
  }
}

import 'package:chordpro/chordpro.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../sync/auth_providers.dart' show authProvider;
import '../sync/sync_backend.dart' show defaultServerUrl;
import '../data/database.dart' show localOwnerId;
import 'display_options.dart';
import 'song_display.dart';
import 'user_settings_store.dart';

export 'display_options.dart';
export 'song_display.dart';
export 'user_settings_store.dart';

/// UI language setting (ADR-0008).
enum LanguageMode { system, de, en }

/// What is shown of a song.
enum DisplayMode { lyricsAndChords, lyricsOnly }

/// Number of columns in live mode. When fitting to the screen this is the
/// maximum; `auto` allows up to four columns.
enum ColumnMode { auto, one, two, three }

/// How far a page turn moves.
enum PageTurnMode { full, half }

/// Appearance of live mode on stage, independent of the app theme
/// (ADR-0007).
enum LiveAppearance {
  /// As the app theme (light or dark).
  app,

  /// Dark, also when the app is light.
  dark,

  /// True black background, e.g. for OLED screens.
  black,
}

/// Accent colour of the app (issue #300): a curated set of seeds that each
/// give a light and a dark colour scheme as calm and readable as the brand
/// blue; the colours are defined in `ui/theme.dart`. [red] is the colour of
/// the former RealChord logo.
enum AccentColor { brand, red, amber, green, teal, purple, pink }

/// When the beat and the click start in live mode (ADR-0026).
enum ClickStart {
  /// With a count-in whenever a song is shown.
  automatic,

  /// By a tap on the tempo, a long press of the forward pedal or Enter.
  manual,
}

/// How long the click plays (ADR-0026).
enum ClickDuration { wholeSong, countIn }

/// What the beat and the click do when the app goes to the background
/// (minimised, another app opened, the screen locked; ADR-0026, #424).
enum ClickInBackground {
  /// They stop; the beat is started again by hand.
  stop,

  /// They keep playing (e.g. to look at another app during a song).
  keepPlaying,
}

/// Sound of the click (ADR-0026), synthesised by the click engine.
enum ClickSound { click, woodblock, beep }

/// When syncs start (ADR-0004); "Sync now" is always available.
enum SyncMode {
  /// At start, after local changes, on server changes and periodically.
  automatic,

  /// Once at start and after signing in.
  onStart,

  /// Only with "Sync now".
  manual,
}

/// Whether a setting follows the person or stays on the device (ADR-0027).
enum SettingSyncScope {
  /// Synced with the account: the same on all devices of a person.
  personal,

  /// Never synced: depends on the screen, audio output or network.
  device,
}

/// The settings (layer 4, ADR-0006): personal settings of the current
/// person (synced with the account, ADR-0027) combined with the settings of
/// this device. See [scopes].
@immutable
class AppSettings {
  const AppSettings({
    this.language = LanguageMode.system,
    this.notation = ChordNotation.international,
    this.nashville = false,
    this.chordStyle = ChordStyle.asWritten,
    this.chordSuperscript = false,
    this.displayMode = DisplayMode.lyricsAndChords,
    this.themeMode = ThemeMode.system,
    this.accent = AccentColor.brand,
    this.columns = ColumnMode.auto,
    this.pageTurn = PageTurnMode.full,
    this.liveAppearance = LiveAppearance.app,
    this.autoFit = true,
    this.setProgress = true,
    this.chorusRepeat = ChorusRepeat.auto,
    this.fontSize = 20,
    this.instrument = 'guitar',
    this.userName = '',
    this.diagrams = DiagramsPosition.off,
    this.serverUrl = defaultServerUrl,
    this.syncMode = SyncMode.onStart,
    this.beatDisplay,
    this.edgeFlash,
    this.click,
    this.clickStart,
    this.clickDuration = ClickDuration.wholeSong,
    this.clickInBackground = ClickInBackground.stop,
    this.countInBars = 2,
    this.clickVolume = 0.8,
    this.clickAccent = true,
    this.clickSound = ClickSound.click,
    this.clickSubdivision = false,
    this.audioLatencyMs = 0,
    this.songMap,
    this.showAnnotations = true,
    this.showOutsideSequence = true,
    this.annotationFinger = false,
    this.songDisplay = SongDisplay.classic,
    this.developerMode = false,
  });

  final LanguageMode language;
  final ChordNotation notation;
  final bool nashville;

  /// Spelling of chord suffixes (ADR-0022).
  final ChordStyle chordStyle;

  /// Extensions and modifiers raised (ADR-0022).
  final bool chordSuperscript;
  final DisplayMode displayMode;
  final ThemeMode themeMode;

  /// Accent colour of the app theme and of live mode.
  final AccentColor accent;
  final ColumnMode columns;
  final PageTurnMode pageTurn;

  /// Stage appearance of live mode.
  final LiveAppearance liveAppearance;

  /// Fit the whole song on the screen (no scrolling) in live mode.
  final bool autoFit;

  /// A progress bar of the set in live mode: the items of the set and the
  /// pages of the current song (ADR-0007).
  final bool setProgress;
  final ChorusRepeat chorusRepeat;

  /// Base font size for lyrics in logical pixels.
  final double fontSize;

  /// Instrument type for conditional directives and chord diagrams
  /// (ADR-0012), e.g. `guitar`, `ukulele` or a free text.
  final String instrument;

  /// User name for conditional directives (e.g. a voice like `alto`).
  final String userName;

  /// Chord diagrams of all chords of a song (ADR-0012).
  final DiagramsPosition diagrams;

  /// setDING server for accounts and sync (ADR-0004); changeable for a
  /// local test server (`make backend`).
  final String serverUrl;

  /// When syncs start.
  final SyncMode syncMode;

  // Beat and click (ADR-0026). The nullable ones follow the instrument
  // until they are set: on for drums, off for the others.

  /// Beat dots in the live header and the count-in numbers.
  final bool? beatDisplay;

  /// The edge of the screen flashes on each beat (drums only).
  final bool? edgeFlash;

  /// Audible click.
  final bool? click;

  /// Automatic or manual start.
  final ClickStart? clickStart;
  final ClickDuration clickDuration;
  final ClickInBackground clickInBackground;

  /// Bars of the count-in: 0 (none), 1 or 2.
  final int countInBars;

  /// Volume of the click, 0 to 1.
  final double clickVolume;

  /// The 1 of a bar sounds different.
  final bool clickAccent;
  final ClickSound clickSound;

  /// Quieter clicks between the beats.
  final bool clickSubdivision;

  /// Delay of the audio output (e.g. Bluetooth headphones); the display is
  /// shifted by it so that it matches what is heard.
  final int audioLatencyMs;

  /// Song map instead of the chord sheet (drums only).
  final bool? songMap;

  /// Personal freehand annotations are shown (ADR-0032).
  final bool showAnnotations;

  /// In live mode, the parts outside the song sequence are
  /// shown dimmed instead of hidden (ADR-0007).
  final bool showOutsideSequence;

  /// Fingers draw annotations too, not only a stylus or a mouse; for
  /// devices without a stylus (ADR-0032).
  final bool annotationFinger;

  /// Shows the *Development* settings category with experimental and test
  /// features, e.g. the MIDI test; off for normal users (#559).
  final bool developerMode;

  /// Styles of the song display per section type (ADR-0033).
  final SongDisplay songDisplay;

  static const maxAudioLatencyMs = 500;

  /// Whether the instrument is drums (ADR-0026).
  bool get isDrums => instrument.trim().toLowerCase() == 'drums';

  bool get showBeat => beatDisplay ?? isDrums;
  bool get showEdgeFlash => isDrums && (edgeFlash ?? true);
  bool get playClick => click ?? isDrums;
  ClickStart get beatStart =>
      clickStart ?? (isDrums ? ClickStart.automatic : ClickStart.manual);
  bool get showSongMap => isDrums && (songMap ?? true);

  /// Whether live mode has a beat at all (display or click).
  bool get beatEnabled => showBeat || playClick || showEdgeFlash;

  /// Instrument presets offered in the settings.
  static const instruments = [
    'guitar',
    'ukulele',
    'bass',
    'keyboard',
    'vocals',
    'drums',
  ];

  /// Selection context for conditional ChordPro directives.
  SelectorContext get selectors => SelectorContext(
    instrument: instrument.trim().isEmpty ? null : instrument.trim(),
    user: userName.trim().isEmpty ? null : userName.trim(),
  );

  static const minFontSize = 12.0;
  static const maxFontSize = 40.0;

  /// The locale to use, or null to follow the system.
  /// Highest column count allowed in live mode.
  int get maxColumns => switch (columns) {
    ColumnMode.auto => 4,
    ColumnMode.one => 1,
    ColumnMode.two => 2,
    ColumnMode.three => 3,
  };

  Locale? get locale => switch (language) {
    LanguageMode.system => null,
    LanguageMode.de => const Locale('de', 'CH'),
    LanguageMode.en => const Locale('en'),
  };

  AppSettings copyWith({
    LanguageMode? language,
    ChordNotation? notation,
    bool? nashville,
    ChordStyle? chordStyle,
    bool? chordSuperscript,
    DisplayMode? displayMode,
    ThemeMode? themeMode,
    AccentColor? accent,
    ColumnMode? columns,
    PageTurnMode? pageTurn,
    LiveAppearance? liveAppearance,
    bool? autoFit,
    bool? setProgress,
    ChorusRepeat? chorusRepeat,
    double? fontSize,
    String? instrument,
    String? userName,
    DiagramsPosition? diagrams,
    String? serverUrl,
    SyncMode? syncMode,
    bool? beatDisplay,
    bool? edgeFlash,
    bool? click,
    ClickStart? clickStart,
    ClickDuration? clickDuration,
    ClickInBackground? clickInBackground,
    int? countInBars,
    double? clickVolume,
    bool? clickAccent,
    ClickSound? clickSound,
    bool? clickSubdivision,
    int? audioLatencyMs,
    bool? songMap,
    bool? showAnnotations,
    bool? showOutsideSequence,
    bool? annotationFinger,
    SongDisplay? songDisplay,
    bool? developerMode,
  }) => AppSettings(
    language: language ?? this.language,
    notation: notation ?? this.notation,
    nashville: nashville ?? this.nashville,
    chordStyle: chordStyle ?? this.chordStyle,
    chordSuperscript: chordSuperscript ?? this.chordSuperscript,
    displayMode: displayMode ?? this.displayMode,
    themeMode: themeMode ?? this.themeMode,
    accent: accent ?? this.accent,
    columns: columns ?? this.columns,
    pageTurn: pageTurn ?? this.pageTurn,
    liveAppearance: liveAppearance ?? this.liveAppearance,
    autoFit: autoFit ?? this.autoFit,
    setProgress: setProgress ?? this.setProgress,
    chorusRepeat: chorusRepeat ?? this.chorusRepeat,
    instrument: instrument ?? this.instrument,
    userName: userName ?? this.userName,
    diagrams: diagrams ?? this.diagrams,
    fontSize: fontSize ?? this.fontSize,
    serverUrl: serverUrl ?? this.serverUrl,
    syncMode: syncMode ?? this.syncMode,
    beatDisplay: beatDisplay ?? this.beatDisplay,
    edgeFlash: edgeFlash ?? this.edgeFlash,
    click: click ?? this.click,
    clickStart: clickStart ?? this.clickStart,
    clickDuration: clickDuration ?? this.clickDuration,
    clickInBackground: clickInBackground ?? this.clickInBackground,
    countInBars: countInBars ?? this.countInBars,
    clickVolume: clickVolume ?? this.clickVolume,
    clickAccent: clickAccent ?? this.clickAccent,
    clickSound: clickSound ?? this.clickSound,
    clickSubdivision: clickSubdivision ?? this.clickSubdivision,
    audioLatencyMs: audioLatencyMs ?? this.audioLatencyMs,
    songMap: songMap ?? this.songMap,
    showAnnotations: showAnnotations ?? this.showAnnotations,
    showOutsideSequence: showOutsideSequence ?? this.showOutsideSequence,
    annotationFinger: annotationFinger ?? this.annotationFinger,
    songDisplay: songDisplay ?? this.songDisplay,
    developerMode: developerMode ?? this.developerMode,
  );

  /// Which settings follow the person (synced with the account) and which
  /// stay on the device (ADR-0027). Every key of [toJson] has a scope; a
  /// test checks that a new setting gets one.
  static const scopes = <String, SettingSyncScope>{
    'language': SettingSyncScope.personal,
    'notation': SettingSyncScope.personal,
    'nashville': SettingSyncScope.personal,
    'chordStyle': SettingSyncScope.personal,
    'chordSuperscript': SettingSyncScope.personal,
    'displayMode': SettingSyncScope.personal,
    'themeMode': SettingSyncScope.personal,
    'accent': SettingSyncScope.personal,
    'setProgress': SettingSyncScope.personal,
    'chorusRepeat': SettingSyncScope.personal,
    'instrument': SettingSyncScope.personal,
    'userName': SettingSyncScope.personal,
    'diagrams': SettingSyncScope.personal,
    'columns': SettingSyncScope.device,
    'pageTurn': SettingSyncScope.device,
    'liveAppearance': SettingSyncScope.device,
    'autoFit': SettingSyncScope.device,
    'fontSize': SettingSyncScope.device,
    'serverUrl': SettingSyncScope.device,
    'syncMode': SettingSyncScope.device,
    // Beat and click (ADR-0026): how the person likes to play; the volume
    // and the audio delay depend on the device and its headphones.
    'beatDisplay': SettingSyncScope.personal,
    'edgeFlash': SettingSyncScope.personal,
    'click': SettingSyncScope.personal,
    'clickStart': SettingSyncScope.personal,
    'clickDuration': SettingSyncScope.personal,
    'clickInBackground': SettingSyncScope.personal,
    'countInBars': SettingSyncScope.personal,
    'clickAccent': SettingSyncScope.personal,
    'clickSound': SettingSyncScope.personal,
    'clickSubdivision': SettingSyncScope.personal,
    'songMap': SettingSyncScope.personal,
    'clickVolume': SettingSyncScope.device,
    'audioLatencyMs': SettingSyncScope.device,
    // Freehand annotations (ADR-0032): whether to see them follows the
    // person; drawing with a finger depends on the device having a stylus.
    'showAnnotations': SettingSyncScope.personal,
    'annotationFinger': SettingSyncScope.device,
    // Parts outside the sequence (ADR-0007): a reading habit of the person.
    'showOutsideSequence': SettingSyncScope.personal,
    // Song display styles (ADR-0033): a reading habit of the person.
    'songDisplay': SettingSyncScope.personal,
    // Developer mode (#559): a choice of the person, on every device.
    'developerMode': SettingSyncScope.personal,
  };

  /// The keys of [scope].
  static Iterable<String> keysOf(SettingSyncScope scope) =>
      scopes.entries.where((e) => e.value == scope).map((e) => e.key);

  /// The settings as JSON values (enums by name), keyed as stored.
  Map<String, Object> toJson() => {
    'language': language.name,
    'notation': notation.name,
    'nashville': nashville,
    'chordStyle': chordStyle.name,
    'chordSuperscript': chordSuperscript,
    'displayMode': displayMode.name,
    'themeMode': themeMode.name,
    'accent': accent.name,
    'columns': columns.name,
    'pageTurn': pageTurn.name,
    'liveAppearance': liveAppearance.name,
    'autoFit': autoFit,
    'setProgress': setProgress,
    'chorusRepeat': chorusRepeat.name,
    'instrument': instrument,
    'userName': userName,
    'diagrams': diagrams.name,
    'fontSize': fontSize,
    'serverUrl': serverUrl,
    'syncMode': syncMode.name,
    // Unset choices that follow the instrument are left out.
    'beatDisplay': ?beatDisplay,
    'edgeFlash': ?edgeFlash,
    'click': ?click,
    'clickStart': ?clickStart?.name,
    'clickDuration': clickDuration.name,
    'clickInBackground': clickInBackground.name,
    'countInBars': countInBars,
    'clickVolume': clickVolume,
    'clickAccent': clickAccent,
    'clickSound': clickSound.name,
    'clickSubdivision': clickSubdivision,
    'audioLatencyMs': audioLatencyMs,
    'songMap': ?songMap,
    'showAnnotations': showAnnotations,
    'showOutsideSequence': showOutsideSequence,
    'annotationFinger': annotationFinger,
    'songDisplay': songDisplay.toJsonString(),
    'developerMode': developerMode,
  };

  /// Settings from JSON values; a missing key, a value of the wrong type or
  /// an unknown value (e.g. from a newer app version) gives the default.
  static AppSettings fromJson(Map<String, Object?> json) {
    T pick<T extends Enum>(List<T> values, String key, T fallback) {
      final name = json[key];
      return values.firstWhere((v) => v.name == name, orElse: () => fallback);
    }

    bool flag(String key, bool fallback) => switch (json[key]) {
      final bool b => b,
      _ => fallback,
    };
    String text(String key, String fallback) => switch (json[key]) {
      final String v => v,
      _ => fallback,
    };
    bool? maybe(String key) => switch (json[key]) {
      final bool b => b,
      _ => null,
    };
    T? pickOrNull<T extends Enum>(List<T> values, String key) {
      for (final v in values) {
        if (v.name == json[key]) return v;
      }
      return null;
    }

    num? number(String key) => switch (json[key]) {
      final num v => v,
      _ => null,
    };

    const d = AppSettings();
    return AppSettings(
      language: pick(LanguageMode.values, 'language', d.language),
      notation: pick(ChordNotation.values, 'notation', d.notation),
      nashville: flag('nashville', d.nashville),
      chordStyle: pick(ChordStyle.values, 'chordStyle', d.chordStyle),
      chordSuperscript: flag('chordSuperscript', d.chordSuperscript),
      displayMode: pick(DisplayMode.values, 'displayMode', d.displayMode),
      themeMode: pick(ThemeMode.values, 'themeMode', d.themeMode),
      accent: pick(AccentColor.values, 'accent', d.accent),
      columns: pick(ColumnMode.values, 'columns', d.columns),
      pageTurn: pick(PageTurnMode.values, 'pageTurn', d.pageTurn),
      liveAppearance: pick(
        LiveAppearance.values,
        'liveAppearance',
        d.liveAppearance,
      ),
      autoFit: flag('autoFit', d.autoFit),
      setProgress: flag('setProgress', d.setProgress),
      chorusRepeat: pick(ChorusRepeat.values, 'chorusRepeat', d.chorusRepeat),
      instrument: text('instrument', d.instrument),
      userName: text('userName', d.userName),
      diagrams: pick(DiagramsPosition.values, 'diagrams', d.diagrams),
      serverUrl: text('serverUrl', d.serverUrl),
      syncMode: pick(SyncMode.values, 'syncMode', d.syncMode),
      fontSize: switch (json['fontSize']) {
        final num v => v.toDouble().clamp(minFontSize, maxFontSize),
        _ => d.fontSize,
      },
      beatDisplay: maybe('beatDisplay'),
      edgeFlash: maybe('edgeFlash'),
      click: maybe('click'),
      clickStart: pickOrNull(ClickStart.values, 'clickStart'),
      clickDuration: pick(
        ClickDuration.values,
        'clickDuration',
        d.clickDuration,
      ),
      clickInBackground: pick(
        ClickInBackground.values,
        'clickInBackground',
        d.clickInBackground,
      ),
      countInBars: (number('countInBars')?.toInt() ?? d.countInBars).clamp(
        0,
        2,
      ),
      clickVolume: (number('clickVolume')?.toDouble() ?? d.clickVolume).clamp(
        0.0,
        1.0,
      ),
      clickAccent: flag('clickAccent', d.clickAccent),
      clickSound: pick(ClickSound.values, 'clickSound', d.clickSound),
      clickSubdivision: flag('clickSubdivision', d.clickSubdivision),
      audioLatencyMs: (number('audioLatencyMs')?.toInt() ?? d.audioLatencyMs)
          .clamp(0, maxAudioLatencyMs),
      songMap: maybe('songMap'),
      showAnnotations: flag('showAnnotations', d.showAnnotations),
      showOutsideSequence: flag('showOutsideSequence', d.showOutsideSequence),
      annotationFinger: flag('annotationFinger', d.annotationFinger),
      developerMode: flag('developerMode', d.developerMode),
      songDisplay: switch (json['songDisplay']) {
        final String v => SongDisplay.fromJsonString(v),
        _ => d.songDisplay,
      },
    );
  }

  /// The values of [keys] stored in [prefs] (flat keys, as before
  /// ADR-0027); missing keys are left out.
  static Map<String, Object> readPrefs(
    SharedPreferences prefs,
    Iterable<String> keys,
  ) => {
    for (final key in keys)
      if (prefs.get(key) case final Object value) key: value,
  };

  /// Stores [values] as flat keys in [prefs].
  static Future<void> writePrefs(
    SharedPreferences prefs,
    Map<String, Object?> values,
  ) async {
    for (final MapEntry(:key, :value) in values.entries) {
      switch (value) {
        case final bool v:
          await prefs.setBool(key, v);
        case final int v:
          await prefs.setInt(key, v);
        case final double v:
          await prefs.setDouble(key, v);
        case final String v:
          await prefs.setString(key, v);
        case null:
          await prefs.remove(key);
      }
    }
  }
}

/// Resolves the UI locale: German or English, falling back to English
/// for other system languages (ADR-0008).
Locale resolveLocale(Locale? setting, List<Locale> systemLocales) {
  if (setting != null) return setting;
  for (final l in systemLocales) {
    if (l.languageCode == 'de') return const Locale('de', 'CH');
    if (l.languageCode == 'en') return const Locale('en');
  }
  return const Locale('en');
}

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('Overridden in main()'),
);

/// The server URL (a device setting). Separate from [settingsProvider]:
/// the backend depends on it, and the personal settings depend on the
/// signed-in user from that backend.
class ServerUrlNotifier extends Notifier<String> {
  @override
  String build() =>
      ref.watch(sharedPreferencesProvider).getString('serverUrl') ??
      initialServerUrl();

  Future<void> set(String url) async {
    state = url;
    await ref.read(sharedPreferencesProvider).setString('serverUrl', url);
  }
}

final serverUrlProvider = NotifierProvider<ServerUrlNotifier, String>(
  ServerUrlNotifier.new,
);

/// The owner of the personal settings (ADR-0027): the signed-in user, or
/// [localOwnerId] while signed out.
final settingsOwnerProvider = Provider<String>(
  (ref) => ref.watch(authProvider.select((u) => u?.id)) ?? localOwnerId,
);

/// Settings of the current owner (personal, ADR-0027) and of this device.
class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    final owner = ref.watch(settingsOwnerProvider);
    final store = ref.watch(userSettingsStoreProvider);
    final serverUrl = ref.watch(serverUrlProvider);
    // Changes from the sync (ADR-0027); the sync is paused in live mode, so
    // nothing changes on stage (ADR-0007).
    final sub = store.changes
        .where((o) => o == owner)
        .listen((_) => state = _compose(owner, ref.read(serverUrlProvider)));
    ref.onDispose(sub.cancel);
    return _compose(owner, serverUrl);
  }

  AppSettings _compose(String owner, String serverUrl) {
    final prefs = ref.read(sharedPreferencesProvider);
    return AppSettings.fromJson({
      ...AppSettings.readPrefs(
        prefs,
        AppSettings.keysOf(SettingSyncScope.device),
      ),
      ...ref.read(userSettingsStoreProvider).data(owner),
      'serverUrl': serverUrl,
    });
  }

  Future<void> update(AppSettings Function(AppSettings) change) async {
    final before = state.toJson();
    state = change(state);
    final after = state.toJson();
    final personal = <String, Object>{};
    final device = <String, Object>{};
    for (final MapEntry(:key, :value) in after.entries) {
      if (before[key] == value) continue;
      (AppSettings.scopes[key] == SettingSyncScope.personal
              ? personal
              : device)[key] =
          value;
    }
    if (device.remove('serverUrl') case final String url) {
      await ref.read(serverUrlProvider.notifier).set(url);
    }
    await AppSettings.writePrefs(ref.read(sharedPreferencesProvider), device);
    if (personal.isNotEmpty) {
      await ref
          .read(userSettingsStoreProvider)
          .change(ref.read(settingsOwnerProvider), personal);
    }
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

/// Selection context for conditional directives; changes only with the
/// instrument and the user name, not with other settings.
final selectorsProvider = Provider<SelectorContext>((ref) {
  ref.watch(settingsProvider.select((s) => (s.instrument, s.userName)));
  return ref.read(settingsProvider).selectors;
});

/// The server when none is chosen in the settings:
/// - [configured]: `--dart-define=SETDING_SERVER_URL=...` at build time,
///   e.g. for `flutter run -d chrome` against a local backend;
/// - on the web client the page's own origin: it is served by the same
///   PocketBase (ADR-0018), so the API is same-origin (no CORS);
/// - otherwise [defaultServerUrl].
String initialServerUrl({
  bool web = kIsWeb,
  Uri? page,
  String configured = const String.fromEnvironment('SETDING_SERVER_URL'),
}) {
  if (configured.isNotEmpty) return configured;
  if (web) {
    final base = page ?? Uri.base;
    if (base.scheme == 'http' || base.scheme == 'https') return base.origin;
  }
  return defaultServerUrl;
}

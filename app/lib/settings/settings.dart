import 'package:chordpro/chordpro.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ui/render/song_view.dart' show ChorusRepeat;

export '../ui/render/song_view.dart' show ChorusRepeat;

/// UI language setting (ADR-0008).
enum LanguageMode { system, de, en }

/// What is shown of a song.
enum DisplayMode { lyricsAndChords, lyricsOnly }

/// Number of columns in live mode. When fitting to the screen this is the
/// maximum; `auto` allows up to four columns.
enum ColumnMode { auto, one, two, three }

/// How far a page turn moves.
enum PageTurnMode { full, half }

/// Device settings (layer 4, ADR-0006). Stored locally per device.
@immutable
class AppSettings {
  const AppSettings({
    this.language = LanguageMode.system,
    this.notation = ChordNotation.international,
    this.nashville = false,
    this.displayMode = DisplayMode.lyricsAndChords,
    this.themeMode = ThemeMode.system,
    this.columns = ColumnMode.auto,
    this.pageTurn = PageTurnMode.full,
    this.autoFit = true,
    this.chorusRepeat = ChorusRepeat.auto,
    this.fontSize = 20,
    this.instrument = 'guitar',
    this.userName = '',
  });

  final LanguageMode language;
  final ChordNotation notation;
  final bool nashville;
  final DisplayMode displayMode;
  final ThemeMode themeMode;
  final ColumnMode columns;
  final PageTurnMode pageTurn;

  /// Fit the whole song on the screen (no scrolling) in live mode.
  final bool autoFit;
  final ChorusRepeat chorusRepeat;

  /// Base font size for lyrics in logical pixels.
  final double fontSize;

  /// Instrument type for conditional directives and chord diagrams
  /// (ADR-0012), e.g. `guitar`, `ukulele` or a free text.
  final String instrument;

  /// User name for conditional directives (e.g. a voice like `alto`).
  final String userName;

  /// Instrument presets offered in the settings.
  static const instruments = [
    'guitar',
    'ukulele',
    'bass',
    'keyboard',
    'vocals',
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
    DisplayMode? displayMode,
    ThemeMode? themeMode,
    ColumnMode? columns,
    PageTurnMode? pageTurn,
    bool? autoFit,
    ChorusRepeat? chorusRepeat,
    double? fontSize,
    String? instrument,
    String? userName,
  }) => AppSettings(
    language: language ?? this.language,
    notation: notation ?? this.notation,
    nashville: nashville ?? this.nashville,
    displayMode: displayMode ?? this.displayMode,
    themeMode: themeMode ?? this.themeMode,
    columns: columns ?? this.columns,
    pageTurn: pageTurn ?? this.pageTurn,
    autoFit: autoFit ?? this.autoFit,
    chorusRepeat: chorusRepeat ?? this.chorusRepeat,
    instrument: instrument ?? this.instrument,
    userName: userName ?? this.userName,
    fontSize: fontSize ?? this.fontSize,
  );

  static AppSettings load(SharedPreferences prefs) {
    T pick<T extends Enum>(List<T> values, String key, T fallback) {
      final name = prefs.getString(key);
      return values.firstWhere((v) => v.name == name, orElse: () => fallback);
    }

    const d = AppSettings();
    return AppSettings(
      language: pick(LanguageMode.values, 'language', d.language),
      notation: pick(ChordNotation.values, 'notation', d.notation),
      nashville: prefs.getBool('nashville') ?? d.nashville,
      displayMode: pick(DisplayMode.values, 'displayMode', d.displayMode),
      themeMode: pick(ThemeMode.values, 'themeMode', d.themeMode),
      columns: pick(ColumnMode.values, 'columns', d.columns),
      pageTurn: pick(PageTurnMode.values, 'pageTurn', d.pageTurn),
      autoFit: prefs.getBool('autoFit') ?? d.autoFit,
      chorusRepeat: pick(ChorusRepeat.values, 'chorusRepeat', d.chorusRepeat),
      instrument: prefs.getString('instrument') ?? d.instrument,
      userName: prefs.getString('userName') ?? d.userName,
      fontSize: (prefs.getDouble('fontSize') ?? d.fontSize).clamp(
        minFontSize,
        maxFontSize,
      ),
    );
  }

  Future<void> save(SharedPreferences prefs) async {
    await prefs.setString('language', language.name);
    await prefs.setString('notation', notation.name);
    await prefs.setBool('nashville', nashville);
    await prefs.setString('displayMode', displayMode.name);
    await prefs.setString('themeMode', themeMode.name);
    await prefs.setString('columns', columns.name);
    await prefs.setString('pageTurn', pageTurn.name);
    await prefs.setBool('autoFit', autoFit);
    await prefs.setString('chorusRepeat', chorusRepeat.name);
    await prefs.setString('instrument', instrument);
    await prefs.setString('userName', userName);
    await prefs.setDouble('fontSize', fontSize);
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

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => AppSettings.load(ref.watch(sharedPreferencesProvider));

  Future<void> update(AppSettings Function(AppSettings) change) async {
    state = change(state);
    await state.save(ref.read(sharedPreferencesProvider));
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

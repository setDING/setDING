import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/l10n/generated/app_localizations.dart';
import 'package:setding/settings/settings.dart';

/// The UI languages: German, English, Italian, French, Spanish and
/// Portuguese (ADR-0008, #983).
void main() {
  test('every language setting has a locale the app supports', () {
    final supported = AppLocalizations.supportedLocales
        .map((l) => l.languageCode)
        .toSet();
    for (final mode in LanguageMode.values) {
      final locale = const AppSettings().copyWith(language: mode).locale;
      if (mode == LanguageMode.system) {
        expect(locale, isNull);
      } else {
        expect(supported, contains(locale!.languageCode), reason: '$mode');
        expect(locale.languageCode, mode.name);
      }
    }
  });

  test('the system language picks a supported language', () {
    expect(resolveLocale(null, const [Locale('it', 'CH')]), const Locale('it'));
    expect(resolveLocale(null, const [Locale('fr', 'CH')]), const Locale('fr'));
    expect(resolveLocale(null, const [Locale('es')]), const Locale('es'));
    expect(resolveLocale(null, const [Locale('pt', 'BR')]), const Locale('pt'));
    expect(
      resolveLocale(null, const [Locale('de', 'AT')]),
      const Locale('de', 'CH'),
    );
    expect(
      resolveLocale(null, const [Locale('nl'), Locale('fr')]),
      const Locale('fr'),
    );
    expect(resolveLocale(null, const [Locale('nl')]), const Locale('en'));
    expect(
      resolveLocale(const Locale('pt'), const [Locale('de')]),
      const Locale('pt'),
    );
  });

  test('the new languages are translated', () {
    final en = lookupAppLocalizations(const Locale('en'));
    for (final (code, settings) in [
      ('it', 'Impostazioni'),
      ('fr', 'Réglages'),
      ('es', 'Ajustes'),
      ('pt', 'Definições'),
    ]) {
      final l = lookupAppLocalizations(Locale(code));
      expect(l.navSettings, settings);
      expect(l.cancel, isNot(en.cancel), reason: code);
      expect(l.importResult(2), isNot(en.importResult(2)), reason: code);
    }
  });

  test('language names are written in their own language', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final l = lookupAppLocalizations(locale);
      expect(
        [
          l.languageDe,
          l.languageEn,
          l.languageIt,
          l.languageFr,
          l.languageEs,
          l.languagePt,
        ],
        ['Deutsch', 'English', 'Italiano', 'Français', 'Español', 'Português'],
      );
    }
  });
}

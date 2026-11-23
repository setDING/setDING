import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/generated/app_localizations.dart';

/// The user documentation (ADR-0030).
const docsSiteUrl = 'https://setding.app';

/// The languages of the documentation site and the folder of each: Swiss
/// Standard German is the root locale, English lives under `en/`. A UI
/// language without its own documentation gets [docsFallbackLanguage]; a new
/// language of the site is one entry here.
const docsSiteLanguages = {'de': '', 'en': 'en/'};

/// The documentation for UI languages the site does not have.
const docsFallbackLanguage = 'en';

/// The pages of the user documentation the app links to (#993).
///
/// The app links to pages, never to headings: their anchors are made from
/// the headings and differ in every language, the page paths do not.
/// `website/src/app-docs-links.test.ts` fails when one of these pages is
/// missing in a language of the site.
enum DocsPage {
  overview('start/overview'),
  roles('bands/roles'),
  organizations('bands/organizations'),
  keyAndSequence('sets/key-and-sequence'),
  editor('songs/editor'),
  chordViews('songs/chord-views'),
  keyboard('live/keyboard'),
  account('settings/account'),
  settingsGeneral('settings/general'),
  settingsDisplay('settings/display'),
  songDisplay('settings/song-display');

  const DocsPage(this.path);

  /// The path of the page below the language folder, without slashes.
  final String path;

  /// The page in the language of [locale] (see [docsSiteLanguages]).
  Uri url(Locale locale) => docsPageUrl(path, locale);
}

/// The documentation page at [path] (e.g. `songs/chord-views`) in the
/// language of [locale], or in [docsFallbackLanguage] when the site does not
/// have that language.
Uri docsPageUrl(String path, Locale locale) {
  final folder =
      docsSiteLanguages[locale.languageCode] ??
      docsSiteLanguages[docsFallbackLanguage]!;
  return Uri.parse('$docsSiteUrl/$folder$path/');
}

/// Opens [page] in the browser, in the language of the app.
Future<void> openDocsPage(BuildContext context, DocsPage page) => launchUrl(
  page.url(Localizations.localeOf(context)),
  mode: LaunchMode.externalApplication,
);

/// A link to a page of the user documentation, opened in the browser.
class DocsLink extends StatelessWidget {
  const DocsLink({super.key, required this.page, required this.label});

  final DocsPage page;
  final String label;

  @override
  Widget build(BuildContext context) => TextButton.icon(
    style: TextButton.styleFrom(
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    ),
    icon: const Icon(Icons.open_in_new, size: 18),
    label: Text(label),
    onPressed: () => openDocsPage(context, page),
  );
}

/// The help button of a screen, panel or section whose concept needs more
/// than a hint (#993): opens [page] of the user documentation in the
/// browser. Its tooltip names the [topic] ("Help: Roles"). The book, not a
/// question mark: the small (?) of [ScopeInfo] explains in place whom a
/// setting applies to, this one leaves the app.
class DocsHelpButton extends StatelessWidget {
  const DocsHelpButton({super.key, required this.page, required this.topic});

  final DocsPage page;

  /// What the page explains, as the screen or section calls it.
  final String topic;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: AppLocalizations.of(context).docsHelp(topic),
    icon: const Icon(Icons.menu_book_outlined),
    onPressed: () => openDocsPage(context, page),
  );
}

import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

/// The user documentation (ADR-0030).
const docsSiteUrl = 'https://setding.app';

/// The documentation page at [path] (e.g. `songs/chord-views`) in the
/// language of [locale]: German pages at the root, English ones under
/// `en/`.
Uri docsPageUrl(String path, Locale locale) =>
    Uri.parse('$docsSiteUrl/${locale.languageCode == 'de' ? '' : 'en/'}$path/');

/// A link to a page of the user documentation, opened in the browser.
class DocsLink extends StatelessWidget {
  const DocsLink({super.key, required this.path, required this.label});

  final String path;
  final String label;

  @override
  Widget build(BuildContext context) => TextButton.icon(
    style: TextButton.styleFrom(
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    ),
    icon: const Icon(Icons.open_in_new, size: 18),
    label: Text(label),
    onPressed: () => launchUrl(
      docsPageUrl(path, Localizations.localeOf(context)),
      mode: LaunchMode.externalApplication,
    ),
  );
}

import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../sync/update_check.dart' show releasePageUrl;
import '../../update/whats_new.dart';

/// The "What's new" notes of one version (ADR-0041), in the app language,
/// with a link to all changes.
Future<void> showWhatsNew(BuildContext context, VersionNotes version) {
  final l10n = AppLocalizations.of(context);
  final language = Localizations.localeOf(context).languageCode;
  final theme = Theme.of(context);
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      key: const Key('whats-new-dialog'),
      title: Text(l10n.whatsNewTitle),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  l10n.whatsNewVersion(version.version),
                  style: theme.textTheme.titleSmall,
                ),
              ),
              for (final note in version.inLanguage(language))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('•  '),
                      Expanded(child: Text(note)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => launchUrl(
            releasePageUrl(version.version),
            mode: LaunchMode.externalApplication,
          ),
          child: Text(l10n.whatsNewAllChanges),
        ),
        FilledButton(
          key: const Key('whats-new-close'),
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.close),
        ),
      ],
    ),
  );
}

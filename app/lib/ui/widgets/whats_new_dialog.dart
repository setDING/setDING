import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../sync/update_check.dart' show releasePageUrl;
import '../../update/whats_new.dart';

/// The "What's new" notes of [versions], newest first (ADR-0041), in the
/// app language.
Future<void> showWhatsNew(BuildContext context, List<VersionNotes> versions) {
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
              for (final (i, v) in versions.indexed) ...[
                Padding(
                  padding: EdgeInsets.only(top: i == 0 ? 0 : 16, bottom: 4),
                  child: Text(
                    l10n.whatsNewVersion(v.version),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                for (final note in v.inLanguage(language))
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
            ],
          ),
        ),
      ),
      actions: [
        if (versions.isNotEmpty)
          TextButton(
            onPressed: () => launchUrl(
              releasePageUrl(versions.first.version),
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

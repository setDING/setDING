import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/database.dart';
import '../../data/lineup.dart';
import '../../data/set_providers.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../sync/auth_providers.dart';
import '../../sync/sync_backend.dart';
import '../widgets/dialogs.dart';
import 'lineup_view.dart';

/// The message to the lineup of [set] (ADR-0061): who plays which set when
/// and where; [formatDate] formats the gig date.
({String subject, String body}) lineupMessage(
  AppLocalizations l10n,
  SetlistEntry set,
  SetLineup lineup, {
  required String Function(DateTime date) formatDate,
}) {
  final details = [
    if (set.gigDate case final date?) formatDate(date),
    if (set.venue case final venue? when venue.trim().isNotEmpty) venue.trim(),
  ].join(' · ');
  return (
    subject: '${l10n.lineup}: ${set.name}',
    body: [
      l10n.lineupMessageIntro(set.name),
      if (details.isNotEmpty) details,
      '${l10n.lineup}: ${lineupNames(l10n, lineup)}',
      '',
      l10n.lineupMessageFooter,
    ].join('\n'),
  );
}

/// A `mailto:` link to [recipients] with [subject] and [body].
Uri lineupMailUri(List<String> recipients, String subject, String body) =>
    // Encoded by hand: Uri's query encoding turns spaces into "+", which
    // mail programs keep.
    Uri.parse(
      'mailto:${recipients.map(Uri.encodeComponent).join(',')}'
      '?subject=${Uri.encodeComponent(subject)}'
      '&body=${Uri.encodeComponent(body)}',
    );

/// *Notify lineup* (ADR-0061): the prepared message to share (the
/// platform's share menu), to copy, or to send by mail to the lineup's
/// addresses, which the server gives to who may edit the set. The app
/// sends nothing itself; offline the mail has no recipients.
Future<void> showNotifyLineupDialog(
  BuildContext context,
  WidgetRef ref,
  SetlistEntry set,
  String Function(DateTime date) formatDate,
) async {
  final lineup = ref.read(setLineupProvider(set.id));
  if (lineup == null) return;
  final l10n = AppLocalizations.of(context);
  final message = lineupMessage(l10n, set, lineup, formatDate: formatDate);
  final backend = ref.read(syncBackendProvider);
  await showDialog<void>(
    context: context,
    builder: (_) => _NotifyDialog(
      message: message,
      emails: backend.fetchLineupEmails(set.id),
    ),
  );
}

class _NotifyDialog extends StatelessWidget {
  const _NotifyDialog({required this.message, required this.emails});

  final ({String subject, String body}) message;
  final Future<List<({String name, String email})>> emails;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return FutureBuilder<List<({String name, String email})>>(
      future: emails.catchError(
        (Object _) => const <({String name, String email})>[],
        test: (e) => e is BackendException,
      ),
      builder: (context, snapshot) {
        final addresses = [
          for (final p
              in snapshot.data ?? const <({String name, String email})>[])
            p.email,
        ];
        final loaded = snapshot.connectionState == ConnectionState.done;
        return AlertDialog(
          title: Text(l10n.lineupNotify),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    message.body,
                    key: const Key('lineup-message'),
                  ),
                ),
                if (loaded && addresses.isEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    l10n.lineupNoAddresses,
                    key: const Key('lineup-no-addresses'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.close),
            ),
            TextButton(
              key: const Key('lineup-copy'),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: message.body));
                if (context.mounted) showMessage(context, l10n.lineupCopied);
              },
              child: Text(l10n.lineupCopy),
            ),
            TextButton(
              key: const Key('lineup-mail'),
              onPressed: !loaded
                  ? null
                  : () => launchUrl(
                      lineupMailUri(addresses, message.subject, message.body),
                    ),
              child: Text(l10n.lineupMail),
            ),
            FilledButton(
              key: const Key('lineup-share'),
              onPressed: () => SharePlus.instance.share(
                ShareParams(text: message.body, subject: message.subject),
              ),
              child: Text(l10n.lineupShare),
            ),
          ],
        );
      },
    );
  }
}

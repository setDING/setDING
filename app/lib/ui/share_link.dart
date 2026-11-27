import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/generated/app_localizations.dart';
import '../settings/settings.dart' show serverUrlProvider;
import '../sync/auth_providers.dart' show serverConfigProvider;
import '../sync/sync_backend.dart' show ServerConfig;
import 'widgets/dialogs.dart';

/// The link to the screen at [path] (e.g. `/sets/<id>`) for others
/// (ADR-0065): on the web client's URL, which the server reports
/// (`linkBase`), so it opens the installed app (App Links) or the web
/// client; the web client uses its own address. Without an answer from the
/// server (offline), the server's URL.
Future<String> recordLink(WidgetRef ref, String path) async {
  final String base;
  if (kIsWeb) {
    base = Uri.base.origin;
  } else {
    final config = await ref
        .read(serverConfigProvider.future)
        .timeout(
          const Duration(seconds: 3),
          onTimeout: () => ServerConfig.unknown,
        );
    base = config.linkBase ?? ref.read(serverUrlProvider);
  }
  return '${base.replaceFirst(RegExp(r'/+$'), '')}$path';
}

/// Shares the link to [path] through the system's share sheet on phones and
/// tablets, and copies it elsewhere (desktop, web), where sharing a text
/// does not reach a chat.
Future<void> shareRecordLink(
  BuildContext context,
  WidgetRef ref, {
  required String path,
  required String title,
}) async {
  final l10n = AppLocalizations.of(context);
  final link = await recordLink(ref, path);
  final mobile =
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  if (mobile) {
    await SharePlus.instance.share(
      ShareParams(text: link, subject: title, title: title),
    );
    return;
  }
  await Clipboard.setData(ClipboardData(text: link));
  if (context.mounted) showMessage(context, l10n.linkCopied);
}

import 'package:chordpro/chordpro.dart' hide Key;
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/generated/app_localizations.dart';
import '../widgets/dialogs.dart';
import '../widgets/side_panel.dart';

/// Opens [uri] outside the app (the service's app or the browser); false
/// when nothing could open it. Replaced in tests.
@visibleForTesting
Future<bool> Function(Uri uri) openSongLink = (uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

/// Names of the detected services (brand names, the same in every
/// language); null for [LinkService.other].
String? linkServiceName(LinkService service) => switch (service) {
  LinkService.youtube => 'YouTube',
  LinkService.spotify => 'Spotify',
  LinkService.appleMusic => 'Apple Music',
  LinkService.soundcloud => 'SoundCloud',
  LinkService.deezer => 'Deezer',
  LinkService.tidal => 'TIDAL',
  LinkService.other => null,
};

IconData linkServiceIcon(LinkService service) => switch (service) {
  LinkService.youtube => Icons.smart_display_outlined,
  LinkService.spotify ||
  LinkService.appleMusic ||
  LinkService.deezer ||
  LinkService.tidal => Icons.music_note_outlined,
  LinkService.soundcloud => Icons.cloud_outlined,
  LinkService.other => Icons.link,
};

/// Side panel with the sources of a song (`{x_link}`): recordings on
/// YouTube, Spotify and the like, opened outside the app. With [onAdd],
/// people who may edit the song add a link.
class SongLinksPanel extends StatelessWidget {
  const SongLinksPanel({super.key, required this.links, this.onAdd});

  final List<SongLink> links;
  final Future<void> Function(String url, String? label)? onAdd;

  Future<void> _open(BuildContext context, SongLink link) async {
    final l10n = AppLocalizations.of(context);
    var opened = false;
    try {
      opened = await openSongLink(link.uri);
    } catch (_) {
      opened = false;
    }
    if (!opened && context.mounted) showMessage(context, l10n.songLinkFailed);
  }

  Future<void> _add(BuildContext context) async {
    final result = await showDialog<({String url, String? label})>(
      context: context,
      builder: (_) => const _AddLinkDialog(),
    );
    if (result != null) await onAdd!(result.url, result.label);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return SidePanel(
      key: const Key('song-links'),
      icon: Icons.headphones_outlined,
      title: l10n.songLinks,
      children: [
        if (links.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              l10n.noSongLinks,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        for (final link in links)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(linkServiceIcon(link.service)),
            title: Text(
              link.label ?? linkServiceName(link.service) ?? link.domain,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              link.domain,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.open_in_new, size: 20),
            onTap: () => _open(context, link),
          ),
        if (onAdd != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.add_link),
              label: Text(l10n.addSongLink),
              onPressed: () => _add(context),
            ),
          ),
        ],
      ],
    );
  }
}

/// Asks for the URL and an optional label of a new source.
class _AddLinkDialog extends StatefulWidget {
  const _AddLinkDialog();

  @override
  State<_AddLinkDialog> createState() => _AddLinkDialogState();
}

class _AddLinkDialogState extends State<_AddLinkDialog> {
  final _url = TextEditingController();
  final _label = TextEditingController();
  bool _invalid = false;

  @override
  void dispose() {
    _url.dispose();
    _label.dispose();
    super.dispose();
  }

  void _submit() {
    final url = _url.text.trim();
    // `|` separates the label in the directive, so it is not part of a URL
    // typed here.
    if (url.contains('|') || parseSongLink(url) == null) {
      setState(() => _invalid = true);
      return;
    }
    final label = _label.text.replaceAll('|', '/').trim();
    Navigator.pop(context, (url: url, label: label.isEmpty ? null : label));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.addSongLink),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('song-link-url'),
              controller: _url,
              autofocus: true,
              keyboardType: TextInputType.url,
              onChanged: (_) {
                if (_invalid) setState(() => _invalid = false);
              },
              decoration: InputDecoration(
                labelText: l10n.songLinkUrl,
                hintText: 'https://www.youtube.com/watch?v=…',
                errorText: _invalid ? l10n.songLinkInvalid : null,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('song-link-label'),
              controller: _label,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: l10n.songLinkLabel,
                hintText: l10n.songLinkLabelHint,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.add)),
      ],
    );
  }
}

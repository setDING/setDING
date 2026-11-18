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
/// YouTube, Spotify and the like, opened outside the app. With [onAdd]
/// and [onChange], people who may edit the song add, edit and remove links.
class SongLinksPanel extends StatelessWidget {
  const SongLinksPanel({
    super.key,
    required this.links,
    this.onAdd,
    this.onChange,
  });

  final List<SongLink> links;
  final Future<void> Function(String url, String? label)? onAdd;

  /// Replaces the link at an index of [links]; a null url removes it.
  final Future<void> Function(int index, String? url, String? label)? onChange;

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
      builder: (_) => const _LinkDialog(),
    );
    if (result?.url case final url?) await onAdd!(url, result!.label);
  }

  Future<void> _edit(BuildContext context, int index) async {
    final result = await showDialog<({String? url, String? label})>(
      context: context,
      builder: (_) => _LinkDialog(link: links[index]),
    );
    if (result != null) await onChange!(index, result.url, result.label);
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
        for (final (index, link) in links.indexed)
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
            trailing: onChange == null
                ? const Icon(Icons.open_in_new, size: 20)
                : IconButton(
                    key: Key('edit-song-link-$index'),
                    tooltip: l10n.editSongLink,
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    onPressed: () => _edit(context, index),
                  ),
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

/// Asks for the URL and an optional label of a new source, or edits
/// [link]. Pops the url and label; a null url removes [link].
class _LinkDialog extends StatefulWidget {
  const _LinkDialog({this.link});

  final SongLink? link;

  @override
  State<_LinkDialog> createState() => _LinkDialogState();
}

class _LinkDialogState extends State<_LinkDialog> {
  late final _url = TextEditingController(text: widget.link?.uri.toString());
  late final _label = TextEditingController(text: widget.link?.label);
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

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    final ok = await confirm(
      context,
      title: l10n.deleteSongLink,
      message: l10n.deleteSongLinkMessage,
    );
    if (ok && mounted) Navigator.pop(context, (url: null, label: null));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final editing = widget.link != null;
    return AlertDialog(
      title: Text(editing ? l10n.editSongLink : l10n.addSongLink),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('song-link-url'),
              controller: _url,
              autofocus: !editing,
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
        if (editing)
          TextButton(
            key: const Key('delete-song-link'),
            onPressed: _delete,
            child: Text(l10n.delete),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(editing ? l10n.save : l10n.add),
        ),
      ],
    );
  }
}

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../projection/projection_controller.dart';
import '../widgets/dialogs.dart';
import '../widgets/section_header.dart';
import '../theme.dart';

/// The projection bar of live mode (ADR-0068 §6–8): previous / next
/// slide, *Blank*, back to following live mode, the copyright hint and
/// the links. Shown only while the projection is on.
class ProjectionBar extends StatelessWidget {
  const ProjectionBar({
    super.key,
    required this.controller,
    required this.onShowLinks,
  });

  final ProjectionController controller;
  final VoidCallback onShowLinks;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final slides = controller.slides;
        return Material(
          key: const Key('projection-bar'),
          color: scheme.surfaceContainerHigh.withValues(alpha: 0.92),
          shape: const StadiumBorder(),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  key: const Key('projection-links'),
                  tooltip: l10n.projectionLinks,
                  icon: Icon(Icons.cast_connected, color: scheme.primary),
                  onPressed: onShowLinks,
                ),
                if (controller.missingCopyright)
                  Tooltip(
                    message: l10n.projectionNoCopyright,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        Icons.copyright,
                        key: const Key('projection-no-copyright'),
                        color: StatusColors.of(context).warning,
                      ),
                    ),
                  ),
                IconButton(
                  key: const Key('projection-previous'),
                  tooltip: l10n.projectionPrevious,
                  icon: const Icon(Icons.chevron_left),
                  onPressed: controller.canPrevious
                      ? controller.previous
                      : null,
                ),
                // The projected section above the position (#1189), so
                // the presenter knows which block is on screen.
                if (slides.isNotEmpty)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (controller.label case final label?)
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 120),
                          child: Text(
                            label,
                            key: const Key('projection-section'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ),
                      Text(
                        '${controller.slide + 1}/${slides.length}',
                        key: const Key('projection-slide'),
                      ),
                    ],
                  ),
                IconButton(
                  key: const Key('projection-next'),
                  tooltip: l10n.projectionNext,
                  icon: const Icon(Icons.chevron_right),
                  onPressed: controller.canNext ? controller.next : null,
                ),
                if (controller.manual)
                  IconButton(
                    key: const Key('projection-follow'),
                    tooltip: l10n.projectionFollow,
                    icon: const Icon(Icons.sync),
                    onPressed: controller.follow,
                  ),
                IconButton(
                  key: const Key('projection-blank'),
                  tooltip: controller.blank
                      ? l10n.projectionUnblank
                      : l10n.projectionBlank,
                  isSelected: controller.blank,
                  icon: const Icon(Icons.tv),
                  selectedIcon: Icon(Icons.tv_off, color: scheme.error),
                  onPressed: controller.toggleBlank,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The links of the projection with a QR code, and *Stop projection*
/// (ADR-0068 §2). A bottom sheet, as everything in live mode.
///
/// The address stays the same on this device (#1183); [onRenew] makes a
/// new one, and the sheet shows it.
Future<void> showProjectionSheet(
  BuildContext context,
  ProjectionController controller, {
  required Future<void> Function() onRenew,
}) async {
  final urls = await controller.urls();
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) =>
        _ProjectionSheet(controller: controller, urls: urls, onRenew: onRenew),
  );
}

class _ProjectionSheet extends StatefulWidget {
  const _ProjectionSheet({
    required this.controller,
    required this.urls,
    required this.onRenew,
  });

  final ProjectionController controller;
  final List<Uri> urls;
  final Future<void> Function() onRenew;

  @override
  State<_ProjectionSheet> createState() => _ProjectionSheetState();
}

class _ProjectionSheetState extends State<_ProjectionSheet> {
  late List<Uri> urls = widget.urls;
  var _renewing = false;

  ProjectionController get controller => widget.controller;

  Future<void> _renew() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _renewing = true);
    await widget.onRenew();
    final fresh = await controller.urls();
    if (!mounted) return;
    setState(() {
      urls = fresh;
      _renewing = false;
    });
    showMessage(context, l10n.projectionRenewed);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final first = urls.isEmpty ? null : urls.first;
    Widget link(String label, Uri url, Key key) => ListTile(
      key: key,
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: SelectableText(url.toString()),
      trailing: IconButton(
        tooltip: l10n.projectionCopyLink,
        icon: const Icon(Icons.copy),
        onPressed: () async {
          await Clipboard.setData(ClipboardData(text: url.toString()));
          if (context.mounted) showMessage(context, l10n.projectionLinkCopied);
        },
      ),
    );
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(
              l10n.projectionTitle,
              padding: SectionHeader.insetPadding,
            ),
            if (first == null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  l10n.projectionNoNetwork,
                  key: const Key('projection-no-network'),
                ),
              )
            else ...[
              Text(l10n.projectionHint),
              const SizedBox(height: 16),
              Center(
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(12),
                  child: QrImageView(
                    key: const Key('projection-qr'),
                    data: first.toString(),
                    size: 200,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              for (final (i, url) in urls.indexed) ...[
                link(l10n.projectionFullScreen, url, Key('projection-url-$i')),
                link(
                  l10n.projectionLowerThird,
                  url.replace(path: '${url.path}/lower-third'),
                  Key('projection-lower-third-$i'),
                ),
              ],
            ],
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                // A new address: the old link stops working (#1183).
                TextButton.icon(
                  key: const Key('projection-renew'),
                  icon: const Icon(Icons.autorenew),
                  label: Text(l10n.projectionRenew),
                  onPressed: _renewing ? null : _renew,
                ),
                OutlinedButton.icon(
                  key: const Key('projection-stop'),
                  icon: const Icon(Icons.cancel_presentation),
                  label: Text(l10n.projectionStop),
                  onPressed: () {
                    controller.stop();
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

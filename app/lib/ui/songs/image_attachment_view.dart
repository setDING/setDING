import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../providers.dart';
import '../platform/stored_file_view.dart';

/// Shows an image attachment full screen, zoomable (#507).
Future<void> showImageAttachment(
  BuildContext context,
  AttachmentEntry attachment,
) => Navigator.push(
  context,
  MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (_) => ImageAttachmentView(attachment: attachment),
  ),
);

/// A full-screen, zoomable image attachment.
class ImageAttachmentView extends ConsumerWidget {
  const ImageAttachmentView({super.key, required this.attachment});

  final AttachmentEntry attachment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final file = ref.watch(attachmentStorageProvider).file(attachment.fileName);
    return Scaffold(
      appBar: AppBar(title: Text(attachment.name)),
      body: file.existsSync()
          ? LayoutBuilder(
              builder: (context, constraints) => InteractiveViewer(
                key: const Key('image-attachment'),
                maxScale: 8,
                child: Center(
                  child: storedImage(
                    file,
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                  ),
                ),
              ),
            )
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  l10n.imageMissing,
                  key: const Key('image-missing'),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
    );
  }
}

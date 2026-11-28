import 'package:material_ui/material_ui.dart';

import '../../data/attachment_storage.dart';
import '../../data/backup.dart' show SkippedFile;
import '../../l10n/generated/app_localizations.dart';
import '../songs/storage_usage.dart' show formatLimit;
import '../theme.dart';
import '../widgets/dialogs.dart';

/// The attachments an import left out, for its summary: those too large
/// (ADR-0070), each with its song, its size and the limit, and the images
/// whose content is not their type (#1227), each with its song. Nothing
/// when there are none.
class SkippedFilesReport extends StatelessWidget {
  const SkippedFilesReport(this.files, {super.key});

  final List<SkippedFile> files;

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final warning = StatusColors.of(context).warning;
    final tooLarge = [
      for (final f in files)
        if (!f.wrongType) f,
    ];
    final wrongType = [
      for (final f in files)
        if (f.wrongType) f,
    ];
    Widget tile(SkippedFile f, String subtitle) => ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(
        isPdfFile(f.name) || !f.name.contains('.')
            ? Icons.picture_as_pdf_outlined
            : isImageFile(f.name)
            ? Icons.image_outlined
            : Icons.insert_drive_file_outlined,
        color: warning,
      ),
      title: Text(f.name),
      subtitle: Text(subtitle),
    );
    return Column(
      key: const Key('import-skipped-files'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (tooLarge.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(l10n.importSkippedFiles(tooLarge.length)),
          for (final f in tooLarge)
            tile(
              f,
              l10n.importSkippedFile(
                f.song,
                formatBytes(f.sizeBytes),
                formatLimit(f.limitBytes),
              ),
            ),
        ],
        if (wrongType.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            l10n.importSkippedWrongType(wrongType.length),
            key: const Key('import-skipped-wrong-type'),
          ),
          for (final f in wrongType) tile(f, f.song),
        ],
      ],
    );
  }
}

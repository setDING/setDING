import 'package:material_ui/material_ui.dart';

import '../../data/attachment_storage.dart';
import '../../data/backup.dart' show SkippedFile;
import '../../l10n/generated/app_localizations.dart';
import '../songs/storage_usage.dart' show formatLimit;
import '../theme.dart';
import '../widgets/dialogs.dart';

/// The attachments an import left out because they are too large
/// (ADR-0070), for its summary: each with its song, its size and the
/// limit. Nothing when there are none.
class SkippedFilesReport extends StatelessWidget {
  const SkippedFilesReport(this.files, {super.key});

  final List<SkippedFile> files;

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final warning = StatusColors.of(context).warning;
    return Column(
      key: const Key('import-skipped-files'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(l10n.importSkippedFiles(files.length)),
        for (final f in files)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: Icon(
              isPdfFile(f.name) || !f.name.contains('.')
                  ? Icons.picture_as_pdf_outlined
                  : Icons.insert_drive_file_outlined,
              color: warning,
            ),
            title: Text(f.name),
            subtitle: Text(
              l10n.importSkippedFile(
                f.song,
                formatBytes(f.sizeBytes),
                formatLimit(f.limitBytes),
              ),
            ),
          ),
      ],
    );
  }
}

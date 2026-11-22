import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/generated/app_localizations.dart';
import 'section_header.dart';

/// What an export of songs or a set writes (issue #870).
enum ExportFormat {
  /// One ChordPro file, for other apps.
  chordPro,

  /// The printable set list (ADR-0013).
  setListPdf,

  /// A setDING archive with options (ADR-0043).
  archive,
}

/// The format chosen last in an export dialog, for the running app.
class LastExportFormatNotifier extends Notifier<ExportFormat?> {
  @override
  ExportFormat? build() => null;

  void choose(ExportFormat format) => state = format;
}

/// The format chosen last when exporting songs.
final lastSongExportFormatProvider =
    NotifierProvider<LastExportFormatNotifier, ExportFormat?>(
      LastExportFormatNotifier.new,
    );

/// The format chosen last when exporting a set.
final lastSetExportFormatProvider =
    NotifierProvider<LastExportFormatNotifier, ExportFormat?>(
      LastExportFormatNotifier.new,
    );

/// The format to preselect: the [last] one if [available], else the first.
ExportFormat initialExportFormat(
  List<ExportFormat> available,
  ExportFormat? last,
) => last != null && available.contains(last) ? last : available.first;

/// The format choice at the top of an export dialog; shows nothing if there
/// is only one format.
class ExportFormatChoice extends StatelessWidget {
  const ExportFormatChoice({
    super.key,
    required this.available,
    required this.value,
    required this.onChanged,
  });

  final List<ExportFormat> available;
  final ExportFormat value;
  final ValueChanged<ExportFormat> onChanged;

  @override
  Widget build(BuildContext context) {
    if (available.length < 2) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(l10n.exportFormat, padding: SectionHeader.insetPadding),
        RadioGroup<ExportFormat>(
          groupValue: value,
          onChanged: (v) => onChanged(v!),
          child: Column(
            children: [
              for (final format in available)
                RadioListTile<ExportFormat>(
                  key: Key('export-format-${format.name}'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  value: format,
                  title: Text(switch (format) {
                    ExportFormat.chordPro => l10n.exportFormatChordPro,
                    ExportFormat.setListPdf => l10n.exportFormatSetListPdf,
                    ExportFormat.archive => l10n.exportFormatArchive,
                  }, style: theme.textTheme.bodyMedium),
                  subtitle: Text(switch (format) {
                    ExportFormat.chordPro => l10n.exportFormatChordProHint,
                    ExportFormat.setListPdf => l10n.exportFormatSetListPdfHint,
                    ExportFormat.archive => l10n.exportFormatArchiveHint,
                  }),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

import 'package:material_ui/material_ui.dart';

import '../../l10n/generated/app_localizations.dart';
import 'section_header.dart';

/// The danger zone at the end of a screen: a tile tinted in the error colour
/// that holds the actions that cannot be undone, such as deleting the
/// account, deleting a band or closing an organization
/// (docs/development/ui-design.md, "Actions"). Every danger zone of the app
/// uses it, so it looks the same on every screen.
class DangerZone extends StatelessWidget {
  const DangerZone({super.key, this.title, required this.children});

  /// The heading; *Danger zone* when null.
  final String? title;

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Material(
        key: const Key('danger-zone'),
        color: scheme.errorContainer.withValues(alpha: 0.4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: scheme.error.withValues(alpha: 0.6)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(
                title ?? AppLocalizations.of(context).dangerZone,
                icon: Icons.warning_amber_rounded,
                color: scheme.error,
                padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 4),
              ),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

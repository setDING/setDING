import 'package:material_ui/material_ui.dart';

import '../../l10n/generated/app_localizations.dart';

/// Whom a setting applies to.
enum SettingScope {
  /// Only the current user (personal overlay, ADR-0006).
  personal,

  /// One set; the whole band plays it like that.
  set,

  /// The band arrangement, used in all the band's sets (ADR-0025).
  band,

  /// The shared song, changed for everyone in the organization.
  song,
}

/// Small (?) icon next to a label that tells whom the setting applies to.
///
/// The text shows on mouse hover and on tap (touch devices), so the UI stays
/// tidy while the scope is always one gesture away.
class ScopeInfo extends StatelessWidget {
  const ScopeInfo(this.scope, {super.key});

  final SettingScope scope;

  static String text(AppLocalizations l10n, SettingScope scope) =>
      switch (scope) {
        SettingScope.personal => l10n.scopePersonal,
        SettingScope.set => l10n.scopeSet,
        SettingScope.band => l10n.scopeBand,
        SettingScope.song => l10n.scopeSong,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Tooltip(
      key: ValueKey('scope-info-${scope.name}'),
      message: text(l10n, scope),
      triggerMode: TooltipTriggerMode.tap,
      showDuration: const Duration(seconds: 5),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          Icons.help_outline,
          size: 16,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

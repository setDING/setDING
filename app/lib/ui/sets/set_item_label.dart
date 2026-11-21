import 'package:material_ui/material_ui.dart';

import '../../data/marker_icons.dart';
import '../../l10n/generated/app_localizations.dart';

// Icons and names of set markers (breaks, announcements, encores, …,
// ADR-0047).
//
// The text of a marker is shared with the whole band (ADR-0015), and band
// members may use different UI languages (ADR-0008). A text that is empty
// or just the default name of its icon in any supported language counts as
// no text of its own: the marker shows the icon's name in the current
// language instead (#289). Older versions stored the type label of the
// creator's language ("Pause", "Break", "Text") as the note; it counts as
// the name of the icon the type became.

/// The Material icon of the catalogue [key]; a neutral icon for a key this
/// version does not know.
IconData markerIconData(String? key) => switch (key) {
  MarkerIcons.breakIcon => Icons.local_cafe_outlined,
  MarkerIcons.drinks => Icons.local_bar_outlined,
  MarkerIcons.announcement => Icons.campaign_outlined,
  MarkerIcons.microphone => Icons.mic_none,
  MarkerIcons.guest => Icons.person_add_alt_outlined,
  MarkerIcons.encore => Icons.star_outline,
  MarkerIcons.transition => Icons.arrow_forward,
  MarkerIcons.solo => Icons.music_note_outlined,
  MarkerIcons.applause => Icons.waving_hand_outlined,
  MarkerIcons.instrument => Icons.swap_horiz,
  MarkerIcons.tuning => Icons.tune,
  MarkerIcons.click => Icons.av_timer,
  MarkerIcons.light => Icons.lightbulb_outline,
  MarkerIcons.effects => Icons.auto_awesome_outlined,
  MarkerIcons.celebration => Icons.celebration_outlined,
  MarkerIcons.info => Icons.info_outline,
  MarkerIcons.warning => Icons.warning_amber_outlined,
  _ => Icons.label_outline,
};

/// The default name of the catalogue [key] in [l10n]'s language, e.g.
/// "Encore"; a generic name for a key this version does not know.
String markerIconName(AppLocalizations l10n, String? key) => switch (key) {
  MarkerIcons.breakIcon => l10n.markerIconBreak,
  MarkerIcons.drinks => l10n.markerIconDrinks,
  MarkerIcons.announcement => l10n.markerIconAnnouncement,
  MarkerIcons.microphone => l10n.markerIconMicrophone,
  MarkerIcons.guest => l10n.markerIconGuest,
  MarkerIcons.encore => l10n.markerIconEncore,
  MarkerIcons.transition => l10n.markerIconTransition,
  MarkerIcons.solo => l10n.markerIconSolo,
  MarkerIcons.applause => l10n.markerIconApplause,
  MarkerIcons.instrument => l10n.markerIconInstrument,
  MarkerIcons.tuning => l10n.markerIconTuning,
  MarkerIcons.click => l10n.markerIconClick,
  MarkerIcons.light => l10n.markerIconLight,
  MarkerIcons.effects => l10n.markerIconEffects,
  MarkerIcons.celebration => l10n.markerIconCelebration,
  MarkerIcons.info => l10n.markerIconInfo,
  MarkerIcons.warning => l10n.markerIconWarning,
  _ => l10n.marker,
};

/// The texts that count as no text of its own for a marker with an icon,
/// in every supported UI language and in lower case.
final Map<String?, Set<String>> _defaultNames = {};

Set<String> _namesOf(String? icon) => _defaultNames.putIfAbsent(icon, () {
  final names = <String>{};
  for (final locale in AppLocalizations.supportedLocales) {
    final l10n = lookupAppLocalizations(locale);
    names.add(markerIconName(l10n, icon).toLowerCase());
    // Type labels of older versions.
    if (icon == MarkerIcons.breakIcon) names.add(l10n.pause.toLowerCase());
    if (icon == MarkerIcons.announcement) {
      names.add(l10n.textItem.toLowerCase());
    }
  }
  return names;
});

/// The text of a marker with [icon], or null when it has none of its own:
/// empty, or just the default name of the icon in one of the supported
/// languages.
String? markerNote(String? icon, String? note) {
  final text = note?.trim() ?? '';
  if (text.isEmpty) return null;
  return _namesOf(icon).contains(text.toLowerCase()) ? null : text;
}

/// What a marker shows as its name: its own text, otherwise the default
/// name of its icon in the current language.
String markerTitle(AppLocalizations l10n, String? icon, String? note) =>
    markerNote(icon, note) ?? markerIconName(l10n, icon);

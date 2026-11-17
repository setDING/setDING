import '../../data/database.dart';
import '../../l10n/generated/app_localizations.dart';

// Labels of pause and text items (breaks and announcements in a set).
//
// The note of such an item is shared with the whole band (ADR-0015), and
// band members may use different UI languages (ADR-0008). Older versions
// stored the type label of the creator's language as the note of a new
// break ("Pause" or "Break"), so a note that only repeats the type label
// in any supported language counts as no note of its own (#289): the item
// shows the label of the current language instead.

/// The label of the type of a pause or text item, e.g. "Break".
String markerTypeLabel(AppLocalizations l10n, SetItemType type) =>
    type == SetItemType.pause ? l10n.pause : l10n.textItem;

/// The type labels of pause and text items in every supported UI language,
/// in lower case.
final Map<SetItemType, Set<String>> _typeLabels = {
  for (final type in [SetItemType.pause, SetItemType.text])
    type: {
      for (final locale in AppLocalizations.supportedLocales)
        markerTypeLabel(lookupAppLocalizations(locale), type).toLowerCase(),
    },
};

/// The note of a pause or text item, or null when it has none of its own:
/// empty, or just the type label in one of the supported languages.
String? markerNote(SetItemType type, String? note) {
  final text = note?.trim() ?? '';
  if (text.isEmpty) return null;
  final labels = _typeLabels[type] ?? const {};
  return labels.contains(text.toLowerCase()) ? null : text;
}

/// What a pause or text item shows as its name: its own note, otherwise
/// the type label in the current language.
String markerTitle(AppLocalizations l10n, SetItemType type, String? note) =>
    markerNote(type, note) ?? markerTypeLabel(l10n, type);

import 'database.dart';

// Set markers (ADR-0047): breaks and texts are one kind of set item, a
// marker, made of an icon from the app's catalogue and an optional text.
//
// The icon is stored by a stable key (never a code point). Older apps only
// know the item types `pause` and `text`, so the type is still written for
// them, derived from the icon, and markers of older apps get an icon from
// their type.

/// The keys of the marker icon catalogue, in the order of the dialog.
abstract final class MarkerIcons {
  static const breakIcon = 'break';
  static const drinks = 'drinks';
  static const announcement = 'announcement';
  static const microphone = 'microphone';
  static const guest = 'guest';
  static const encore = 'encore';
  static const transition = 'transition';
  static const solo = 'solo';
  static const applause = 'applause';
  static const instrument = 'instrument';
  static const tuning = 'tuning';
  static const click = 'click';
  static const light = 'light';
  static const effects = 'effects';
  static const celebration = 'celebration';
  static const info = 'info';
  static const warning = 'warning';

  /// Every key of the catalogue.
  static const all = [
    breakIcon,
    drinks,
    announcement,
    microphone,
    guest,
    encore,
    transition,
    solo,
    applause,
    instrument,
    tuning,
    click,
    light,
    effects,
    celebration,
    info,
    warning,
  ];

  /// The icons of the *Break* group: written as `pause` for older apps.
  static const breakGroup = {breakIcon, drinks};

  /// The icon of a new marker when none is chosen.
  static const defaultIcon = breakIcon;

  /// The longest text of a marker (ADR-0047); longer notes of older apps
  /// are kept and shortened on display.
  static const maxTextLength = 24;

  /// Whether [icon] is a break, as older apps see it.
  static bool isBreak(String? icon) => breakGroup.contains(icon);

  /// The item type older apps read for a marker with [icon].
  static String legacyType(String? icon) => isBreak(icon) ? 'pause' : 'text';

  /// The icon of a marker of an older app, from its item [type].
  static String fromLegacyType(Object? type) =>
      type == 'pause' ? breakIcon : announcement;
}

/// The stored form of a set item's type and icon, as read from the server or
/// an archive: `song` stays a song; any other type is a marker, whose icon
/// is [icon] or, for markers of older apps, follows from the type.
({SetItemType type, String? icon}) readItemType(Object? type, Object? icon) {
  if (type == 'song') return (type: SetItemType.song, icon: null);
  return (
    type: SetItemType.marker,
    icon: icon is String && icon.isNotEmpty
        ? icon
        : MarkerIcons.fromLegacyType(type),
  );
}

/// The item type written to the server or an archive: `song`, or for a
/// marker the type older apps read (`pause` or `text`).
String writeItemType(SetItemType type, String? icon) =>
    type == SetItemType.song ? 'song' : MarkerIcons.legacyType(icon);

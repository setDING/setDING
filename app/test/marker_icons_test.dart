import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/data/database.dart';
import 'package:setding/data/marker_icons.dart';
import 'package:setding/l10n/generated/app_localizations.dart';
import 'package:setding/sync/sync_backend.dart';
import 'package:setding/ui/sets/set_item_label.dart';

/// Set markers with an icon from the catalogue (ADR-0047).
void main() {
  test('every icon of the catalogue has a short name in every language', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = lookupAppLocalizations(locale);
      final names = <String>{};
      for (final key in MarkerIcons.all) {
        final name = markerIconName(l10n, key);
        expect(
          name.length,
          lessThanOrEqualTo(MarkerIcons.maxTextLength),
          reason: '$locale $key',
        );
        // Unique, so a key without a name of its own (the generic name of
        // the info icon) is found.
        expect(names.add(name.toLowerCase()), isTrue, reason: '$locale $name');
        expect(markerIconData(key), isNot(Icons.label_outline), reason: key);
      }
    }
  });

  test('the type older apps read follows from the icon', () {
    expect(writeItemType(SetItemType.song, null), 'song');
    expect(writeItemType(SetItemType.marker, MarkerIcons.breakIcon), 'pause');
    expect(writeItemType(SetItemType.marker, MarkerIcons.drinks), 'pause');
    expect(writeItemType(SetItemType.marker, MarkerIcons.encore), 'text');
    expect(writeItemType(SetItemType.marker, 'from-a-newer-app'), 'text');
  });

  test('markers of older apps get an icon from their type', () {
    expect(readItemType('song', null), (type: SetItemType.song, icon: null));
    expect(readItemType('pause', null), (
      type: SetItemType.marker,
      icon: MarkerIcons.breakIcon,
    ));
    expect(readItemType('text', ''), (
      type: SetItemType.marker,
      icon: MarkerIcons.announcement,
    ));
    expect(readItemType('text', MarkerIcons.encore), (
      type: SetItemType.marker,
      icon: MarkerIcons.encore,
    ));
    // A song never has an icon.
    expect(readItemType('song', MarkerIcons.encore).icon, isNull);
  });

  test('the server item keeps the icon, also one this version does not '
      'know', () {
    final legacy = RemoteSetItem.fromJson({
      'id': 'i1',
      'type': 'pause',
      'note': 'Pause',
    });
    expect(
      (legacy.type, legacy.icon),
      (SetItemType.marker, MarkerIcons.breakIcon),
    );
    // Sent back with the icon, so the server keeps it (ADR-0047).
    expect(legacy.toJson(), {
      'id': 'i1',
      'type': 'pause',
      'note': 'Pause',
      'icon': 'break',
    });

    final json = {'id': 'i2', 'type': 'text', 'icon': 'from-a-newer-app'};
    final newer = RemoteSetItem.fromJson(json);
    expect(newer.icon, 'from-a-newer-app');
    expect(newer.extra, isEmpty);
    expect(newer.toJson(), json);

    final encore = RemoteSetItem.fromJson({
      'id': 'i3',
      'type': 'text',
      'icon': 'encore',
    });
    expect(encore.toJson()['type'], 'text');
  });
}

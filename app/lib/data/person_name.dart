import 'package:flutter/foundation.dart';

import 'database.dart';

/// How the names of people are shown in lists (ADR-0062); a personal
/// setting of the viewer.
enum NameFormat {
  /// The nickname, otherwise "First Last" (the default).
  nickname,

  /// "First Last".
  firstLast,

  /// "Last First"; lists are sorted by the last name.
  lastFirst,

  /// "First Last (Nickname)".
  fullWithNickname,
}

/// The name of a person (ADR-0062): first and last name are required for
/// accounts, the nickname is optional. [fallback] is the single name of
/// older servers and of accounts before the split, shown when first and
/// last name are unknown.
@immutable
class PersonName {
  const PersonName({
    this.firstName = '',
    this.lastName = '',
    this.nickname = '',
    this.fallback = '',
  });

  final String firstName;
  final String lastName;
  final String nickname;
  final String fallback;

  String get _first => firstName.trim();
  String get _last => lastName.trim();
  String get _nick => nickname.trim();

  /// First and last name are both known.
  bool get complete => _first.isNotEmpty && _last.isNotEmpty;

  /// "First Last", or the parts that are known; [fallback] without either.
  String get fullName {
    final full = [_first, _last].where((s) => s.isNotEmpty).join(' ');
    return full.isNotEmpty ? full : fallback.trim();
  }

  /// No name at all (callers show the email address instead).
  bool get isEmpty => fullName.isEmpty && _nick.isEmpty;

  /// The name as [format] shows it; every format falls back to what is
  /// known, so a person without a nickname is shown with the full name.
  String format(NameFormat format) {
    final full = fullName;
    switch (format) {
      case NameFormat.nickname:
        return _nick.isNotEmpty ? _nick : full;
      case NameFormat.firstLast:
        return full.isNotEmpty ? full : _nick;
      case NameFormat.lastFirst:
        final reversed = [_last, _first].where((s) => s.isNotEmpty).join(' ');
        if (reversed.isNotEmpty) return reversed;
        return full.isNotEmpty ? full : _nick;
      case NameFormat.fullWithNickname:
        if (full.isEmpty) return _nick;
        if (_nick.isEmpty || _nick == full) return full;
        return '$full ($_nick)';
    }
  }

  /// The key lists of people are sorted by: the shown name, except for
  /// [NameFormat.lastFirst], which sorts by last name, then first name.
  String sortKey(NameFormat format) => this.format(format).toLowerCase();

  /// Whether [query] (case-insensitive, every word) matches the first name,
  /// the last name, the nickname or the fallback name.
  bool matches(String query) {
    final words = query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty);
    final haystack = [
      firstName,
      lastName,
      nickname,
      fallback,
    ].join(' ').toLowerCase();
    return words.every(haystack.contains);
  }

  @override
  bool operator ==(Object other) =>
      other is PersonName &&
      other.firstName == firstName &&
      other.lastName == lastName &&
      other.nickname == nickname &&
      other.fallback == fallback;

  @override
  int get hashCode => Object.hash(firstName, lastName, nickname, fallback);
}

/// The name of a band member as cached on the device.
extension MembershipName on MembershipEntry {
  PersonName get person => PersonName(
    firstName: userFirstName,
    lastName: userLastName,
    nickname: userNickname,
    fallback: userName,
  );
}

/// The name of a person of an organization as cached on the device.
extension OrgMembershipName on OrgMembershipEntry {
  PersonName get person => PersonName(
    firstName: userFirstName,
    lastName: userLastName,
    nickname: userNickname,
    fallback: userName,
  );
}

/// [people] sorted by role (as the database stores it: by name), then by
/// [person] in [format] (ADR-0062).
List<T> sortedPeople<T>(
  List<T> people,
  NameFormat format, {
  required String Function(T) role,
  required PersonName Function(T) person,
}) {
  final keys = {for (final p in people) p: person(p).sortKey(format)};
  return [...people]..sort((a, b) {
    final r = role(a).compareTo(role(b));
    return r != 0 ? r : keys[a]!.compareTo(keys[b]!);
  });
}

/// The name of a person as [format] shows it, or [email] (then `?`) for a
/// person without a name.
String personLabel(PersonName name, NameFormat format, {String? email}) {
  final shown = name.format(format);
  if (shown.isNotEmpty) return shown;
  return (email == null || email.isEmpty) ? '?' : email;
}

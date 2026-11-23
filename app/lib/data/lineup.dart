import 'package:flutter/foundation.dart';

import 'database.dart';
import 'set_repository.dart' show plannedFor;

/// A person in a set's lineup (ADR-0061).
@immutable
class LineupPerson {
  const LineupPerson({
    required this.userId,
    required this.name,
    required this.substitute,
  });

  final String userId;
  final String name;

  /// Not a member of the set's band: a person of the organization who helps
  /// out for this set.
  final bool substitute;

  @override
  bool operator ==(Object other) =>
      other is LineupPerson &&
      other.userId == userId &&
      other.name == name &&
      other.substitute == substitute;

  @override
  int get hashCode => Object.hash(userId, name, substitute);
}

/// The lineup of a set as the UI shows it (ADR-0061).
@immutable
class SetLineup {
  const SetLineup({
    required this.people,
    required this.custom,
    required this.plannedForMe,
  });

  /// The people who play the set: band members first, then substitutes,
  /// each by name. People this device does not know (e.g. who left the
  /// organization) are left out.
  final List<LineupPerson> people;

  /// The set has a lineup of its own; otherwise the whole band plays it.
  final bool custom;

  /// The signed-in user plays the set ([plannedFor]).
  final bool plannedForMe;

  /// The user IDs of [people].
  List<String> get userIds => [for (final p in people) p.userId];
}

/// Resolves the lineup of [set] with the names of the band's [members] and
/// the organization's [orgMembers]; [userId] is the signed-in user.
SetLineup resolveLineup(
  SetlistEntry set, {
  required List<MembershipEntry> members,
  required List<OrgMembershipEntry> orgMembers,
  required String? userId,
}) {
  final band = {for (final m in members) m.userId: m.userName};
  final org = {for (final m in orgMembers) m.userId: m.userName};
  int byName(LineupPerson a, LineupPerson b) =>
      a.name.toLowerCase().compareTo(b.name.toLowerCase());
  final people = <LineupPerson>[];
  if (set.lineupCustom) {
    for (final id in set.lineup) {
      final name = band[id] ?? org[id];
      if (name == null) continue;
      people.add(
        LineupPerson(userId: id, name: name, substitute: !band.containsKey(id)),
      );
    }
  } else {
    for (final MapEntry(:key, :value) in band.entries) {
      people.add(LineupPerson(userId: key, name: value, substitute: false));
    }
  }
  people.sort((a, b) {
    if (a.substitute != b.substitute) return a.substitute ? 1 : -1;
    return byName(a, b);
  });
  return SetLineup(
    people: people,
    custom: set.lineupCustom,
    plannedForMe: plannedFor(
      set,
      userId: userId,
      bandMember: userId != null && band.containsKey(userId),
    ),
  );
}

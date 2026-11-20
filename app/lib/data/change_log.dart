import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import 'database.dart';

/// How long entries of the change log are kept (ADR-0045).
const changeLogRetention = Duration(days: 30);

/// What changed in an entry of the change log (ADR-0045), stored as JSON
/// in `change_log.details`.
@immutable
class ChangeDetails {
  const ChangeDetails({
    this.text = false,
    this.pdf = false,
    this.added = 0,
    this.removed = 0,
    this.sequences = const [],
  });

  /// Reads stored details; unknown or broken values are left out.
  factory ChangeDetails.fromJson(String json) {
    final Map<String, Object?> data;
    try {
      final decoded = jsonDecode(json);
      if (decoded is! Map<String, Object?>) return const ChangeDetails();
      data = decoded;
    } on FormatException {
      return const ChangeDetails();
    }
    int count(String key) => switch (data[key]) {
      final int n when n > 0 => n,
      _ => 0,
    };
    return ChangeDetails(
      text: data['text'] == true,
      pdf: data['pdf'] == true,
      added: count('added'),
      removed: count('removed'),
      sequences: [
        if (data['sequences'] case final List<Object?> list)
          for (final s in list)
            if (s is String) s,
      ],
    );
  }

  /// A song: its ChordPro text changed.
  final bool text;

  /// A song: a PDF attachment was added, replaced or removed.
  final bool pdf;

  /// A set: songs added and removed.
  final int added;
  final int removed;

  /// A set: titles of the songs whose sequence changed, of a set item or
  /// of the band's arrangement.
  final List<String> sequences;

  bool get isEmpty =>
      !text && !pdf && added == 0 && removed == 0 && sequences.isEmpty;

  /// Both changes together, e.g. two syncs of the same set.
  ChangeDetails merge(ChangeDetails other) => ChangeDetails(
    text: text || other.text,
    pdf: pdf || other.pdf,
    added: added + other.added,
    removed: removed + other.removed,
    sequences: {...sequences, ...other.sequences}.toList(),
  );

  String toJson() => jsonEncode({
    if (text) 'text': true,
    if (pdf) 'pdf': true,
    if (added > 0) 'added': added,
    if (removed > 0) 'removed': removed,
    if (sequences.isNotEmpty) 'sequences': sequences,
  });

  @override
  bool operator ==(Object other) =>
      other is ChangeDetails &&
      other.text == text &&
      other.pdf == pdf &&
      other.added == added &&
      other.removed == removed &&
      listEquals(other.sequences, sequences);

  @override
  int get hashCode =>
      Object.hash(text, pdf, added, removed, Object.hashAll(sequences));

  @override
  String toString() => 'ChangeDetails(${toJson()})';
}

/// One entry of the recent changes (ADR-0045): all changes of one song or
/// set together, with the person and the time of the newest one.
@immutable
class RecentChange {
  const RecentChange({
    required this.kind,
    required this.recordId,
    required this.title,
    required this.at,
    this.userId,
    this.details = const ChangeDetails(),
  });

  final ChangeKind kind;
  final String recordId;
  final String title;
  final DateTime at;
  final String? userId;
  final ChangeDetails details;
}

/// Groups log rows (newest first) to one entry per song or set: a song
/// that is new and was changed afterwards stays a new song.
List<RecentChange> groupChanges(List<ChangeLogRow> rows) {
  final byRecord = <String, RecentChange>{};
  for (final row in rows) {
    final details = ChangeDetails.fromJson(row.details);
    final key =
        '${row.kind == ChangeKind.setChanged ? 'set' : 'song'}:'
        '${row.recordId}';
    final newer = byRecord[key];
    if (newer == null) {
      byRecord[key] = RecentChange(
        kind: row.kind,
        recordId: row.recordId,
        title: row.title,
        at: row.at,
        userId: row.userId,
        details: details,
      );
      continue;
    }
    byRecord[key] = RecentChange(
      kind: row.kind == ChangeKind.songAdded ? row.kind : newer.kind,
      recordId: newer.recordId,
      title: newer.title,
      at: newer.at,
      userId: newer.userId,
      details: details.merge(newer.details),
    );
  }
  return byRecord.values.toList();
}

/// The change log on this device (ADR-0045): written by the sync engine,
/// read by the overview.
class ChangeLogRepository {
  ChangeLogRepository(this.db);

  final AppDatabase db;

  Future<void> add({
    required ChangeKind kind,
    required String scopeId,
    required String recordId,
    required String title,
    String? userId,
    ChangeDetails details = const ChangeDetails(),
    DateTime? at,
  }) => db
      .into(db.changeLog)
      .insert(
        ChangeLogCompanion.insert(
          at: at ?? DateTime.now(),
          kind: kind,
          scopeId: scopeId,
          recordId: recordId,
          title: title,
          userId: Value(userId),
          details: Value(details.toJson()),
        ),
      );

  /// Removes the entries older than [changeLogRetention].
  Future<int> prune({DateTime? now}) {
    final limit = (now ?? DateTime.now()).subtract(changeLogRetention);
    return (db.delete(
      db.changeLog,
    )..where((c) => c.at.isSmallerThanValue(limit))).go();
  }

  /// The changes in [scopeIds] (a band and its organization) after
  /// [since] (all if null), one per song or set, newest first.
  Stream<List<RecentChange>> watch(List<String> scopeIds, {DateTime? since}) {
    final query = db.select(db.changeLog)
      ..where(
        (c) =>
            c.scopeId.isIn(scopeIds) &
            (since == null
                ? const Constant(true)
                : c.at.isBiggerThanValue(since)),
      )
      ..orderBy([
        (c) => OrderingTerm.desc(c.at),
        (c) => OrderingTerm.desc(c.id),
      ]);
    return query.watch().map(groupChanges);
  }
}

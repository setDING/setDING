import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Severity of a [LogEntry].
enum LogLevel { info, warning, error }

/// One message of the app's diagnostic log.
@immutable
class LogEntry {
  const LogEntry(this.time, this.level, this.name, this.message);

  final DateTime time;
  final LogLevel level;

  /// Area of the app, e.g. `sync`.
  final String name;
  final String message;

  @override
  String toString() =>
      '${time.toIso8601String()} ${level.name.toUpperCase()} [$name] $message';
}

/// A named logger. Messages go to the console (also in release builds,
/// e.g. Android logcat), to the Dart developer log, and to a small buffer
/// of recent entries that the settings can copy for support.
class Log {
  const Log(this.name);

  final String name;

  /// Number of entries kept in [recent].
  static const capacity = 300;
  static final _recent = <LogEntry>[];

  /// The recent entries, oldest first.
  static List<LogEntry> get recent => List.unmodifiable(_recent);

  /// The recent entries as text, one per line.
  static String export() => _recent.join('\n');

  @visibleForTesting
  static void clear() => _recent.clear();

  void info(String message) => _write(LogLevel.info, message);

  void warning(String message, [Object? error]) =>
      _write(LogLevel.warning, error == null ? message : '$message: $error');

  void error(String message, [Object? error, StackTrace? stackTrace]) => _write(
    LogLevel.error,
    error == null ? message : '$message: $error',
    stackTrace,
  );

  void _write(LogLevel level, String message, [StackTrace? stackTrace]) {
    final entry = LogEntry(DateTime.now(), level, name, message);
    _recent.add(entry);
    if (_recent.length > capacity) _recent.removeAt(0);
    developer.log(
      message,
      name: 'setding.$name',
      level: switch (level) {
        LogLevel.info => 800,
        LogLevel.warning => 900,
        LogLevel.error => 1000,
      },
      stackTrace: stackTrace,
    );
    debugPrint(entry.toString());
  }
}

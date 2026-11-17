// Host side of `make perf`: writes the timeline summaries that
// integration_test/performance_test.dart reports to build/perf/.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart' as driver;
import 'package:integration_test/integration_test_driver.dart';

/// Events of the VM's timeline ring buffer; a part close to it may have lost
/// its beginning.
const _ringBufferEvents = 32000;

Future<void> main() => integrationDriver(
  responseDataCallback: (data) async {
    if (data == null) return;
    final dir = Directory('build/perf')..createSync(recursive: true);
    // Scenarios are recorded in parts (`key#1`, `key#2`, …): joined here.
    final scenarios = <String, List<Object?>>{};
    for (final MapEntry(:key, :value) in data.entries) {
      if (key == 'memory') {
        File(
          '${dir.path}/memory.json',
        ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(value));
        continue;
      }
      final events = (value as Map<String, dynamic>)['traceEvents'] as List;
      if (events.length >= _ringBufferEvents) {
        stderr.writeln(
          'perf: $key has ${events.length} timeline events, '
          'its beginning may be lost (record it in smaller parts)',
        );
      }
      scenarios.putIfAbsent(key.split('#').first, () => []).addAll(events);
    }
    for (final MapEntry(:key, :value) in scenarios.entries) {
      final timeline = driver.Timeline.fromJson({'traceEvents': value});
      final summary = driver.TimelineSummary.summarize(timeline);
      await summary.writeTimelineToFile(
        key,
        destinationDirectory: dir.path,
        pretty: true,
        includeSummary: true,
      );
    }
  },
);

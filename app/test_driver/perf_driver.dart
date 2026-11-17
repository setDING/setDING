// Host side of `make perf`: writes the timeline summaries that
// integration_test/performance_test.dart reports to build/perf/.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart' as driver;
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
  responseDataCallback: (data) async {
    if (data == null) return;
    final dir = Directory('build/perf')..createSync(recursive: true);
    for (final MapEntry(:key, :value) in data.entries) {
      if (key == 'memory') {
        File(
          '${dir.path}/memory.json',
        ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(value));
        continue;
      }
      final timeline = driver.Timeline.fromJson(value as Map<String, dynamic>);
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

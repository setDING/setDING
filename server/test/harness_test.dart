import 'dart:async';
import 'dart:io';

import 'package:setding_server/pocketbase_harness.dart';
import 'package:test/test.dart';

/// The test harness itself (`lib/pocketbase_harness.dart`).
void main() {
  // Other test files write into the shared `server/pb_hooks` while this one
  // runs (compat_test.dart stamps `setding-version.txt`). A `migrate down`
  // that watched the hooks directory restarted and cancelled itself
  // (issue #1240).
  test(
    'a downgrade is not cancelled by a change in pb_hooks (#1240)',
    () async {
      final probe = File('../server/pb_hooks/harness-probe-$pid.txt');
      var pb = await PocketBase.start();
      var n = 0;
      final writer = Timer.periodic(
        const Duration(milliseconds: 100),
        (_) => probe.writeAsStringSync('${n++}\n'),
      );
      try {
        pb = await pb.downgrade('1795800000_invite_token.js');
      } finally {
        writer.cancel();
        if (probe.existsSync()) probe.deleteSync();
        await pb.stop();
      }
    },
  );
}

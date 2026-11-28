import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../sync/sync_backend.dart';
import '../sync/sync_controller.dart';
import 'band_providers.dart';

/// The storage organization [orgId] uses on the server and its limit
/// (ADR-0070), fetched again after every sync; null offline, for people who
/// may not upload PDFs and on servers without a storage route.
final orgStorageProvider = FutureProvider.autoDispose
    .family<OrgStorage?, String>((ref, orgId) async {
      ref.watch(syncControllerProvider.select((s) => s.lastReport));
      try {
        return await ref.read(bandServiceProvider).orgStorage(orgId);
      } on BackendException {
        return null;
      }
    });

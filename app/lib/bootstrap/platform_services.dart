/// Opens what the app needs from the platform: database, attachment storage
/// and session store (ADR-0018: native apps and the web client differ here,
/// everything above is shared).
library;

import '../data/attachment_storage.dart';
import '../data/database.dart';
import '../sync/session_store.dart';

export 'platform_services_web.dart'
    if (dart.library.io) 'platform_services_io.dart';

/// Platform-specific services, opened once at startup.
typedef PlatformServices = ({
  AppDatabase db,
  AttachmentStorage storage,
  SessionStore sessionStore,
});

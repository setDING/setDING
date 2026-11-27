/// The token of the projection address kept per device (ADR-0068 §2,
/// #1183), so the browser at the projector and an OBS source keep working;
/// renewed on demand.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../settings/settings.dart' show sharedPreferencesProvider;
import 'projection_token.dart';

/// The token of this device, stored locally and never synced: it opens the
/// projection, which is no business of other devices.
class ProjectionTokenStore {
  ProjectionTokenStore(this._prefs);

  static const key = 'projectionToken';

  final SharedPreferences _prefs;

  /// The token of this device, created on first use.
  String get token {
    final stored = _prefs.getString(key);
    if (isProjectionToken(stored)) return stored!;
    return renew();
  }

  /// Replaces the token: links with the old one stop working.
  String renew() {
    final token = newProjectionToken();
    _prefs.setString(key, token);
    return token;
  }
}

final projectionTokenProvider = Provider<ProjectionTokenStore>(
  (ref) => ProjectionTokenStore(ref.read(sharedPreferencesProvider)),
);

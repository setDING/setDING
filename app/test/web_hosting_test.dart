import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:setding/settings/settings.dart';
import 'package:setding/sync/sync_backend.dart';

/// The web client is served by the same PocketBase as the API (ADR-0018).
void main() {
  test('the web client talks to the server it was loaded from', () {
    expect(
      initialServerUrl(
        web: true,
        page: Uri.parse('https://app.setding.app/invite/abc'),
        configured: '',
      ),
      'https://app.setding.app',
    );
    expect(
      initialServerUrl(
        web: true,
        page: Uri.parse('http://127.0.0.1:8090/'),
        configured: '',
      ),
      'http://127.0.0.1:8090',
    );
  });

  test('the apps use the default server', () {
    expect(initialServerUrl(web: false, configured: ''), defaultServerUrl);
  });

  test('a server given at build time wins', () {
    expect(
      initialServerUrl(
        web: true,
        page: Uri.parse('http://localhost:5555/'),
        configured: 'http://127.0.0.1:8090',
      ),
      'http://127.0.0.1:8090',
    );
  });

  test('invitation links of the web client carry the token', () {
    const token = 'AbCdEfGhIjKlMnOpQrStUv12';
    expect(inviteTokenFrom('https://app.setding.app/invite/$token'), token);
  });

  test('the web client loads the audio engine of the click', () {
    // Without this script SoLoud cannot start in the browser (ADR-0026).
    expect(
      File('web/index.html').readAsStringSync(),
      contains(
        '<script src="assets/packages/flutter_soloud/web/init_soloud.js" '
        'defer></script>',
      ),
    );
  });
}

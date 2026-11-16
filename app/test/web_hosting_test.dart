import 'package:flutter_test/flutter_test.dart';
import 'package:realchord/settings/settings.dart';
import 'package:realchord/sync/sync_backend.dart';

/// The web client is served by the same PocketBase as the API (ADR-0018).
void main() {
  test('the web client talks to the server it was loaded from', () {
    expect(
      initialServerUrl(
        web: true,
        page: Uri.parse('https://app.realchord.app/invite/abc'),
        configured: '',
      ),
      'https://app.realchord.app',
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
    expect(inviteTokenFrom('https://app.realchord.app/invite/$token'), token);
  });
}

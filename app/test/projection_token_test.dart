import 'package:flutter_test/flutter_test.dart';
import 'package:setding/projection/projection_token.dart';
import 'package:setding/projection/projection_token_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The projection address kept per device (ADR-0068 §2, #1183).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('tokens are 128 random bits, URL-safe', () {
    final a = newProjectionToken(), b = newProjectionToken();
    expect(isProjectionToken(a), isTrue);
    expect(a, isNot(b));
    for (final bad in [null, '', 'short', '${a}x', 'a' * 21 + '/']) {
      expect(isProjectionToken(bad), isFalse, reason: '$bad');
    }
  });

  test(
    'the same token until renewed, also after a restart of the app',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = ProjectionTokenStore(prefs);
      final first = store.token;
      expect(store.token, first);
      expect(ProjectionTokenStore(prefs).token, first, reason: 'restarted');
      final renewed = store.renew();
      expect(renewed, isNot(first));
      expect(store.token, renewed);
      expect(prefs.getString(ProjectionTokenStore.key), renewed);
    },
  );

  test('a damaged stored token is replaced', () async {
    SharedPreferences.setMockInitialValues({
      ProjectionTokenStore.key: 'not a token',
    });
    final store = ProjectionTokenStore(await SharedPreferences.getInstance());
    expect(isProjectionToken(store.token), isTrue);
  });
}

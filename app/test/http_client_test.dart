import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/io_client.dart';
import 'package:setding/platform/http_client_io.dart';

/// The DER bytes of a PEM certificate.
List<int> _der(String pem) => base64.decode(
  pem.split('\n').where((l) => l.isNotEmpty && !l.startsWith('-----')).join(),
);

void main() {
  test('bundles the ISRG roots X1 and X2 as valid certificates', () {
    expect(bundledRootCertificates, [isrgRootX1, isrgRootX2]);
    for (final (pem, name) in [
      (isrgRootX1, 'ISRG Root X1'),
      (isrgRootX2, 'ISRG Root X2'),
    ]) {
      // Only the bundled certificate: parsing it must succeed.
      SecurityContext(withTrustedRoots: false)
          .setTrustedCertificatesBytes(pem.codeUnits);
      expect(latin1.decode(_der(pem)), contains(name));
    }
  });

  test('adds the bundled roots to the system roots without failing', () {
    // The roots are usually among the system roots already (Linux test
    // machine); adding them again must not throw.
    expect(bundledRootsContext, returnsNormally);
  });

  test('uses an IOClient with the bundled roots on Windows', () {
    final client = createHttpClient(windows: true);
    addTearDown(client.close);
    expect(client, isA<IOClient>());
  });
}

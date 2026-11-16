import 'package:flutter_test/flutter_test.dart';
import 'package:realchord/ui/live/pdf_spread_view.dart';

/// Turning spreads of two PDF pages in landscape (ADR-0009).
void main() {
  test('does not turn without a document', () {
    final c = PdfSpreadController();
    expect(c.isReady, isFalse);
    expect(c.next(), isFalse);
    expect(c.previous(), isFalse);
    expect(c.firstPage, 1);
  });
}

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setding/ui/live/song_page_controller.dart';

// The page controller of live mode, extracted from live_screen.dart (#1202).
void main() {
  testWidgets('turns within the pages it was attached with', (tester) async {
    final pages = SongPageController();
    addTearDown(pages.dispose);
    var notified = 0;
    pages.addListener(() => notified++);

    pages.attach(3, sections: const [0, 10, null]);
    await tester.pumpWidget(const SizedBox());
    expect(notified, 1, reason: 'told after the frame');
    expect(pages.count, 3);
    expect(pages.section, 0);

    expect(pages.previous(), isFalse);
    expect(pages.next(), isTrue);
    expect(pages.section, 10);
    expect(pages.next(), isTrue);
    expect(pages.section, isNull);
    expect(pages.next(), isFalse);
    expect(pages.page, 2);

    pages.first();
    expect(pages.page, 0);
    pages
      ..show(5)
      ..show(1);
    expect(pages.page, 1);
  });

  testWidgets('finds the page of a section and clamps on fewer pages', (
    tester,
  ) async {
    final pages = SongPageController();
    addTearDown(pages.dispose);
    pages.attach(3, sections: const [0, 10, 20]);
    expect(pages.pageOf(15), 1);
    expect(pages.pageOf(20), 2);

    pages
      ..show(2)
      ..attach(2);
    expect(pages.page, 1);
    expect(pages.pageOf(15), isNull, reason: 'no sections known');

    pages.attach(0);
    expect(pages.count, 1);
    expect(pages.page, 0);
    await tester.pumpWidget(const SizedBox());
  });
}

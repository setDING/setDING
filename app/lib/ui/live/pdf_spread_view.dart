import 'package:material_ui/material_ui.dart';
import 'package:pdfrx/pdfrx.dart';

/// Position in a PDF shown as two pages side by side (ADR-0009).
///
/// Spreads are pages 1–2, 3–4, …; a last odd page is shown alone on the
/// left. [next] and [previous] turn a whole spread and return false at the
/// end or start, so live mode moves on to the next or previous song.
class PdfSpreadController extends ChangeNotifier {
  int _first = 1;
  int _pageCount = 0;

  /// First (left) page number of the visible spread, 1-based.
  int get firstPage => _first;

  /// Number of pages; 0 while no document is shown.
  int get pageCount => _pageCount;

  bool get isReady => _pageCount > 0;

  void _attach(int pageCount) {
    _pageCount = pageCount;
    if (_first > pageCount) {
      _first = pageCount.isOdd ? pageCount : pageCount - 1;
    }
    if (_first < 1) _first = 1;
  }

  void _detach() => _pageCount = 0;

  bool next() {
    if (!isReady || _first + 2 > _pageCount) return false;
    _first += 2;
    notifyListeners();
    return true;
  }

  bool previous() {
    if (!isReady || _first <= 1) return false;
    _first -= 2;
    notifyListeners();
    return true;
  }
}

/// Shows two pages of a PDF side by side, fitted to the available space.
/// Taps are left to the live screen, which turns the spreads.
class PdfSpreadView extends StatefulWidget {
  const PdfSpreadView({
    super.key,
    required this.documentRef,
    required this.controller,
  });

  final PdfDocumentRef documentRef;
  final PdfSpreadController controller;

  @override
  State<PdfSpreadView> createState() => _PdfSpreadViewState();
}

class _PdfSpreadViewState extends State<PdfSpreadView> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  @override
  void didUpdateWidget(PdfSpreadView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller
        ..removeListener(_changed)
        .._detach();
      widget.controller.addListener(_changed);
    }
  }

  @override
  void dispose() {
    widget.controller
      ..removeListener(_changed)
      .._detach();
    super.dispose();
  }

  void _changed() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final background = Theme.of(context).colorScheme.surfaceContainerHighest;
    return ColoredBox(
      color: background,
      child: PdfDocumentViewBuilder(
        documentRef: widget.documentRef,
        loadingBuilder: (context) =>
            const Center(child: CircularProgressIndicator()),
        builder: (context, document) {
          if (document == null) return const SizedBox.expand();
          final controller = widget.controller.._attach(document.pages.length);
          final first = controller.firstPage;
          Widget page(int number) => number > document.pages.length
              ? const SizedBox.shrink()
              : PdfPageView(
                  key: ValueKey('pdf-spread-page-$number'),
                  document: document,
                  pageNumber: number,
                  alignment: number == first
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                );
          return Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: page(first)),
                const SizedBox(width: 8),
                Expanded(child: page(first + 1)),
              ],
            ),
          );
        },
      ),
    );
  }
}

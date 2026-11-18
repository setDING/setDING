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

  /// Called while the spread is built; listeners (the page hint of live
  /// mode) are told about a new page count after the frame.
  void _attach(int pageCount) {
    final changed = pageCount != _pageCount;
    _pageCount = pageCount;
    if (_first > pageCount) {
      _first = pageCount.isOdd ? pageCount : pageCount - 1;
    }
    if (_first < 1) _first = 1;
    if (changed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_disposed) notifyListeners();
      });
    }
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
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
    this.pageOverlay,
  });

  final PdfDocumentRef documentRef;
  final PdfSpreadController controller;

  /// Laid over each page, exactly on the page (e.g. freehand annotations,
  /// ADR-0032).
  final Widget Function(int pageNumber)? pageOverlay;

  @override
  State<PdfSpreadView> createState() => _PdfSpreadViewState();
}

class _PdfSpreadViewState extends State<PdfSpreadView> {
  /// The reference given to the document builder. A rebuild creates a new
  /// reference to the same file; the builder would drop the loaded document
  /// and its rendered pages for it, so the reference only changes with the
  /// document (its key).
  late PdfDocumentRef _documentRef = widget.documentRef;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  @override
  void didUpdateWidget(PdfSpreadView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.documentRef.key != _documentRef.key) {
      _documentRef = widget.documentRef;
    }
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
        documentRef: _documentRef,
        loadingBuilder: (context) =>
            const Center(child: CircularProgressIndicator()),
        builder: (context, document) {
          if (document == null) return const SizedBox.expand();
          final controller = widget.controller.._attach(document.pages.length);
          final first = controller.firstPage;
          Widget page(int number) {
            if (number > document.pages.length) return const SizedBox.shrink();
            final alignment = number == first
                ? Alignment.centerRight
                : Alignment.centerLeft;
            final view = PdfPageView(
              key: ValueKey('pdf-spread-page-$number'),
              document: document,
              pageNumber: number,
              alignment: alignment,
            );
            final overlay = widget.pageOverlay;
            if (overlay == null) return view;
            final pdfPage = document.pages[number - 1];
            return LayoutBuilder(
              builder: (context, box) => Stack(
                children: [
                  Positioned.fill(child: view),
                  Positioned.fromRect(
                    rect: fittedPageRect(
                      box.biggest,
                      pdfPage.width / pdfPage.height,
                      alignment,
                    ),
                    child: overlay(number),
                  ),
                ],
              ),
            );
          }

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

/// Where a page of [aspect] (width / height) is drawn in [box] when it is
/// fitted (contained) and aligned with [alignment].
Rect fittedPageRect(Size box, double aspect, Alignment alignment) {
  final size = box.width / box.height > aspect
      ? Size(box.height * aspect, box.height)
      : Size(box.width, box.width / aspect);
  return alignment.inscribe(size, Offset.zero & box);
}

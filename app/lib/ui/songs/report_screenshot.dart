import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/annotation.dart';
import '../../data/database.dart';
import '../../data/song_providers.dart';
import '../../data/song_review.dart';
import '../../l10n/generated/app_localizations.dart';
import '../annotations/annotation_paint.dart';
import '../annotations/annotation_placement.dart';

/// Longest side of a report's screenshot in pixels (ADR-0060).
const maxScreenshotSide = 1600.0;

/// Takes what the person sees inside the [RepaintBoundary] with [key] as an
/// image, at most [maxScreenshotSide] on the longer side (ADR-0060); null
/// when there is nothing to take.
Future<ui.Image?> captureView(GlobalKey key) async {
  final boundary = key.currentContext?.findRenderObject();
  if (boundary is! RenderRepaintBoundary || !boundary.hasSize) return null;
  final size = boundary.size;
  final longest = math.max(size.width, size.height);
  if (longest <= 0) return null;
  final view = ui.PlatformDispatcher.instance.implicitView;
  final device = view?.devicePixelRatio ?? 1.0;
  final ratio = math.min(device, maxScreenshotSide / longest);
  return boundary.toImage(pixelRatio: ratio);
}

/// [image] with [strokes] (in the image's coordinates, see [_Marking]) as a
/// PNG of at most [maxScreenshotBytes]: scaled down until it fits.
Future<Uint8List> encodeScreenshot(
  ui.Image image,
  List<PlacedStroke> strokes,
) async {
  var scale = 1.0;
  while (true) {
    final width = math.max(1, (image.width * scale).round());
    final height = math.max(1, (image.height * scale).round());
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(scale);
    canvas.drawImage(image, Offset.zero, Paint());
    // Highlighters below the pen, as in the annotations (ADR-0032).
    for (final highlighters in [true, false]) {
      paintStrokes(
        canvas,
        strokes,
        brightness: Brightness.light,
        highlighters: highlighters,
      );
    }
    final picture = recorder.endRecording();
    final out = await picture.toImage(width, height);
    picture.dispose();
    final data = await out.toByteData(format: ui.ImageByteFormat.png);
    out.dispose();
    final bytes = data!.buffer.asUint8List();
    // Small enough, or as small as it gets.
    if (bytes.length <= maxScreenshotBytes || (width == 1 && height == 1)) {
      return bytes;
    }
    scale *= 0.75;
  }
}

/// Lets the person mark the place in a screenshot with the pen or the
/// highlighter of the annotations (ADR-0032, ADR-0060) and returns the
/// marked screenshot as a PNG, or null when cancelled.
Future<Uint8List?> markScreenshot(BuildContext context, ui.Image image) =>
    Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _MarkingScreen(image: image),
      ),
    );

class _MarkingScreen extends StatefulWidget {
  const _MarkingScreen({required this.image});

  final ui.Image image;

  @override
  State<_MarkingScreen> createState() => _MarkingScreenState();
}

class _MarkingScreenState extends State<_MarkingScreen> {
  /// Strokes in the coordinates of the image.
  final _strokes = <PlacedStroke>[];
  List<Offset>? _current;
  var _tool = AnnotationTool.pen;
  var _saving = false;

  /// Red for the pen, orange for the highlighter (palette indexes).
  int get _color => _tool == AnnotationTool.pen ? 0 : 3;
  double get _width =>
      widget.image.width * (_tool == AnnotationTool.pen ? 0.006 : 0.03);

  PlacedStroke _placed(List<Offset> points) => PlacedStroke(
    stroke: AnnotationStroke(
      id: '${_strokes.length}',
      tool: _tool,
      color: _color,
      width: 0,
      points: const [],
    ),
    points: points,
    width: _width,
  );

  Future<void> _done() async {
    setState(() => _saving = true);
    final bytes = await encodeScreenshot(widget.image, _strokes);
    if (mounted) Navigator.pop(context, bytes);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final image = widget.image;
    final imageSize = Size(image.width.toDouble(), image.height.toDouble());
    return Scaffold(
      key: const Key('screenshot-marking'),
      appBar: AppBar(
        title: Text(l10n.screenshotMarkTitle),
        actions: [
          IconButton(
            key: const Key('screenshot-undo'),
            tooltip: l10n.undo,
            icon: const Icon(Icons.undo),
            onPressed: _strokes.isEmpty
                ? null
                : () => setState(_strokes.removeLast),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: FilledButton(
              key: const Key('screenshot-done'),
              onPressed: _saving ? null : _done,
              child: Text(l10n.screenshotAttach),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: SegmentedButton<AnnotationTool>(
              segments: [
                ButtonSegment(
                  value: AnnotationTool.pen,
                  icon: const Icon(Icons.edit),
                  label: Text(l10n.annotationPen),
                ),
                ButtonSegment(
                  value: AnnotationTool.highlighter,
                  icon: const Icon(Icons.highlight),
                  label: Text(l10n.annotationHighlighter),
                ),
              ],
              selected: {_tool},
              onSelectionChanged: (s) => setState(() => _tool = s.single),
            ),
          ),
          Text(
            l10n.screenshotMarkHint,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Center(
              child: FittedBox(
                child: SizedBox.fromSize(
                  size: imageSize,
                  child: GestureDetector(
                    key: const Key('screenshot-canvas'),
                    onPanStart: (d) =>
                        setState(() => _current = [d.localPosition]),
                    onPanUpdate: (d) =>
                        setState(() => _current?.add(d.localPosition)),
                    onPanEnd: (_) => setState(() {
                      if (_current case final points?) {
                        _strokes.add(_placed(points));
                      }
                      _current = null;
                    }),
                    child: CustomPaint(
                      painter: _MarkingPainter(
                        image: image,
                        strokes: [
                          ..._strokes,
                          if (_current case final points?) _placed(points),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MarkingPainter extends CustomPainter {
  _MarkingPainter({required this.image, required this.strokes});

  final ui.Image image;
  final List<PlacedStroke> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImage(image, Offset.zero, Paint());
    for (final highlighters in [true, false]) {
      paintStrokes(
        canvas,
        strokes,
        brightness: Brightness.light,
        highlighters: highlighters,
      );
    }
  }

  @override
  bool shouldRepaint(_MarkingPainter old) => true;
}

/// A small preview of a report's screenshot (ADR-0060), loaded (and
/// downloaded once) when shown; a tap shows it full size.
class ReportScreenshotThumbnail extends ConsumerStatefulWidget {
  const ReportScreenshotThumbnail({super.key, required this.report});

  final SongReportRow report;

  @override
  ConsumerState<ReportScreenshotThumbnail> createState() =>
      _ReportScreenshotThumbnailState();
}

class _ReportScreenshotThumbnailState
    extends ConsumerState<ReportScreenshotThumbnail> {
  late Future<Uint8List?> _bytes = _load();

  Future<Uint8List?> _load() =>
      ref.read(songReviewRepositoryProvider).screenshot(widget.report);

  @override
  void didUpdateWidget(ReportScreenshotThumbnail old) {
    super.didUpdateWidget(old);
    if (old.report.remoteScreenshot != widget.report.remoteScreenshot ||
        old.report.screenshotFile != widget.report.screenshotFile) {
      _bytes = _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FutureBuilder<Uint8List?>(
      future: _bytes,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null) {
          return Text(
            snapshot.connectionState == ConnectionState.done
                ? l10n.screenshotUnavailable
                : l10n.screenshotLoading,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          );
        }
        return Tooltip(
          message: l10n.screenshotShow,
          child: InkWell(
            key: const Key('report-screenshot'),
            onTap: () => showDialog<void>(
              context: context,
              builder: (context) =>
                  Dialog(child: InteractiveViewer(child: Image.memory(bytes))),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(bytes, height: 96, fit: BoxFit.contain),
            ),
          ),
        );
      },
    );
  }
}

import 'package:material_ui/material_ui.dart';

import '../../l10n/generated/app_localizations.dart';

/// What the bottom right corner of a live page says (ADR-0007): more of the
/// current song follows, or the song ends here.
enum PageHint {
  /// Another page of the song follows (song pages, a scrolled song that is
  /// not at its end, PDF pages or spreads).
  more,

  /// The last page of the song.
  end,
}

/// Size of the folded corner.
const pageHintSize = 44.0;

/// Marks the bottom right corner of the live page: a folded corner in the
/// accent colour while more of the song follows, a final barline on its
/// last page. Seen from the corner of the eye on stage, where the page
/// counter in the bottom bar has to be read. It never takes taps.
class PageHintMark extends StatelessWidget {
  const PageHintMark({super.key, required this.hint});

  /// Null shows nothing (e.g. a pause in the set).
  final PageHint? hint;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final mark = switch (hint) {
      PageHint.more => Semantics(
        key: const Key('live-more-pages'),
        label: l10n.liveMorePages,
        child: CustomPaint(
          size: const Size.square(pageHintSize),
          painter: _DogEarPainter(
            flap: scheme.primary,
            back: scheme.surfaceContainer,
            shadow: scheme.shadow,
          ),
        ),
      ),
      PageHint.end => Semantics(
        key: const Key('live-song-end'),
        label: l10n.liveSongEnd,
        child: Padding(
          padding: const EdgeInsets.only(right: 4, bottom: 8),
          child: CustomPaint(
            size: const Size(11, 28),
            painter: _FinalBarlinePainter(
              scheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
      null => const SizedBox.shrink(),
    };
    return IgnorePointer(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.bottomRight,
          children: [...previous, ?current],
        ),
        child: mark,
      ),
    );
  }
}

/// The corner of a page folded over onto the page: the flap lies above the
/// diagonal, the corner below it shows what is behind the page.
class _DogEarPainter extends CustomPainter {
  _DogEarPainter({
    required this.flap,
    required this.back,
    required this.shadow,
  });

  final Color flap;
  final Color back;
  final Color shadow;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final corner = Path()
      ..moveTo(0, h)
      ..lineTo(w, 0)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(corner, Paint()..color = back);
    final fold = Path()
      ..moveTo(0, h)
      ..lineTo(w, 0)
      ..lineTo(0, 0)
      ..close();
    canvas.drawShadow(fold, shadow, 3, false);
    canvas.drawPath(fold, Paint()..color = flap);
  }

  @override
  bool shouldRepaint(_DogEarPainter old) =>
      old.flap != flap || old.back != back || old.shadow != shadow;
}

/// The final barline of sheet music: a thin and a thick line.
class _FinalBarlinePainter extends CustomPainter {
  _FinalBarlinePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    canvas
      ..drawRect(Rect.fromLTWH(0, 0, 2, size.height), paint)
      ..drawRect(Rect.fromLTWH(size.width - 6, 0, 6, size.height), paint);
  }

  @override
  bool shouldRepaint(_FinalBarlinePainter old) => old.color != color;
}

import 'package:material_ui/material_ui.dart';

/// Brand colors of the RealChord logo (sources in `app/branding/`).
abstract final class BrandColors {
  /// Top and bottom of the logo gradient.
  static const gradientTop = Color(0xFFFFB020);
  static const gradientBottom = Color(0xFFE8461C);

  /// Text of the wordmark ("Real") on light and dark backgrounds.
  static const ink = Color(0xFF1B1D22);
  static const inkDark = Color(0xFFFFFFFF);

  /// Splash background, the same as the native and web splash
  /// (`flutter_native_splash.yaml`, `web/index.html`).
  static const splashLight = Color(0xFFFFFFFF);
  static const splashDark = Color(0xFF121417);

  static const gradient = LinearGradient(
    // Matches x2=0.35 in mark.svg: slightly diagonal, top to bottom.
    begin: Alignment(-1, -1),
    end: Alignment(-0.3, 1),
    colors: [gradientTop, gradientBottom],
  );
}

/// The logo mark: a plectrum with a chord diagram. Drawn in code (the same
/// geometry as `app/branding/mark.svg`), so it shows on the very first frame
/// without loading an asset.
class RealChordMark extends StatelessWidget {
  const RealChordMark({super.key, this.size = 48});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: const CustomPaint(painter: _MarkPainter()),
  );
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // mark.svg uses a 512 × 512 view box.
    canvas.scale(size.width / 512, size.height / 512);

    final pick = Path()
      ..moveTo(256, 36)
      ..cubicTo(386, 36, 474, 92, 474, 184)
      ..cubicTo(474, 306, 344, 434, 256, 478)
      ..cubicTo(168, 434, 38, 306, 38, 184)
      ..cubicTo(38, 92, 126, 36, 256, 36)
      ..close();
    canvas.drawPath(
      pick,
      Paint()..shader = BrandColors.gradient.createShader(pick.getBounds()),
    );

    Paint line(double width, [double opacity = 1]) => Paint()
      ..color = Colors.white.withValues(alpha: opacity)
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Nut, frets and strings.
    canvas.drawLine(const Offset(178, 138), const Offset(334, 138), line(22));
    final fret = line(10, 0.85);
    canvas.drawLine(const Offset(186, 206), const Offset(326, 206), fret);
    canvas.drawLine(const Offset(190, 270), const Offset(322, 270), fret);
    final string = line(10);
    for (final (x, bottom) in [
      (186.0, 318.0),
      (232.0, 338.0),
      (280.0, 338.0),
      (326.0, 318.0),
    ]) {
      canvas.drawLine(Offset(x, 138), Offset(x, bottom), string);
    }

    // Finger positions.
    final dot = Paint()..color = Colors.white;
    for (final center in const [
      Offset(326, 172),
      Offset(280, 238),
      Offset(186, 238),
    ]) {
      canvas.drawCircle(center, 21, dot);
    }
  }

  @override
  bool shouldRepaint(_MarkPainter oldDelegate) => false;
}

/// The wordmark "RealChord": "Real" in [ink], "Chord" in the brand gradient.
class RealChordWordmark extends StatelessWidget {
  const RealChordWordmark({super.key, this.height = 32, this.ink});

  /// Font size of the wordmark.
  final double height;

  /// Color of "Real"; defaults to a color readable on the current theme.
  final Color? ink;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final style = TextStyle(
      fontFamily: 'NotoSans',
      fontWeight: FontWeight.w700,
      fontSize: height,
      height: 1.1,
      letterSpacing: -0.025 * height,
      color: ink ?? (dark ? BrandColors.inkDark : BrandColors.ink),
    );
    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Real', style: style),
          ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: BrandColors.gradient.createShader,
            child: Text('Chord', style: style),
          ),
        ],
      ),
    );
  }
}

/// Mark and wordmark side by side.
class RealChordLogo extends StatelessWidget {
  const RealChordLogo({super.key, this.height = 40});

  final double height;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'RealChord',
    image: true,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        RealChordMark(size: height * 1.25),
        SizedBox(width: height * 0.3),
        RealChordWordmark(height: height),
      ],
    ),
  );
}

/// Shown while the app starts: the same layout as the native splash
/// (Android, iOS) and the web splash, so the change is seamless. Follows
/// the system brightness, since the settings are not loaded yet.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, this.busy = false});

  /// Shows a progress indicator below the mark (e.g. the first sync).
  final bool busy;

  static const markSize = 128.0;
  static const wordmarkWidth = 200.0;

  /// Shortest time the splash stays on screen (counted from the start of
  /// `main()`), so it is noticeable even where the app starts in a fraction
  /// of a second (Windows, Linux). Starting runs during this time; only the
  /// rest is waited for.
  static const minimumDuration = Duration(seconds: 1);

  /// Waits until [shown] has run for at least [minimumDuration].
  static Future<void> waitForMinimum(Stopwatch shown) async {
    final rest = remaining(shown.elapsed);
    if (rest > Duration.zero) await Future<void>.delayed(rest);
  }

  /// How much longer the splash stays after it has been shown for [elapsed].
  static Duration remaining(
    Duration elapsed, {
    Duration minimum = minimumDuration,
  }) => elapsed >= minimum ? Duration.zero : minimum - elapsed;

  @override
  Widget build(BuildContext context) {
    final dark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: dark ? BrandColors.splashDark : BrandColors.splashLight,
        child: Semantics(
          label: 'RealChord',
          child: Stack(
            children: [
              const Center(child: RealChordMark(size: markSize)),
              if (busy)
                Align(
                  alignment: const Alignment(0, 0.45),
                  child: SizedBox.square(
                    dimension: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: BrandColors.gradientBottom,
                    ),
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 48,
                child: Center(
                  child: SizedBox(
                    width: wordmarkWidth,
                    child: FittedBox(
                      child: RealChordWordmark(
                        height: 40,
                        ink: dark ? BrandColors.inkDark : BrandColors.ink,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

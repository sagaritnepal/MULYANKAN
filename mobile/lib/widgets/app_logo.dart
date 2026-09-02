import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_theme.dart';

/// The logo is drawn rather than shipped as artwork.
///
/// It replaced a 2.4 MB rendered PNG that carried its own dark textured
/// background (so it sat as a grey rectangle on the app's own background)
/// and turned to mush at the 18px avatar size the feed uses. Drawing it
/// means one shape that stays crisp at every size, no asset weight, and
/// transparency for free.
///
/// The mark is a gauge: a swept arc with a needle, for a product that
/// measures vehicles.

/// Icon-only mark, for app bars and the feed's showroom avatar.
class AppLogoMark extends StatelessWidget {
  final double size;
  const AppLogoMark({super.key, this.size = 32});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GaugeMarkPainter(size: size)),
    );
  }
}

/// The full lockup — mark plus the stacked wordmark and tagline.
///
/// Everything is sized from [width] so the proportions hold whether it is
/// rendered at 150px in the feed app bar or 240px on the login screen.
class AppLogoFull extends StatelessWidget {
  final double width;
  const AppLogoFull({super.key, this.width = 280});

  @override
  Widget build(BuildContext context) {
    final markSize = width * 0.235;
    final titleSize = width * 0.125;
    final taglineSize = math.max(width * 0.045, 7.0);

    return SizedBox(
      width: width,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AppLogoMark(size: markSize),
          SizedBox(width: width * 0.055),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MULYANKAN',
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: titleSize,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                    letterSpacing: titleSize * 0.02,
                    height: 1.05,
                  ),
                ),
                SizedBox(height: width * 0.018),
                // A short rule rather than a full-width one: it ends under
                // the wordmark instead of drifting past it at large sizes.
                Container(
                  height: math.max(width * 0.008, 1.0),
                  width: width * 0.60,
                  color: AppColors.accent,
                ),
                SizedBox(height: width * 0.022),
                Text(
                  'AUTO VALUATION',
                  maxLines: 1,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: taglineSize,
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted,
                    letterSpacing: taglineSize * 0.28,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GaugeMarkPainter extends CustomPainter {
  final double size;
  const _GaugeMarkPainter({required this.size});

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final w = canvasSize.width;
    final h = canvasSize.height;
    final radius = w * 0.26;

    // Rounded tile.
    final tile = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, w, h),
      Radius.circular(w * 0.28),
    );
    canvas.drawRRect(tile, Paint()..color = AppColors.accent);

    // The gauge sits a little below centre so the needle has room above
    // it and the whole glyph reads as balanced inside the tile.
    final pivot = Offset(w / 2, h * 0.66);

    // Flutter's angles start at 3 o'clock and increase clockwise, so this
    // sweeps from roughly 10 o'clock up over the top to 2 o'clock.
    const startAngle = math.pi + 0.38;
    const sweepAngle = math.pi - 0.76;

    final arcPaint = Paint()
      ..color = AppColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.085
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: pivot, radius: radius),
      startAngle,
      sweepAngle,
      false,
      arcPaint,
    );

    // Ticks are omitted below 28px — at avatar size they smear into the
    // arc and cost legibility rather than adding detail.
    if (size >= 28) {
      final tickPaint = Paint()
        ..color = AppColors.ink.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.035
        ..strokeCap = StrokeCap.round;
      for (int i = 0; i <= 2; i++) {
        final t = startAngle + sweepAngle * (i / 2);
        final inner = radius * 1.28;
        final outer = radius * 1.46;
        canvas.drawLine(
          pivot + Offset(math.cos(t) * inner, math.sin(t) * inner),
          pivot + Offset(math.cos(t) * outer, math.sin(t) * outer),
          tickPaint,
        );
      }
    }

    // Needle, pointing up-right into the top of the sweep — a reading
    // toward the high end rather than sitting at rest.
    const needleAngle = math.pi * 1.72;
    final needlePaint = Paint()
      ..color = AppColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.075
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      pivot,
      pivot + Offset(math.cos(needleAngle) * radius * 0.82, math.sin(needleAngle) * radius * 0.82),
      needlePaint,
    );

    // Pivot cap: a red dot inside a cream disc, so the needle looks hinged
    // rather than floating.
    canvas.drawCircle(pivot, w * 0.075, Paint()..color = AppColors.ink);
    canvas.drawCircle(pivot, w * 0.032, Paint()..color = AppColors.accent);
  }

  @override
  bool shouldRepaint(_GaugeMarkPainter oldDelegate) => oldDelegate.size != size;
}

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

  // Intrinsic design metrics. The lockup is built at this size and then
  // scaled to the requested [width] by a FittedBox, rather than deriving
  // font sizes from the width directly — that earlier approach sized the
  // wordmark to roughly 70% of the lockup while leaving it only 71% of
  // the room, and the final N was clipped off at every size.
  static const double _markSize = 62;
  static const double _titleSize = 33;
  static const double _taglineSize = 11.5;
  static const double _gap = 14;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: FittedBox(
        fit: BoxFit.contain,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const AppLogoMark(size: _markSize),
            const SizedBox(width: _gap),
            // IntrinsicWidth + stretch makes the rule exactly as wide as
            // the wordmark, instead of guessing a fraction of the width.
            IntrinsicWidth(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'MULYANKAN',
                    maxLines: 1,
                    softWrap: false,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: _titleSize,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                      letterSpacing: _titleSize * 0.02,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Container(height: 2, color: AppColors.accent),
                  const SizedBox(height: 6),
                  Text(
                    'AUTO VALUATION',
                    maxLines: 1,
                    softWrap: false,
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: _taglineSize,
                      fontWeight: FontWeight.w600,
                      color: AppColors.muted,
                      letterSpacing: _taglineSize * 0.28,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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

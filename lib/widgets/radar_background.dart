import 'dart:math' as math;
import 'package:flutter/material.dart';

class RadarBackground extends StatelessWidget {
  const RadarBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // LayoutBuilder → kesin px boyutları alır, CustomPaint asla yanlış boyutlanmaz
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: CustomPaint(painter: _RadarPainter()),
            ),
            child,
          ],
        );
      },
    );
  }
}

class _RadarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Merkez: sağ alt köşe
    final cx = size.width;
    final cy = size.height;

    // ── Renk paleti ───────────────────────────────────────────────────────
    // Ana çizgi: parlak teal (#00D4FF)
    // Dolgu gölgesi: daha koyu mavi (#0077B6)
    const ringColor  = Color(0xFF00D4FF);
    const glowColor  = Color(0xFF0077B6);
    const axisColor  = Color(0xFF48CAE4);

    // ── Radar halkaları ───────────────────────────────────────────────────
    final List<double> radii  = [100, 200, 310, 430, 560];
    final List<double> opacs  = [0.70, 0.52, 0.38, 0.26, 0.15];
    final List<double> widths = [2.5, 2.0, 1.8, 1.5, 1.2];

    for (int i = 0; i < radii.length; i++) {
      final r = radii[i];

      // Gölge (daha kalın, düşük opacity)
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        math.pi, -math.pi / 2, false,
        Paint()
          ..color = glowColor.withValues(alpha: opacs[i] * 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = widths[i] + 4,
      );

      // Ana halka çizgisi
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        math.pi, -math.pi / 2, false,
        Paint()
          ..color = ringColor.withValues(alpha: opacs[i])
          ..style = PaintingStyle.stroke
          ..strokeWidth = widths[i]
          ..strokeCap = StrokeCap.round,
      );
    }

    // ── Eksen çizgileri ───────────────────────────────────────────────────
    final axisPaint = Paint()
      ..color = axisColor.withValues(alpha: 0.35)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(0, cy), Offset(cx, cy), axisPaint);  // yatay
    canvas.drawLine(Offset(cx, 0), Offset(cx, cy), axisPaint);  // dikey

    // ── Tick işaretleri ───────────────────────────────────────────────────
    final tickPaint = Paint()
      ..color = ringColor.withValues(alpha: 0.50)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final r in radii) {
      for (double a = math.pi; a <= math.pi * 1.5 + 0.01; a += math.pi / 8) {
        final px = cx + r * math.cos(a);
        final py = cy + r * math.sin(a);
        canvas.drawLine(
          Offset(px, py),
          Offset(px - 11 * math.cos(a), py - 11 * math.sin(a)),
          tickPaint,
        );
      }
    }

    // ── Köşe parıltısı (sağ alt köşede küçük dolu daire) ─────────────────
    canvas.drawCircle(
      Offset(cx, cy), 8,
      Paint()..color = ringColor.withValues(alpha: 0.20),
    );
    canvas.drawCircle(
      Offset(cx, cy), 4,
      Paint()..color = ringColor.withValues(alpha: 0.80),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

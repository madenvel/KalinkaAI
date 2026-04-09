import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Procedural album art generated via CustomPainter.
/// Creates a unique dark gradient per track based on track ID hash,
/// with concentric rings and accent dots.
class ProceduralAlbumArt extends StatelessWidget {
  final String trackId;
  final double size;

  const ProceduralAlbumArt({super.key, required this.trackId, this.size = 200});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _ProceduralAlbumArtPainter(trackId: trackId),
    );
  }
}

class _ProceduralAlbumArtPainter extends CustomPainter {
  final String trackId;

  _ProceduralAlbumArtPainter({required this.trackId});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Seed a deterministic hue from the track ID
    final hash = trackId.hashCode;
    final rng = Random(hash);

    // Generate a deep hue in the berry/brass range (340-400°, wrapping
    // through crimson red to warm gold) matching Kalinka Berry & Brass accents.
    final hue = (340.0 + rng.nextDouble() * 60.0) % 360.0;
    final baseColor = HSLColor.fromAHSL(1.0, hue, 0.60, 0.16).toColor();
    const nearBlack = KalinkaColors.background;

    // Radial gradient background
    final bgPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment(
          -0.3 + rng.nextDouble() * 0.6,
          -0.3 + rng.nextDouble() * 0.6,
        ),
        radius: 1.0,
        colors: [baseColor, nearBlack],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Concentric rings at 85% and 55% radius, white at 4-5% opacity
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    ringPaint.color = Colors.white.withValues(alpha: 0.05);
    canvas.drawCircle(center, radius * 0.85, ringPaint);

    ringPaint.color = Colors.white.withValues(alpha: 0.04);
    canvas.drawCircle(center, radius * 0.55, ringPaint);

    // Small accent dot at center
    final accentDotPaint = Paint()..color = KalinkaColors.accent;
    canvas.drawCircle(center, 3, accentDotPaint);

    // Small gold dot offset toward top-left
    final goldDotPaint = Paint()..color = KalinkaColors.gold;
    final goldOffset = Offset(
      center.dx - radius * 0.25,
      center.dy - radius * 0.3,
    );
    canvas.drawCircle(goldOffset, 2, goldDotPaint);
  }

  @override
  bool shouldRepaint(_ProceduralAlbumArtPainter oldDelegate) {
    return oldDelegate.trackId != trackId;
  }
}

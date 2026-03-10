import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A 2px gradient progress line (accent → gold) for the mini player top edge.
class GradientProgressLine extends StatelessWidget {
  final double progress;
  final double height;

  const GradientProgressLine({
    super.key,
    required this.progress,
    this.height = 3,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(double.infinity, height),
      painter: _GradientProgressPainter(progress: progress),
    );
  }
}

class _GradientProgressPainter extends CustomPainter {
  final double progress;

  _GradientProgressPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    // Background track
    final bgPaint = Paint()..color = KalinkaColors.borderSubtle;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Gradient fill
    if (progress > 0) {
      final fillWidth = size.width * progress.clamp(0.0, 1.0);
      final fillPaint = Paint()
        ..shader = KalinkaColors.progressGradient.createShader(
          Rect.fromLTWH(0, 0, size.width, size.height),
        );
      canvas.drawRect(Rect.fromLTWH(0, 0, fillWidth, size.height), fillPaint);
    }
  }

  @override
  bool shouldRepaint(_GradientProgressPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

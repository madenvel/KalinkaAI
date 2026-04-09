import 'dart:math';
import 'package:flutter/material.dart';

/// Paints a progress ring around a thumbnail during long-press.
/// Shared by SearchTrackRow, SearchAlbumRow, and SearchPlaylistRow.
class LongPressRingPainter extends CustomPainter {
  final double progress;
  final Color color;

  LongPressRingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 1;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(LongPressRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

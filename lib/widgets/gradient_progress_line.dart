import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum GradientProgressLineMode { normal, reconnecting, offline }

/// A mini-player progress line with online/reconnecting/offline visual modes.
class GradientProgressLine extends StatefulWidget {
  final double progress;
  final double height;
  final GradientProgressLineMode mode;

  const GradientProgressLine({
    super.key,
    required this.progress,
    required this.mode,
    this.height = 2,
  });

  @override
  State<GradientProgressLine> createState() => _GradientProgressLineState();
}

class _GradientProgressLineState extends State<GradientProgressLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerController;

  bool get _shouldAnimateShimmer =>
      widget.mode == GradientProgressLineMode.reconnecting &&
      widget.progress < 1.0;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _syncShimmerAnimation();
  }

  @override
  void didUpdateWidget(covariant GradientProgressLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode ||
        oldWidget.progress != widget.progress) {
      _syncShimmerAnimation();
    }
  }

  void _syncShimmerAnimation() {
    if (_shouldAnimateShimmer) {
      if (!_shimmerController.isAnimating) {
        _shimmerController.repeat(reverse: true);
      }
      return;
    }

    if (_shimmerController.isAnimating) {
      _shimmerController.stop();
    }
    _shimmerController.value = 0.0;
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mode == GradientProgressLineMode.reconnecting) {
      return AnimatedBuilder(
        animation: _shimmerController,
        builder: (context, _) {
          return CustomPaint(
            size: Size(double.infinity, widget.height),
            painter: _GradientProgressPainter(
              progress: widget.progress,
              mode: widget.mode,
              shimmerProgress: _shimmerController.value,
            ),
          );
        },
      );
    }

    return CustomPaint(
      size: Size(double.infinity, widget.height),
      painter: _GradientProgressPainter(
        progress: widget.progress,
        mode: widget.mode,
        shimmerProgress: 0.0,
      ),
    );
  }
}

class _GradientProgressPainter extends CustomPainter {
  final double progress;
  final GradientProgressLineMode mode;
  final double shimmerProgress;

  _GradientProgressPainter({
    required this.progress,
    required this.mode,
    required this.shimmerProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final clampedProgress = progress.clamp(0.0, 1.0).toDouble();
    final fillWidth = size.width * clampedProgress;

    // Background track
    final bgPaint = Paint()..color = KalinkaColors.borderSubtle;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    if (fillWidth > 0) {
      final fillPaint = Paint();
      if (mode == GradientProgressLineMode.offline) {
        fillPaint.color = KalinkaColors.textMuted;
      } else {
        fillPaint.shader = KalinkaColors.progressGradient.createShader(
          Rect.fromLTWH(0, 0, size.width, size.height),
        );
      }
      canvas.drawRect(Rect.fromLTWH(0, 0, fillWidth, size.height), fillPaint);
    }

    if (mode == GradientProgressLineMode.reconnecting &&
        fillWidth < size.width) {
      // Sweep a soft highlight across the unfilled portion while reconnecting.
      final remainingWidth = size.width - fillWidth;
      final shimmerWidth = remainingWidth.clamp(10.0, 56.0).toDouble();
      final travelDistance = math.max(remainingWidth - shimmerWidth, 0.0);
      final shimmerLeft = fillWidth + (shimmerProgress * travelDistance);

      final reconnectRect = Rect.fromLTWH(
        fillWidth,
        0,
        remainingWidth,
        size.height,
      );
      final shimmerRect = Rect.fromLTWH(
        shimmerLeft,
        0,
        shimmerWidth,
        size.height,
      ).intersect(reconnectRect);

      if (shimmerRect.width > 0) {
        final shimmerPaint = Paint()
          ..shader = LinearGradient(
            colors: [
              KalinkaColors.statusPending.withValues(alpha: 0.0),
              KalinkaColors.statusPending.withValues(alpha: 0.45),
              KalinkaColors.statusPending.withValues(alpha: 0.0),
            ],
            stops: [0.0, 0.5, 1.0],
          ).createShader(shimmerRect);
        canvas.drawRect(shimmerRect, shimmerPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_GradientProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.mode != mode ||
        oldDelegate.shimmerProgress != shimmerProgress;
  }
}

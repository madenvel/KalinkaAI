import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Animated sonar / radar-ping widget.
///
/// Renders [ringCount] concentric stroke circles that expand from [minRadius]
/// to [maxRadius] and fade out. Individual rings are staggered in time by
/// [interval], so at steady state there are always [ringCount] rings in
/// flight simultaneously — the classic sonar-pulse look.
///
/// Parameters
/// ----------
/// [minRadius]   – starting radius of each ring (pixels).
/// [maxRadius]   – ending radius each ring reaches before it disappears.
/// [interval]    – time between consecutive ring births. The total animation
///                 period is `interval × ringCount`.
/// [fadingFactor] – controls how quickly a ring's opacity decays as it
///                 expands.  Uses a power-curve:
///                   opacity = (1 − t)^fadingFactor × color.opacity
///                 where t ∈ [0, 1] is the ring's normalised lifetime.
///                   • 1.0 → linear fade  (default)
///                   • > 1.0 → fast initial fade, ring disappears quickly
///                   • < 1.0 → slow fade, ring stays visible nearly to max radius
/// [color]       – stroke colour (alpha is respected and combined with the
///                 animated opacity).
/// [ringCount]   – number of rings alive simultaneously.
/// [strokeWidth] – width of each ring's stroke (default 2).
class SonarAnimation extends StatefulWidget {
  final double minRadius;
  final double maxRadius;
  final Duration interval;
  final double fadingFactor;
  final Color color;
  final int ringCount;
  final double strokeWidth;

  const SonarAnimation({
    super.key,
    required this.minRadius,
    required this.maxRadius,
    required this.interval,
    this.fadingFactor = 1.0,
    required this.color,
    required this.ringCount,
    this.strokeWidth = 2.0,
  }) : assert(minRadius >= 0, 'minRadius must be non-negative'),
       assert(
         maxRadius > minRadius,
         'maxRadius must be greater than minRadius',
       ),
       assert(ringCount > 0, 'ringCount must be at least 1'),
       assert(fadingFactor > 0, 'fadingFactor must be positive');

  @override
  State<SonarAnimation> createState() => _SonarAnimationState();
}

class _SonarAnimationState extends State<SonarAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.interval * widget.ringCount,
    )..repeat();
  }

  @override
  void didUpdateWidget(SonarAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newDuration = widget.interval * widget.ringCount;
    if (newDuration != _controller.duration) {
      _controller.duration = newDuration;
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          painter: _SonarPainter(
            progress: _controller.value,
            minRadius: widget.minRadius,
            maxRadius: widget.maxRadius,
            fadingFactor: widget.fadingFactor,
            color: widget.color,
            ringCount: widget.ringCount,
            strokeWidth: widget.strokeWidth,
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------

class _SonarPainter extends CustomPainter {
  final double progress;
  final double minRadius;
  final double maxRadius;
  final double fadingFactor;
  final Color color;
  final int ringCount;
  final double strokeWidth;

  const _SonarPainter({
    required this.progress,
    required this.minRadius,
    required this.maxRadius,
    required this.fadingFactor,
    required this.color,
    required this.ringCount,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radiusSpan = maxRadius - minRadius;
    final baseAlpha = color.a; // 0.0–1.0

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    for (int i = 0; i < ringCount; i++) {
      // Each ring is staggered by i/ringCount of the total cycle.
      // Shift progress so ring 0 is always the newest (just born).
      final ringT = (progress - i / ringCount + 1.0) % 1.0;

      // radius grows linearly from minRadius → maxRadius over the cycle.
      final radius = minRadius + radiusSpan * ringT;

      // opacity decays from color.opacity → 0 using the fading-factor power curve.
      final opacity =
          math.pow(1.0 - ringT, fadingFactor).toDouble() * baseAlpha;

      paint.color = color.withValues(
        red: color.r,
        green: color.g,
        blue: color.b,
        alpha: opacity.clamp(0.0, 1.0),
      );

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_SonarPainter old) =>
      old.progress != progress ||
      old.minRadius != minRadius ||
      old.maxRadius != maxRadius ||
      old.fadingFactor != fadingFactor ||
      old.color != color ||
      old.ringCount != ringCount ||
      old.strokeWidth != strokeWidth;
}

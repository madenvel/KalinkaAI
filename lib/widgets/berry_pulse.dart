import 'dart:async';

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Animated "berry cluster" overlay for the now-playing artwork thumbnail.
///
/// Three gold dots mirror the Kalinka berry-cluster mark: one large dot
/// lower-left, one medium dot upper-right, one small dot mid-right. They
/// pulse vertically with independent rhythms, giving an organic breathing
/// quality. When [isPlaying] is false the dots freeze in place and dim.
class BerryPulse extends StatefulWidget {
  final bool isPlaying;

  const BerryPulse({super.key, required this.isPlaying});

  @override
  State<BerryPulse> createState() => _BerryPulseState();
}

class _BerryPulseState extends State<BerryPulse> with TickerProviderStateMixin {
  late final AnimationController _ctrlA;
  late final AnimationController _ctrlB;
  late final AnimationController _ctrlC;

  late final Animation<double> _animA;
  late final Animation<double> _animB;
  late final Animation<double> _animC;

  late final Listenable _pulseRepaint;
  Timer? _phaseBTimer;
  Timer? _phaseCTimer;

  static const _dotColor = KalinkaColors.accentTint;

  static const double _ampA = 4.5;
  static const double _ampB = 3.0;
  static const double _ampC = 2.0;
  static const double _size = 44.0;

  @override
  void initState() {
    super.initState();

    _ctrlA = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _ctrlB = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _ctrlC = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _animA = CurvedAnimation(parent: _ctrlA, curve: Curves.easeInOut);
    _animB = CurvedAnimation(parent: _ctrlB, curve: Curves.easeInOut);
    _animC = CurvedAnimation(parent: _ctrlC, curve: Curves.easeInOut);
    _pulseRepaint = Listenable.merge([_animA, _animB, _animC]);

    if (widget.isPlaying) {
      _startWithPhaseOffsets();
    }
  }

  void _startWithPhaseOffsets() {
    _phaseBTimer?.cancel();
    _phaseCTimer?.cancel();

    _ctrlA.repeat(reverse: true);
    _ctrlB.stop();
    _ctrlC.stop();

    _phaseBTimer = Timer(
      Duration(milliseconds: (_ctrlB.duration!.inMilliseconds * 0.33).round()),
      () {
        if (mounted && widget.isPlaying) {
          _ctrlB.repeat(reverse: true);
        }
      },
    );

    _phaseCTimer = Timer(
      Duration(milliseconds: (_ctrlC.duration!.inMilliseconds * 0.67).round()),
      () {
        if (mounted && widget.isPlaying) {
          _ctrlC.repeat(reverse: true);
        }
      },
    );
  }

  @override
  void didUpdateWidget(BerryPulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPlaying != widget.isPlaying) {
      if (widget.isPlaying) {
        _startWithPhaseOffsets();
      } else {
        _phaseBTimer?.cancel();
        _phaseCTimer?.cancel();
        _ctrlA.stop();
        _ctrlB.stop();
        _ctrlC.stop();
      }
    }
  }

  @override
  void dispose() {
    _phaseBTimer?.cancel();
    _phaseCTimer?.cancel();
    _ctrlA.dispose();
    _ctrlB.dispose();
    _ctrlC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final opacity = widget.isPlaying ? 0.90 : 0.35;

    if (reduceMotion) {
      return RepaintBoundary(
        child: AnimatedOpacity(
          opacity: opacity,
          duration: const Duration(milliseconds: 350),
          child: const SizedBox(
            width: _size,
            height: _size,
            child: CustomPaint(
              painter: _StaticBerryDotsPainter(
                offsetA: 0,
                offsetB: 0,
                offsetC: 0,
                dotColor: _dotColor,
              ),
            ),
          ),
        ),
      );
    }

    return RepaintBoundary(
      child: AnimatedOpacity(
        opacity: opacity,
        duration: const Duration(milliseconds: 350),
        child: SizedBox(
          width: _size,
          height: _size,
          child: CustomPaint(
            painter: _AnimatedBerryDotsPainter(
              animA: _animA,
              animB: _animB,
              animC: _animC,
              repaint: _pulseRepaint,
              dotColor: _dotColor,
              ampA: _ampA,
              ampB: _ampB,
              ampC: _ampC,
            ),
          ),
        ),
      ),
    );
  }
}

class _StaticBerryDotsPainter extends CustomPainter {
  final double offsetA;
  final double offsetB;
  final double offsetC;
  final Color dotColor;

  const _StaticBerryDotsPainter({
    required this.offsetA,
    required this.offsetB,
    required this.offsetC,
    required this.dotColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _paintDots(
      canvas: canvas,
      dotColor: dotColor,
      offsetA: offsetA,
      offsetB: offsetB,
      offsetC: offsetC,
    );
  }

  @override
  bool shouldRepaint(covariant _StaticBerryDotsPainter oldDelegate) {
    return oldDelegate.offsetA != offsetA ||
        oldDelegate.offsetB != offsetB ||
        oldDelegate.offsetC != offsetC ||
        oldDelegate.dotColor != dotColor;
  }
}

class _AnimatedBerryDotsPainter extends CustomPainter {
  final Animation<double> animA;
  final Animation<double> animB;
  final Animation<double> animC;
  final Color dotColor;
  final double ampA;
  final double ampB;
  final double ampC;

  _AnimatedBerryDotsPainter({
    required this.animA,
    required this.animB,
    required this.animC,
    required Listenable repaint,
    required this.dotColor,
    required this.ampA,
    required this.ampB,
    required this.ampC,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    final offsetA = (animA.value * 2 - 1) * ampA;
    final offsetB = (animB.value * 2 - 1) * ampB;
    final offsetC = (animC.value * 2 - 1) * ampC;

    _paintDots(
      canvas: canvas,
      dotColor: dotColor,
      offsetA: offsetA,
      offsetB: offsetB,
      offsetC: offsetC,
    );
  }

  @override
  bool shouldRepaint(covariant _AnimatedBerryDotsPainter oldDelegate) {
    return oldDelegate.animA != animA ||
        oldDelegate.animB != animB ||
        oldDelegate.animC != animC ||
        oldDelegate.dotColor != dotColor ||
        oldDelegate.ampA != ampA ||
        oldDelegate.ampB != ampB ||
        oldDelegate.ampC != ampC;
  }
}

void _paintDots({
  required Canvas canvas,
  required Color dotColor,
  required double offsetA,
  required double offsetB,
  required double offsetC,
}) {
  final paint = Paint()..color = dotColor;

  // Artwork thumbnail is 44×44 dp.
  // Dot rest positions are represented as top-left anchors; convert to centers.
  // Dot A — large, lower-left (diameter 5, base top 31.5)
  canvas.drawCircle(Offset(8 + 2.5, 31.5 - offsetA + 2.5), 2.5, paint);
  // Dot B — medium, upper-right (diameter 3.5, base top 28.25)
  canvas.drawCircle(Offset(20 + 1.75, 28.25 - offsetB + 1.75), 1.75, paint);
  // Dot C — small, mid-right (diameter 2.5, base top 33.75)
  canvas.drawCircle(Offset(28 + 1.25, 33.75 - offsetC + 1.25), 1.25, paint);
}

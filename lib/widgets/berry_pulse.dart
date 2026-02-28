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

  static const double _ampA = 4.5;
  static const double _ampB = 3.0;
  static const double _ampC = 2.0;

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

    if (widget.isPlaying) {
      _startWithPhaseOffsets();
    }
  }

  void _startWithPhaseOffsets() {
    _ctrlA.repeat(reverse: true);

    Future.delayed(
      Duration(
          milliseconds: (_ctrlB.duration!.inMilliseconds * 0.33).round()),
      () {
        if (mounted) _ctrlB.repeat(reverse: true);
      },
    );

    Future.delayed(
      Duration(
          milliseconds: (_ctrlC.duration!.inMilliseconds * 0.67).round()),
      () {
        if (mounted) _ctrlC.repeat(reverse: true);
      },
    );
  }

  @override
  void didUpdateWidget(BerryPulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPlaying != widget.isPlaying) {
      if (widget.isPlaying) {
        _ctrlA.repeat(reverse: true);
        _ctrlB.repeat(reverse: true);
        _ctrlC.repeat(reverse: true);
      } else {
        _ctrlA.stop();
        _ctrlB.stop();
        _ctrlC.stop();
      }
    }
  }

  @override
  void dispose() {
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
      return AnimatedOpacity(
        opacity: opacity,
        duration: const Duration(milliseconds: 350),
        child: const _BerryDots(offsetA: 0, offsetB: 0, offsetC: 0),
      );
    }

    return AnimatedOpacity(
      opacity: opacity,
      duration: const Duration(milliseconds: 350),
      child: AnimatedBuilder(
        animation: Listenable.merge([_animA, _animB, _animC]),
        builder: (context, _) {
          final offsetA = (_animA.value * 2 - 1) * _ampA;
          final offsetB = (_animB.value * 2 - 1) * _ampB;
          final offsetC = (_animC.value * 2 - 1) * _ampC;

          return _BerryDots(
            offsetA: offsetA,
            offsetB: offsetB,
            offsetC: offsetC,
          );
        },
      ),
    );
  }
}

class _BerryDots extends StatelessWidget {
  final double offsetA;
  final double offsetB;
  final double offsetC;

  const _BerryDots({
    required this.offsetA,
    required this.offsetB,
    required this.offsetC,
  });

  static const _dotColor = KalinkaColors.accentTint;

  @override
  Widget build(BuildContext context) {
    // Artwork thumbnail is 44×44 dp.
    // Dot rest positions from bottom-left (x from left, y from bottom).
    // Converted to top-left origin: top = 44 - y_from_bottom - radius - offset
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        children: [
          // Dot A — large, lower-left  (5 dp, rest y=10 from bottom)
          Positioned(
            left: 8,
            top: 31.5 - offsetA, // 44 - 10 - 2.5 = 31.5
            child: const _Dot(diameter: 5, color: _dotColor),
          ),
          // Dot B — medium, upper-right  (3.5 dp, rest y=14 from bottom)
          Positioned(
            left: 20,
            top: 28.25 - offsetB, // 44 - 14 - 1.75 = 28.25
            child: const _Dot(diameter: 3.5, color: _dotColor),
          ),
          // Dot C — small, mid-right  (2.5 dp, rest y=9 from bottom)
          Positioned(
            left: 28,
            top: 33.75 - offsetC, // 44 - 9 - 1.25 = 33.75
            child: const _Dot(diameter: 2.5, color: _dotColor),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final double diameter;
  final Color color;

  const _Dot({required this.diameter, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

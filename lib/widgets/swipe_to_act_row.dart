import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart' show SpringSimulation;
import '../theme/app_theme.dart';
import '../utils/haptics.dart';

/// Single-action right-swipe gesture wrapper.
///
/// Swipe right to trigger "Play next" on release.
/// Icon zooms from minimal to full size as you swipe.
/// Haptics trigger at 1/3 of max drag.
class SwipeToActRow extends StatefulWidget {
  final Widget child;
  final VoidCallback onPlayNext;
  final VoidCallback? onAddToQueue;
  final bool enabled;

  const SwipeToActRow({
    super.key,
    required this.child,
    required this.onPlayNext,
    this.onAddToQueue,
    this.enabled = true,
  });

  @override
  State<SwipeToActRow> createState() => _SwipeToActRowState();
}

class _SwipeToActRowState extends State<SwipeToActRow>
    with TickerProviderStateMixin {
  static const double _playNextIconSize = 24.0;
  static const double _playNextIconMinSize = 12.0;
  static const double _iconPadding = 16.0;
  static const double _maxDrag = 200.0;
  static const double _hapticThreshold = _maxDrag / 3.0; // 1/3 of max drag
  static const double _dragActivationThreshold = 14.0;
  static const double _resistanceCoefficient =
      60.0; // Controls resistance curve

  double _dragOffset = 0.0;
  double _rawDragOffset = 0.0; // Track raw offset before resistance
  bool _dragging = false;
  bool _dragUnlocked = false;

  late AnimationController _snapController;

  /// Drives the "play next" confirmation overlay: quick fade-in, short hold,
  /// slow fade-out. Starts simultaneously with the spring snap-back so feedback
  /// is immediate, then lingers briefly after the item returns to rest.
  late AnimationController _confirmController;
  late Animation<double> _confirmOpacity;

  @override
  void initState() {
    super.initState();
    _snapController = AnimationController(
      vsync: this,
      lowerBound: 0.0,
      upperBound:
          1000.0, // Must cover full pixel range; default [0,1] clips the spring
      duration: const Duration(
        milliseconds: 500,
      ), // Duration not used with SpringSimulation
    );
    _snapController.addListener(() {
      setState(() => _dragOffset = _snapController.value);
    });

    _confirmController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    // Quick fade-in (10%), short hold (25%), slow fade-out (65%)
    _confirmOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 10),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 65),
    ]).animate(_confirmController);
  }

  @override
  void dispose() {
    _snapController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  /// Apply resistance to drag offset using logarithmic curve.
  /// Resistance increases as you drag further, making it harder to overshoot.
  double _applyResistance(double rawOffset) {
    if (rawOffset <= 0) return 0;
    // Logarithmic curve: creates increasing resistance
    return math.log(1 + rawOffset / _resistanceCoefficient) *
        _resistanceCoefficient;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!widget.enabled) return;

    bool unlockedThisFrame = false;

    setState(() {
      _dragging = true;
      _rawDragOffset = (_rawDragOffset + details.delta.dx).clamp(
        0.0,
        double.infinity,
      );

      if (!_dragUnlocked && _rawDragOffset > _dragActivationThreshold) {
        _dragUnlocked = true;
        unlockedThisFrame = true;
      }

      _dragOffset = _dragUnlocked ? _applyResistance(_rawDragOffset) : 0.0;
    });

    if (unlockedThisFrame) {
      KalinkaHaptics.selectionClick();
    }
  }

  void _onDragEnd(DragEndDetails details) {
    if (!widget.enabled) return;

    _dragging = false;

    final bool triggerPlayNext = _dragOffset >= _hapticThreshold;

    _animateSpringSnap(
      0.0,
      onComplete: () {
        if (triggerPlayNext) {
          widget.onPlayNext();
        }
      },
    );

    if (triggerPlayNext) {
      KalinkaHaptics.corkPop();
      // Start confirmation overlay immediately on release — appears during
      // the spring snap-back so feedback is instant, not delayed.
      _confirmController.forward(from: 0.0);
    }
  }

  void _animateSpringSnap(double target, {VoidCallback? onComplete}) {
    final simulation = SpringSimulation(
      const SpringDescription(
        mass: 1.0,
        stiffness: 300.0, // Controls bounce: higher = stiffer
        damping: 30.0, // Controls oscillation dampening
      ),
      _dragOffset,
      target,
      0.0, // velocity
    );

    _snapController.animateWith(simulation).then((_) {
      if (target == 0.0) {
        _dragUnlocked = false;
        _rawDragOffset = 0.0;
      }
      onComplete?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget inner;

    if (!widget.enabled ||
        _dragOffset == 0.0 && !_dragging && !_snapController.isAnimating) {
      // Pass-through: no swipe state, just render child with drag detection
      inner = GestureDetector(
        onHorizontalDragUpdate: _onDragUpdate,
        onHorizontalDragEnd: _onDragEnd,
        child: widget.child,
      );
    } else {
      // Icon zoom calculation: zooms until 1/3 threshold, then stays stable
      final progress = (_dragOffset / _hapticThreshold).clamp(0.0, 1.0);
      final iconSize =
          _playNextIconMinSize +
          (_playNextIconSize - _playNextIconMinSize) * progress;

      // Background is visible immediately on any drag
      const bgColor = KalinkaColors.gold; // Gold from theme palette

      inner = GestureDetector(
        onHorizontalDragUpdate: _onDragUpdate,
        onHorizontalDragEnd: _onDragEnd,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // Uniform background under the swipe
            Positioned.fill(child: ColoredBox(color: bgColor)),
            // Icon (left-anchored, zooms as swipe progresses)
            Positioned(
              left: _iconPadding,
              top: 0,
              bottom: 0,
              child: Center(
                child: Icon(
                  Icons.arrow_upward,
                  color: Colors.white,
                  size: iconSize,
                ),
              ),
            ),
            // Content layer (slides right)
            Transform.translate(
              offset: Offset(_dragOffset, 0),
              child: ColoredBox(
                color: KalinkaColors.background,
                child: widget.child,
              ),
            ),
          ],
        ),
      );
    }

    // Confirmation overlay: gold wash + checkmark, fades in immediately on
    // release then fades out. IgnorePointer ensures it never blocks touches.
    return Stack(
      children: [
        inner,
        Positioned.fill(
          child: IgnorePointer(
            child: FadeTransition(
              opacity: _confirmOpacity,
              child: ColoredBox(
                color: KalinkaColors.gold.withValues(alpha: 0.18),
                child: const Center(
                  child: Icon(
                    Icons.check_rounded,
                    color: KalinkaColors.gold,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

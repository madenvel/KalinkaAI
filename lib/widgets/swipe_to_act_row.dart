import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart' show SpringSimulation;
import '../theme/app_theme.dart';
import '../utils/haptics.dart';

/// Bidirectional swipe gesture wrapper.
///
/// Swipe right → "Add to queue" (white + icon on gold background).
/// Swipe left  → "Play next"   (white ↑ icon on gold background).
/// Icon zooms from minimal to full size as you swipe.
/// Haptics trigger at 1/3 of max drag.
class SwipeToActRow extends StatefulWidget {
  final Widget child;
  final VoidCallback onAddToQueue;
  final VoidCallback onPlayNext;
  final bool enabled;

  const SwipeToActRow({
    super.key,
    required this.child,
    required this.onAddToQueue,
    required this.onPlayNext,
    this.enabled = true,
  });

  @override
  State<SwipeToActRow> createState() => _SwipeToActRowState();
}

class _SwipeToActRowState extends State<SwipeToActRow>
    with TickerProviderStateMixin {
  static const double _iconSize = 24.0;
  static const double _iconMinSize = 12.0;
  static const double _iconPadding = 16.0;
  static const double _maxDrag = 200.0;
  static const double _hapticThreshold = _maxDrag / 3.0;
  static const double _dragActivationThreshold = 14.0;
  static const double _settleEpsilon = 0.5;
  static const double _resistanceCoefficient = 60.0;

  double _dragOffset = 0.0;
  double _rawDragOffset = 0.0;
  bool _dragging = false;
  bool _dragUnlocked = false;

  late AnimationController _snapController;
  late AnimationController _confirmController;
  late Animation<double> _confirmOpacity;

  @override
  void initState() {
    super.initState();
    _snapController = AnimationController(
      vsync: this,
      lowerBound: -1000.0,
      upperBound: 1000.0,
      duration: const Duration(milliseconds: 500),
    );
    _snapController.addListener(() {
      setState(() {
        final value = _snapController.value;
        _dragOffset = value.abs() <= _settleEpsilon ? 0.0 : value;
      });
    });

    _confirmController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
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

  double _applyResistance(double rawOffset) {
    if (rawOffset <= 0) return 0;
    return math.log(1 + rawOffset / _resistanceCoefficient) *
        _resistanceCoefficient;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!widget.enabled) return;

    bool unlockedThisFrame = false;

    setState(() {
      _dragging = true;
      _rawDragOffset += details.delta.dx;

      if (!_dragUnlocked &&
          _rawDragOffset.abs() > _dragActivationThreshold) {
        _dragUnlocked = true;
        unlockedThisFrame = true;
      }

      if (_dragUnlocked) {
        final sign = _rawDragOffset >= 0 ? 1.0 : -1.0;
        _dragOffset = sign * _applyResistance(_rawDragOffset.abs());
      } else {
        _dragOffset = 0.0;
      }
    });

    if (unlockedThisFrame) {
      KalinkaHaptics.selectionClick();
    }
  }

  void _onDragEnd(DragEndDetails details) {
    if (!widget.enabled) return;

    _dragging = false;

    final bool triggered = _dragOffset.abs() >= _hapticThreshold;
    final bool isQueue = _dragOffset > 0;

    _animateSpringSnap(
      0.0,
      onComplete: () {
        if (triggered) {
          if (isQueue) {
            widget.onAddToQueue();
          } else {
            widget.onPlayNext();
          }
        }
      },
    );

    if (triggered) {
      KalinkaHaptics.corkPop();
      _confirmController.forward(from: 0.0);
    }
  }

  void _animateSpringSnap(double target, {VoidCallback? onComplete}) {
    final simulation = SpringSimulation(
      const SpringDescription(
        mass: 1.0,
        stiffness: 300.0,
        damping: 30.0,
      ),
      _dragOffset,
      target,
      0.0,
    );

    _snapController.animateWith(simulation).then((_) {
      if (target == 0.0) {
        _dragUnlocked = false;
        _rawDragOffset = 0.0;
        if (mounted) {
          setState(() {
            _dragOffset = 0.0;
          });
        }
      }
      onComplete?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget inner;

    if (!widget.enabled ||
        _dragOffset.abs() <= _settleEpsilon &&
            !_dragging &&
            !_snapController.isAnimating) {
      inner = GestureDetector(
        onHorizontalDragUpdate: _onDragUpdate,
        onHorizontalDragEnd: _onDragEnd,
        child: widget.child,
      );
    } else {
      final absOffset = _dragOffset.abs();
      final progress = (absOffset / _hapticThreshold).clamp(0.0, 1.0);
      final currentIconSize =
          _iconMinSize + (_iconSize - _iconMinSize) * progress;
      final isRight = _dragOffset > 0;

      // Right swipe (queue): warm white bg. Left swipe (play next): amber bg.
      final bgColor = isRight
          ? KalinkaColors.gold
          : KalinkaColors.statusPending;

      inner = GestureDetector(
        onHorizontalDragUpdate: _onDragUpdate,
        onHorizontalDragEnd: _onDragEnd,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                // Background on the revealed side only
                if (isRight)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: _dragOffset.clamp(0.0, width),
                    child: ColoredBox(color: bgColor),
                  )
                else
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    width: absOffset.clamp(0.0, width),
                    child: ColoredBox(color: bgColor),
                  ),
                // Icon on the revealed side
                if (isRight)
                  Positioned(
                    left: _iconPadding,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Icon(
                        Icons.add,
                        color: Colors.white,
                        size: currentIconSize,
                      ),
                    ),
                  )
                else
                  Positioned(
                    right: _iconPadding,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Icon(
                        Icons.arrow_upward,
                        color: Colors.white,
                        size: currentIconSize,
                      ),
                    ),
                  ),
                // Content layer (slides with drag)
                Transform.translate(
                  offset: Offset(_dragOffset, 0),
                  child: SizedBox(
                    width: width,
                    child: ColoredBox(
                      color: KalinkaColors.surfaceRaised,
                      child: widget.child,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    // Confirmation overlay
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

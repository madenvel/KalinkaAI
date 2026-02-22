import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
    with SingleTickerProviderStateMixin {
  static const double _playNextIconSize = 24.0;
  static const double _playNextIconMinSize = 12.0;
  static const double _iconPadding = 16.0;
  static const double _maxDrag = 200.0;
  static const double _hapticThreshold = _maxDrag / 3.0; // 1/3 of max drag

  double _dragOffset = 0.0;
  bool _dragging = false;
  bool _hapticTriggered = false;

  late AnimationController _snapController;
  late Animation<double> _snapAnimation;

  @override
  void initState() {
    super.initState();
    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _snapAnimation = _snapController.drive(Tween(begin: 0.0, end: 0.0));
    _snapController.addListener(() {
      setState(() => _dragOffset = _snapAnimation.value);
    });
  }

  @override
  void dispose() {
    _snapController.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!widget.enabled) return;

    setState(() {
      _dragging = true;
      _dragOffset = (_dragOffset + details.delta.dx).clamp(0.0, _maxDrag);
    });

    // Trigger haptic at 1/3 threshold
    if (_dragOffset >= _hapticThreshold && !_hapticTriggered) {
      _hapticTriggered = true;
      KalinkaHaptics.mediumImpact();
    } else if (_dragOffset < _hapticThreshold && _hapticTriggered) {
      _hapticTriggered = false;
    }
  }

  void _onDragEnd(DragEndDetails details) {
    if (!widget.enabled) return;

    _dragging = false;

    final bool triggerPlayNext = _dragOffset >= _hapticThreshold;

    _animateSnap(
      0.0,
      onComplete: () {
        if (triggerPlayNext) {
          widget.onPlayNext();
        }
      },
    );
  }

  void _animateSnap(double target, {VoidCallback? onComplete}) {
    _snapAnimation = Tween(
      begin: _dragOffset,
      end: target,
    ).animate(CurvedAnimation(parent: _snapController, curve: Curves.easeOut));
    _snapController.forward(from: 0.0).then((_) {
      if (target == 0.0) {
        _hapticTriggered = false;
      }
      onComplete?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled ||
        _dragOffset == 0.0 && !_dragging && !_snapController.isAnimating) {
      // Pass-through: no swipe state, just render child with drag detection
      return GestureDetector(
        onHorizontalDragUpdate: _onDragUpdate,
        onHorizontalDragEnd: _onDragEnd,
        child: widget.child,
      );
    }

    // Icon zoom calculation: zooms until 1/3 threshold, then stays stable
    final progress = (_dragOffset / _hapticThreshold).clamp(0.0, 1.0);
    final iconSize =
        _playNextIconMinSize +
        (_playNextIconSize - _playNextIconMinSize) * progress;

    // Background is visible immediately on any drag
    const bgColor = KalinkaColors.accentTint; // Neutral from theme palette

    return GestureDetector(
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
}

import 'package:flutter/material.dart';
import '../utils/haptics.dart';
import 'now_playing_content.dart';

/// Full-screen expanded player overlay that slides up from bottom.
/// Used in phone layout only. Wraps [NowPlayingContent] with a slide animation.
///
/// Swiping down from the header area (80px) drives the animation interactively
/// and dismisses the overlay when released past the threshold or with enough velocity.
class ExpandedPlayerOverlay extends StatefulWidget {
  final AnimationController animationController;
  final VoidCallback onClose;

  const ExpandedPlayerOverlay({
    super.key,
    required this.animationController,
    required this.onClose,
  });

  @override
  State<ExpandedPlayerOverlay> createState() => _ExpandedPlayerOverlayState();
}

class _ExpandedPlayerOverlayState extends State<ExpandedPlayerOverlay> {
  double _dragStartY = 0.0;
  double _animValueAtDragStart = 0.0;
  bool _dismissHapticFired = false;

  static const double _dismissVelocityThreshold = 500.0; // px/s downward
  static const double _dismissValueThreshold = 0.70;

  void _onDragStart(DragStartDetails d) {
    _dragStartY = d.globalPosition.dy;
    _animValueAtDragStart = widget.animationController.value;
    _dismissHapticFired = false;
    widget.animationController.stop();
  }

  void _onDragUpdate(DragUpdateDetails d) {
    final screenH = MediaQuery.of(context).size.height;
    final traveled = d.globalPosition.dy - _dragStartY;
    final newVal =
        (_animValueAtDragStart - traveled / screenH).clamp(0.0, 1.0);
    widget.animationController.value = newVal;

    if (!_dismissHapticFired && newVal < _dismissValueThreshold) {
      _dismissHapticFired = true;
      KalinkaHaptics.mediumImpact();
    } else if (_dismissHapticFired && newVal >= _dismissValueThreshold) {
      _dismissHapticFired = false;
    }
  }

  void _onDragEnd(DragEndDetails d) {
    final velocity = d.primaryVelocity ?? 0.0; // positive = downward
    final shouldDismiss =
        widget.animationController.value < _dismissValueThreshold ||
        velocity > _dismissVelocityThreshold;

    if (shouldDismiss) {
      // Animate to 0; the addStatusListener in MusicPlayerScreen sets _playerOpen=false
      widget.animationController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutQuart,
      );
    } else {
      // Snap back to fully open
      widget.animationController.animateTo(
        1.0,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      // Use raw controller (no CurvedAnimation) for 1:1 finger tracking during drag.
      // Easing is applied via animateTo(..., curve: ...) in MusicPlayerScreen.
      position: Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(widget.animationController),
      child: Stack(
        children: [
          NowPlayingContent(showOverlayHeader: true, onClose: widget.onClose),
          // Transparent gesture zone over the 80px header — lets close-button taps through
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 80,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onVerticalDragStart: _onDragStart,
              onVerticalDragUpdate: _onDragUpdate,
              onVerticalDragEnd: _onDragEnd,
            ),
          ),
        ],
      ),
    );
  }
}

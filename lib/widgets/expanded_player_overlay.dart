import 'package:flutter/material.dart';
import 'now_playing_content.dart';

/// Full-screen expanded player overlay that slides up from bottom.
/// Used in phone layout only. Wraps [NowPlayingContent] with a slide animation.
class ExpandedPlayerOverlay extends StatelessWidget {
  final AnimationController animationController;
  final VoidCallback onClose;

  const ExpandedPlayerOverlay({
    super.key,
    required this.animationController,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final animation = CurvedAnimation(
      parent: animationController,
      curve: Curves.easeInOutQuart,
    );

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(animation),
      child: NowPlayingContent(showOverlayHeader: true, onClose: onClose),
    );
  }
}

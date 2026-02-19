import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Wraps a child widget to support left-swipe revealing action buttons.
/// Left-swipe translates the item left to reveal "play next" and "remove" buttons.
class SwipeRevealItem extends StatefulWidget {
  final Widget child;
  final bool isRevealed;
  final VoidCallback? onReveal;
  final VoidCallback? onPlayNext;
  final VoidCallback? onDelete;

  const SwipeRevealItem({
    super.key,
    required this.child,
    this.isRevealed = false,
    this.onReveal,
    this.onPlayNext,
    this.onDelete,
  });

  @override
  State<SwipeRevealItem> createState() => _SwipeRevealItemState();
}

class _SwipeRevealItemState extends State<SwipeRevealItem> {
  double _dragOffset = 0;
  static const _revealWidth = 100.0;

  @override
  void didUpdateWidget(SwipeRevealItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isRevealed && oldWidget.isRevealed) {
      _dragOffset = 0;
    } else if (widget.isRevealed && !oldWidget.isRevealed) {
      _dragOffset = -_revealWidth;
    }
  }

  @override
  Widget build(BuildContext context) {
    final offset = widget.isRevealed ? -_revealWidth : _dragOffset;

    return SizedBox(
      height: 60,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // Action buttons (positioned at right edge, behind content)
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: _revealWidth,
            child: Row(
              children: [
                const SizedBox(width: 4),
                // Play next button
                _ActionButton(
                  icon: Icons.skip_next_rounded,
                  color: KalinkaColors.accent,
                  onTap: widget.onPlayNext,
                ),
                const SizedBox(width: 4),
                // Remove button
                _ActionButton(
                  icon: Icons.delete_outline,
                  color: KalinkaColors.deleteRed,
                  onTap: widget.onDelete,
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
          // Main content (slides left on swipe)
          GestureDetector(
            onHorizontalDragUpdate: (details) {
              setState(() {
                _dragOffset = (_dragOffset + details.delta.dx).clamp(
                  -_revealWidth,
                  0,
                );
              });
            },
            onHorizontalDragEnd: (details) {
              if (_dragOffset < -_revealWidth / 2) {
                setState(() => _dragOffset = -_revealWidth);
                widget.onReveal?.call();
              } else {
                setState(() => _dragOffset = 0);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              transform: Matrix4.translationValues(offset, 0, 0),
              color: KalinkaColors.background,
              child: widget.child,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Icon(icon, size: 22, color: color),
          ),
        ),
      ),
    );
  }
}

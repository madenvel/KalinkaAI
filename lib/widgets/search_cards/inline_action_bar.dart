import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';

/// Compact pill-shaped action buttons for expanded accordion cards.
/// Displays: Play, Play Next, Queue.
class InlineActionBar extends StatelessWidget {
  final VoidCallback onPlay;
  final VoidCallback onPlayNext;
  final VoidCallback onQueueAll;

  const InlineActionBar({
    super.key,
    required this.onPlay,
    required this.onPlayNext,
    required this.onQueueAll,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _ActionPill(
            icon: Icons.play_arrow,
            label: 'PLAY',
            color: KalinkaColors.accent,
            onTap: onPlay,
          ),
          const SizedBox(width: 8),
          _ActionPill(
            icon: Icons.skip_next,
            label: 'NEXT',
            color: KalinkaColors.textSecondary,
            onTap: onPlayNext,
          ),
          const SizedBox(width: 8),
          _ActionPill(
            icon: Icons.add,
            label: 'QUEUE',
            color: KalinkaColors.textSecondary,
            onTap: onQueueAll,
          ),
        ],
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  final IconData icon;
  final String? label;
  final Color color;
  final VoidCallback onTap;

  const _ActionPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: label != null ? 11 : 8,
          vertical: 7,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: color.withValues(alpha: 0.28),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            if (label != null) ...[
              const SizedBox(width: 4),
              Text(
                label!,
                style: KalinkaTextStyles.browseButtonLabel.copyWith(
                  color: color,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

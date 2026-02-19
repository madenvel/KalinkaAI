import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Pulsing AI search pill in the header zone.
class AiSearchPill extends StatefulWidget {
  final VoidCallback? onTap;

  const AiSearchPill({super.key, this.onTap});

  @override
  State<AiSearchPill> createState() => _AiSearchPillState();
}

class _AiSearchPillState extends State<AiSearchPill>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 0.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: KalinkaColors.accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: KalinkaColors.accent, width: 1.5),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            // Search icon
            const Icon(Icons.search, size: 18, color: KalinkaColors.accent),
            const SizedBox(width: 10),
            // Placeholder text
            Expanded(
              child: Text(
                'Search music\u2026',
                style: KalinkaTextStyles.searchPlaceholder,
              ),
            ),
            const SizedBox(width: 10),
            // AI badge with pulsing dot
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: KalinkaColors.accent.withValues(alpha: 0.12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('AI', style: KalinkaTextStyles.aiBadge),
                  const SizedBox(width: 4),
                  FadeTransition(
                    opacity: _pulseAnimation,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: KalinkaColors.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

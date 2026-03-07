import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Empty queue state — shown when the queue contains no tracks.
/// Displays procedural art, title, subtitle, and a pulsing search hint chip.
class EmptyQueueState extends StatefulWidget {
  final VoidCallback? onSearchTap;

  const EmptyQueueState({super.key, this.onSearchTap});

  @override
  State<EmptyQueueState> createState() => _EmptyQueueStateState();
}

class _EmptyQueueStateState extends State<EmptyQueueState>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.0, end: 6.0).animate(
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
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Procedural art element
                  SizedBox(
                    width: 100,
                    height: 100,
                    child: CustomPaint(painter: _EmptyQueueArtPainter()),
                  ),
                  const SizedBox(height: 24),
                  // Title
                  Text(
                    'Nothing Queued',
                    style: KalinkaTextStyles.emptyQueueTitle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  // Subtitle
                  Text(
                    'Search to Add Music',
                    style: KalinkaTextStyles.emptyQueueSubtitle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  // Search hint chip with pulse
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return GestureDetector(
                        onTap: widget.onSearchTap,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: KalinkaColors.surfaceInput,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: KalinkaColors.accent.withValues(
                                alpha: 0.30,
                              ),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: KalinkaColors.accent.withValues(
                                  alpha:
                                      0.04 +
                                      (_pulseAnimation.value / 6.0) * 0.11,
                                ),
                                blurRadius: _pulseAnimation.value,
                                spreadRadius: _pulseAnimation.value * 0.5,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.search,
                                size: 13,
                                color: KalinkaColors.accent.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Tap to Search',
                                style: KalinkaTextStyles.recentChipLabel,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Procedural art for the empty queue state: concentric rings with colored dots.
class _EmptyQueueArtPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // Three concentric rings
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    ringPaint.color = Colors.white.withValues(alpha: 0.05);
    canvas.drawCircle(center, maxRadius * 0.90, ringPaint); // ~45px

    ringPaint.color = Colors.white.withValues(alpha: 0.04);
    canvas.drawCircle(center, maxRadius * 0.64, ringPaint); // ~32px

    ringPaint.color = Colors.white.withValues(alpha: 0.05);
    canvas.drawCircle(center, maxRadius * 0.38, ringPaint); // ~19px

    // Center accent dot
    canvas.drawCircle(
      center,
      5,
      Paint()..color = KalinkaColors.accent.withValues(alpha: 0.40),
    );

    // Gold dot offset upper-left
    canvas.drawCircle(
      Offset(center.dx - 22, center.dy - 26),
      4,
      Paint()..color = KalinkaColors.gold.withValues(alpha: 0.20),
    );

    // Small accent dot lower-right
    canvas.drawCircle(
      Offset(center.dx + 24, center.dy + 18),
      2.5,
      Paint()..color = KalinkaColors.accent.withValues(alpha: 0.25),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

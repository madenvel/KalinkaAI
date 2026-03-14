import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Empty queue state — shown when the queue contains no tracks.
/// Displays procedural art, title, and subtitle.
///
/// When [isOffline] is true (no server connection), the content is dimmed and
/// the subtitle prompts the user to connect rather than search.
class EmptyQueueState extends StatelessWidget {
  final bool isOffline;

  const EmptyQueueState({super.key, this.isOffline = false});

  @override
  Widget build(BuildContext context) {
    final content = LayoutBuilder(
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
                    isOffline
                        ? 'Connect to Server to See Music'
                        : 'Search to Add Music',
                    style: KalinkaTextStyles.emptyQueueSubtitle,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (isOffline) {
      return Opacity(opacity: 0.45, child: content);
    }
    return content;
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

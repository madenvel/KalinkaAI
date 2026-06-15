import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Empty state for the Modules / Devices settings tabs when no plugins of the
/// relevant kind are installed on the server.
///
/// Mirrors the [EmptyQueueState] aesthetic — concentric procedural rings with a
/// centred icon, a Playfair display title, and a sans-serif explanation that
/// tells the user they need to install plugins to populate the list.
class ModulesEmptyState extends StatelessWidget {
  /// True for the devices tab, false for the input-modules tab. Switches the
  /// icon and copy so each tab reads correctly.
  final bool isDevice;

  const ModulesEmptyState({super.key, required this.isDevice});

  @override
  Widget build(BuildContext context) {
    final title = isDevice ? 'No Devices' : 'No Input Modules';
    final description = isDevice
        ? 'Install a device plugin on your server to let Kalinka control your '
              'playback hardware — power it on and off, adjust volume, and pause '
              'playback when it turns off.'
        : 'Install an input module plugin on your server to stream music from '
              'sources like Qobuz, Jamendo, or your local library.';
    final icon = isDevice ? Icons.speaker_outlined : Icons.extension_outlined;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 100,
                    height: 100,
                    child: CustomPaint(
                      painter: _EmptyRingsPainter(),
                      child: Center(
                        child: Icon(
                          icon,
                          size: 30,
                          color: KalinkaColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    title,
                    style: KalinkaTextStyles.emptyQueueTitle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    description,
                    style: KalinkaTextStyles.emptyQueueSubtitle.copyWith(
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
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

/// Concentric rings with a couple of offset accent dots — the same motif used
/// by the empty-queue art, sized to frame a centred icon.
class _EmptyRingsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    ringPaint.color = Colors.white.withValues(alpha: 0.05);
    canvas.drawCircle(center, maxRadius * 0.90, ringPaint);

    ringPaint.color = Colors.white.withValues(alpha: 0.04);
    canvas.drawCircle(center, maxRadius * 0.64, ringPaint);

    // Gold dot offset upper-left.
    canvas.drawCircle(
      Offset(center.dx - 24, center.dy - 28),
      4,
      Paint()..color = KalinkaColors.gold.withValues(alpha: 0.20),
    );

    // Small accent dot lower-right.
    canvas.drawCircle(
      Offset(center.dx + 26, center.dy + 20),
      2.5,
      Paint()..color = KalinkaColors.accent.withValues(alpha: 0.25),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

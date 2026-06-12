import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'kalinka_button.dart';

/// One spotlight stop of the first-run tour.
class CoachMarkStop {
  /// Key of the widget to spotlight. When the key can't be resolved
  /// (widget not mounted), the tip card shows centered without a cutout.
  final GlobalKey targetKey;
  final String title;
  final String body;

  const CoachMarkStop({
    required this.targetKey,
    required this.title,
    required this.body,
  });
}

/// One-time UI tour shown the first time the play queue appears: a dimmed
/// scrim with a cutout spotlight around each target and a tip card beneath
/// it. Tapping anywhere, or the Next button, advances; Skip ends the tour.
class CoachMarksOverlay extends StatefulWidget {
  final List<CoachMarkStop> stops;
  final VoidCallback onDismiss;

  const CoachMarksOverlay({
    super.key,
    required this.stops,
    required this.onDismiss,
  });

  @override
  State<CoachMarksOverlay> createState() => _CoachMarksOverlayState();
}

class _CoachMarksOverlayState extends State<CoachMarksOverlay> {
  int _index = 0;
  Rect? _targetRect;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolveRect());
  }

  void _resolveRect() {
    if (!mounted) return;
    final targetContext = widget.stops[_index].targetKey.currentContext;
    final targetBox = targetContext?.findRenderObject() as RenderBox?;
    final overlayBox = context.findRenderObject() as RenderBox?;
    Rect? rect;
    if (targetBox != null &&
        overlayBox != null &&
        targetBox.hasSize &&
        targetBox.attached) {
      final topLeft = targetBox.localToGlobal(
        Offset.zero,
        ancestor: overlayBox,
      );
      rect = topLeft & targetBox.size;
    }
    setState(() => _targetRect = rect);
  }

  void _next() {
    if (_index >= widget.stops.length - 1) {
      widget.onDismiss();
      return;
    }
    setState(() {
      _index++;
      _targetRect = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolveRect());
  }

  @override
  Widget build(BuildContext context) {
    final stop = widget.stops[_index];
    final isLast = _index == widget.stops.length - 1;

    return GestureDetector(
      onTap: _next,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _SpotlightPainter(cutout: _targetRect),
            ),
          ),
          _buildTipCard(stop, isLast),
        ],
      ),
    );
  }

  Widget _buildTipCard(CoachMarkStop stop, bool isLast) {
    final card = Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      constraints: const BoxConstraints(maxWidth: 420),
      decoration: BoxDecoration(
        color: KalinkaColors.surfaceRaised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KalinkaColors.borderDefault),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 40,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_index + 1} / ${widget.stops.length}',
            style: KalinkaTextStyles.sectionHeaderMuted,
          ),
          const SizedBox(height: 8),
          Text(stop.title, style: KalinkaTextStyles.cardTitle),
          const SizedBox(height: 6),
          Text(
            stop.body,
            style: KalinkaTextStyles.trayRowSublabel.copyWith(
              fontSize: KalinkaTypography.baseSize + 2,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              GestureDetector(
                onTap: widget.onDismiss,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 6,
                  ),
                  child: Text('Skip', style: KalinkaTextStyles.cancelButton),
                ),
              ),
              const Spacer(),
              KalinkaButton(
                label: isLast ? 'Done' : 'Next',
                variant: KalinkaButtonVariant.accent,
                size: KalinkaButtonSize.compact,
                onTap: _next,
              ),
            ],
          ),
        ],
      ),
    );

    // Below the spotlight when there is one, otherwise centered.
    final rect = _targetRect;
    if (rect == null) {
      return Center(child: card);
    }
    return Positioned(
      top: rect.bottom + 20,
      left: 0,
      right: 0,
      child: Align(alignment: Alignment.topCenter, child: card),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  final Rect? cutout;

  const _SpotlightPainter({this.cutout});

  @override
  void paint(Canvas canvas, Size size) {
    final scrim = Path()..addRect(Offset.zero & size);
    Path path = scrim;
    final rect = cutout;
    if (rect != null) {
      final hole = Path()
        ..addRRect(
          RRect.fromRectAndRadius(rect.inflate(6), const Radius.circular(14)),
        );
      path = Path.combine(PathOperation.difference, scrim, hole);
    }
    canvas.drawPath(
      path,
      Paint()..color = Colors.black.withValues(alpha: 0.72),
    );
    if (rect != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.inflate(6), const Radius.circular(14)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = KalinkaColors.accent.withValues(alpha: 0.8),
      );
    }
  }

  @override
  bool shouldRepaint(_SpotlightPainter oldDelegate) =>
      oldDelegate.cutout != cutout;
}

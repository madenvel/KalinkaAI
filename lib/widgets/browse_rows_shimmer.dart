import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A block of [count] shimmering placeholder rows — 44×44 artwork + two text
/// lines — pulsing under one shared controller (cheap: a single Opacity
/// rebuild, not one per row). Mirrors [TrackTileLayout]'s 12/8 padding and
/// 10px leading gap so placeholders occupy the same space as the real rows
/// they stand in for. Used as the load-more footer in paged/infinite lists.
class BrowseRowsShimmer extends StatefulWidget {
  final int count;

  /// Hairline divider above the first shimmer row, so it reads as a
  /// continuation of the list it trails rather than a detached block.
  final bool leadingDivider;

  const BrowseRowsShimmer({
    super.key,
    this.count = 3,
    this.leadingDivider = false,
  });

  @override
  State<BrowseRowsShimmer> createState() => _BrowseRowsShimmerState();
}

class _BrowseRowsShimmerState extends State<BrowseRowsShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.4, end: 0.7).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (int i = 0; i < widget.count; i++) {
      if (widget.leadingDivider || i > 0) {
        rows.add(const Divider(
          color: KalinkaColors.borderSubtle,
          thickness: 1,
          height: 14,
        ));
      }
      rows.add(_row());
    }
    return AnimatedBuilder(
      animation: _opacity,
      builder: (context, child) =>
          Opacity(opacity: _opacity.value, child: child),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: rows,
      ),
    );
  }

  Widget _row() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            _box(44),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _line(0.55, 12),
                  const SizedBox(height: 7),
                  _line(0.35, 9),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _box(double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: KalinkaColors.surfaceInput,
          borderRadius: BorderRadius.circular(6),
        ),
      );

  Widget _line(double factor, double height) => Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: factor,
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: KalinkaColors.surfaceInput,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      );
}

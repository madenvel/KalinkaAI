import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Shimmer placeholder mirroring the zero-state search structure: a RECENT
/// chip row followed by two content sections of stacked rows. Shown while
/// the connection is reconnecting or the zero-state data is (re)loading, so
/// the surface reads as "refreshing" instead of flashing stale data or a
/// scatter of per-section spinners.
class ZeroStateShimmer extends StatefulWidget {
  const ZeroStateShimmer({super.key});

  @override
  State<ZeroStateShimmer> createState() => _ZeroStateShimmerState();
}

class _ZeroStateShimmerState extends State<ZeroStateShimmer>
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
    return AnimatedBuilder(
      animation: _opacity,
      builder: (context, child) =>
          Opacity(opacity: _opacity.value, child: child),
      // Non-scrollable: it's a transient placeholder, and the real content's
      // ListView takes over (with its own scroll position) once data lands.
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          // RECENT — label + horizontal chips
          const SizedBox(height: 16),
          _bar(56, 10),
          const SizedBox(height: 12),
          Row(
            children: [
              _chip(78),
              const SizedBox(width: 6),
              _chip(104),
              const SizedBox(width: 6),
              _chip(88),
            ],
          ),
          const SizedBox(height: 8),
          // BASED ON NOW PLAYING — label + rows
          const SizedBox(height: 16),
          _bar(150, 10),
          const SizedBox(height: 12),
          ..._rows(3),
          // RECENTLY FAVOURITED — label + rows
          const SizedBox(height: 24),
          _bar(160, 10),
          const SizedBox(height: 12),
          ..._rows(3),
        ],
      ),
    );
  }

  List<Widget> _rows(int count) {
    final rows = <Widget>[];
    for (int i = 0; i < count; i++) {
      rows.add(_row());
      if (i < count - 1) {
        rows.add(const Divider(
          color: KalinkaColors.borderSubtle,
          thickness: 1,
          height: 14,
        ));
      }
    }
    return rows;
  }

  /// One row mirroring a track/album tile: 44×44 artwork + two text lines,
  /// matching [TrackTileLayout]'s 12/8 padding and 10px leading gap.
  Widget _row() {
    return Padding(
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
  }

  /// Fixed-size bar — section labels and the like.
  Widget _bar(double width, double height) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: KalinkaColors.surfaceInput,
          borderRadius: BorderRadius.circular(4),
        ),
      );

  /// Fractional-width line for row text (fills its column slot to [factor]).
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

  /// Rounded square artwork placeholder.
  Widget _box(double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: KalinkaColors.surfaceInput,
          borderRadius: BorderRadius.circular(6),
        ),
      );

  /// Stadium chip placeholder for the RECENT row.
  Widget _chip(double width) => Container(
        width: width,
        height: 30,
        decoration: BoxDecoration(
          color: KalinkaColors.surfaceInput,
          borderRadius: BorderRadius.circular(15),
        ),
      );
}

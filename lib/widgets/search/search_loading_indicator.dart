import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Staged "working" indicator shown under a query bubble while its results
/// resolve. Always visible for at least the provider's minimum loading window,
/// so a slow AI request reads as "working" rather than frozen.
class SearchLoadingIndicator extends StatefulWidget {
  const SearchLoadingIndicator({super.key});

  @override
  State<SearchLoadingIndicator> createState() => _SearchLoadingIndicatorState();
}

class _SearchLoadingIndicatorState extends State<SearchLoadingIndicator>
    with SingleTickerProviderStateMixin {
  static const _stages = [
    'Understanding your request…',
    'Searching your sources…',
    'Curating the results…',
  ];

  late final AnimationController _controller;
  Timer? _stageTimer;
  int _stage = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
    _stageTimer = Timer.periodic(const Duration(milliseconds: 1600), (_) {
      if (!mounted) return;
      setState(() => _stage = (_stage + 1) % _stages.length);
    });
  }

  @override
  void dispose() {
    _stageTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
      child: Row(
        children: [
          _buildDots(),
          const SizedBox(width: 12),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                _stages[_stage],
                key: ValueKey(_stage),
                style: KalinkaTextStyles.trackRowSubtitle.copyWith(
                  color: KalinkaColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDots() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            // Each dot pulses on a staggered phase.
            final phase = (_controller.value + i / 3) % 1.0;
            final t = (0.5 - (phase - 0.5).abs()) * 2; // triangle 0→1→0
            final scale = 0.7 + 0.3 * t;
            return Padding(
              padding: EdgeInsets.only(right: i < 2 ? 5 : 0),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Color.lerp(
                      KalinkaColors.gold.withValues(alpha: 0.35),
                      KalinkaColors.gold,
                      t,
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

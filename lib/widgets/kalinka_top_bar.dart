import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_theme.dart';
import '../utils/haptics.dart';
import 'server_chip.dart';

/// Slim top app bar for the main/queue and search screens.
///
/// The connection indicator (via [ServerChip], which carries the green status
/// dot) lives here on both screens and never leaves the top bar. On the search
/// screen a back arrow replaces the leading wordmark.
class KalinkaTopBar extends StatelessWidget {
  /// When true, the leading slot shows a back arrow (search screen) instead of
  /// the Kalinka wordmark (main screen).
  final bool showBack;
  final VoidCallback? onBack;
  final VoidCallback? onServerChipTap;

  /// Anchor for the first-run coach-mark spotlight on the connection chip.
  final GlobalKey? connectionKey;

  const KalinkaTopBar({
    super.key,
    this.showBack = false,
    this.onBack,
    this.onServerChipTap,
    this.connectionKey,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: KalinkaColors.surfaceBase,
        border: Border(
          bottom: BorderSide(color: KalinkaColors.borderDefault, width: 1),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 52,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(child: _buildLeading()),
                KeyedSubtree(
                  key: connectionKey,
                  child: ServerChip(onTap: onServerChipTap),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeading() {
    if (showBack) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Semantics(
          label: 'Close search',
          button: true,
          child: GestureDetector(
            onTap: () {
              KalinkaHaptics.lightImpact();
              onBack?.call();
            },
            behavior: HitTestBehavior.opaque,
            child: const SizedBox(
              width: 44,
              height: 44,
              child: Icon(
                Icons.arrow_back,
                size: 22,
                color: KalinkaColors.textPrimary,
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(width: 4),
        SvgPicture.asset(
          'assets/images/kalinka_icon.svg',
          height: 22,
          width: 22,
        ),
        const SizedBox(width: 10),
        Text('Kalinka', style: KalinkaTextStyles.nowPlayingLabel),
      ],
    );
  }
}

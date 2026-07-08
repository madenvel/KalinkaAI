import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_theme.dart';
import 'server_chip.dart';

/// Slim top app bar for the main/queue screen: Kalinka wordmark on the left,
/// connection chip (via [ServerChip], which carries the green status dot) on
/// the right. The search screen replaces this bar with its own header row
/// (see SearchSessionView).
class KalinkaTopBar extends StatelessWidget {
  final VoidCallback? onServerChipTap;

  /// Anchor for the first-run coach-mark spotlight on the connection chip.
  final GlobalKey? connectionKey;

  const KalinkaTopBar({super.key, this.onServerChipTap, this.connectionKey});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: kKalinkaTopBarDecoration,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: kKalinkaTopBarHeight,
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
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 4),
        child: SvgPicture.asset(
          'assets/images/kalinka_logo.svg',
          height: kKalinkaWordmarkHeight,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

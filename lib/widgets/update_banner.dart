import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/server_update_provider.dart';
import '../theme/app_theme.dart';

/// "Server upgrade available" banner shown at the top of the General
/// settings tab. Dismissal lasts until the next app start (session-scoped
/// provider). Hidden entirely when the server has no update, can't
/// self-upgrade, or predates the update endpoint.
class UpdateBanner extends ConsumerWidget {
  final VoidCallback onUpgrade;

  const UpdateBanner({super.key, required this.onUpgrade});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dismissed = ref.watch(updateBannerDismissedProvider);
    final info = ref.watch(serverUpdateProvider).value;
    if (dismissed || info == null || !info.canUpgrade) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: KalinkaColors.accent.withValues(alpha: 0.07),
        border: Border(
          bottom: BorderSide(color: KalinkaColors.accent.withValues(alpha: 0.18)),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(
            Icons.system_update_alt,
            size: 16,
            color: KalinkaColors.accent,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Kalinka server upgrade available · '
              '${info.currentVersion} → ${info.latestVersion}',
              style: KalinkaTextStyles.bannerText.copyWith(
                color: KalinkaColors.textPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onUpgrade,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: KalinkaColors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: KalinkaColors.accent.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                'UPGRADE NOW',
                style: KalinkaTextStyles.bannerText.copyWith(
                  color: KalinkaColors.accent,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () =>
                ref.read(updateBannerDismissedProvider.notifier).dismiss(),
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(
                Icons.close,
                size: 16,
                color: KalinkaColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

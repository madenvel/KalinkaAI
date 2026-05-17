import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';

/// Amber banner that appears when settings changes are staged but not yet applied.
///
/// Shows the count of pending changes, a "Discard" link, and "APPLY" button.
/// The amber tint + bold text already signal urgency clearly; an earlier
/// pulsing dot animation here turned out to be a major CPU drain (perpetual
/// 60Hz Opacity rebuild + saveLayer) and gave no information the colour
/// didn't already convey. Now a flat static dot.
class PendingChangesBanner extends ConsumerWidget {
  final VoidCallback onApply;

  const PendingChangesBanner({super.key, required this.onApply});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsState = ref.watch(settingsProvider);

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: settingsState.hasPendingChanges
          ? Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: KalinkaColors.statusPending.withValues(alpha: 0.07),
                border: Border(
                  bottom: BorderSide(
                    color: KalinkaColors.statusPending.withValues(alpha: 0.18),
                  ),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: KalinkaColors.statusPending,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${settingsState.pendingCount} change${settingsState.pendingCount == 1 ? '' : 's'} staged · restart required',
                      style: KalinkaTextStyles.bannerText.copyWith(
                        color: KalinkaColors.statusPendingLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      ref.read(settingsProvider.notifier).discardAll();
                    },
                    child: Text(
                      'Discard',
                      style: KalinkaTextStyles.cancelButton,
                    ),
                  ),
                  const SizedBox(width: 15),
                  GestureDetector(
                    onTap: onApply,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: KalinkaColors.statusPending.withValues(
                          alpha: 0.1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: KalinkaColors.statusPending.withValues(
                            alpha: 0.4,
                          ),
                        ),
                      ),
                      child: Text(
                        'APPLY',
                        style: KalinkaTextStyles.bannerText.copyWith(
                          color: KalinkaColors.statusPendingLight,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}

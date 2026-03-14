import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';

/// Amber banner that appears when settings changes are staged but not yet applied.
///
/// Shows count of pending changes, "Discard" link, and "Apply" button.
class PendingChangesBanner extends ConsumerStatefulWidget {
  final VoidCallback onApply;

  const PendingChangesBanner({super.key, required this.onApply});

  @override
  ConsumerState<PendingChangesBanner> createState() =>
      _PendingChangesBannerState();
}

class _PendingChangesBannerState extends ConsumerState<PendingChangesBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                  // Pulsing amber dot
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      final opacity =
                          0.25 + 0.75 * (1.0 - _pulseController.value);
                      return Opacity(opacity: opacity, child: child);
                    },
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: KalinkaColors.statusPending,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Text
                  Expanded(
                    child: Text(
                      '${settingsState.pendingCount} change${settingsState.pendingCount == 1 ? '' : 's'} staged \u00b7 restart required',
                      style: KalinkaTextStyles.bannerText.copyWith(
                        color: KalinkaColors.statusPendingLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Discard link
                  GestureDetector(
                    onTap: () {
                      ref.read(settingsProvider.notifier).discardAll();
                    },
                    child: Text(
                      'Discard',
                      style: KalinkaTextStyles.bannerText.copyWith(
                        color: KalinkaColors.textMuted,
                        fontSize: 10,
                        decoration: TextDecoration.underline,
                        decorationColor: KalinkaColors.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  // Apply button
                  GestureDetector(
                    onTap: widget.onApply,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: KalinkaColors.statusPending.withValues(
                          alpha: 0.2,
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

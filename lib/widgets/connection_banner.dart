import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/connection_settings_provider.dart';
import '../providers/connection_state_provider.dart';
import '../theme/app_theme.dart';

/// Thin banner below the header zone showing reconnecting/offline state.
///
/// Smoothly animates in/out via [AnimatedSize]. Shows nothing when connected.
class ConnectionBanner extends ConsumerStatefulWidget {
  const ConnectionBanner({super.key});

  @override
  ConsumerState<ConnectionBanner> createState() => _ConnectionBannerState();
}

class _ConnectionBannerState extends ConsumerState<ConnectionBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connectionState = ref.watch(connectionStateProvider);
    final settings = ref.watch(connectionSettingsProvider);
    final name = settings.name.isNotEmpty ? settings.name : settings.host;

    return AnimatedSize(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: switch (connectionState) {
        ConnectionStatus.reconnecting => _buildBanner(
          bgColor: KalinkaColors.statusPending.withValues(alpha: 0.07),
          borderColor: KalinkaColors.statusPending.withValues(alpha: 0.18),
          dotColor: KalinkaColors.statusPending,
          pulseDot: true,
          text: 'Reconnecting to $name \u00b7 retrying\u2026',
          textColor: KalinkaColors.statusPendingLight,
        ),
        ConnectionStatus.offline => _buildBanner(
          bgColor: KalinkaColors.statusError.withValues(alpha: 0.08),
          borderColor: KalinkaColors.statusError.withValues(alpha: 0.18),
          dotColor: KalinkaColors.statusError,
          pulseDot: false,
          text: '$name unreachable \u00b7 queue shown from last sync',
          textColor: const Color(0xFFF87171),
          showRetry: true,
        ),
        _ => const SizedBox.shrink(),
      },
    );
  }

  Widget _buildBanner({
    required Color bgColor,
    required Color borderColor,
    required Color dotColor,
    required bool pulseDot,
    required String text,
    required Color textColor,
    bool showRetry = false,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(bottom: BorderSide(color: borderColor, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Dot
          if (pulseDot)
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final opacity = 0.25 + 0.75 * (1.0 - _pulseController.value);
                return Opacity(opacity: opacity, child: child);
              },
              child: _buildDot(dotColor),
            )
          else
            _buildDot(dotColor),
          const SizedBox(width: 8),
          // Text
          Expanded(
            child: Text(
              text,
              style: KalinkaTextStyles.bannerText.copyWith(color: textColor),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Retry button (offline only)
          if (showRetry) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                ref.read(connectionStateProvider.notifier).retryNow();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: KalinkaColors.statusError.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  'Retry',
                  style: KalinkaTextStyles.bannerText.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDot(Color color) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

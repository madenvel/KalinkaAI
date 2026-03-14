import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/connection_settings_provider.dart';
import '../providers/connection_state_provider.dart';
import '../theme/app_theme.dart';

/// Card that appears above the mini-player after 30s of failed reconnection.
///
/// Offers "Scan for servers" and "Retry" actions, plus a dismiss link.
/// Once dismissed, it won't reappear until the app restarts.
class EscalationCard extends ConsumerStatefulWidget {
  final VoidCallback onScanForServers;

  const EscalationCard({super.key, required this.onScanForServers});

  @override
  ConsumerState<EscalationCard> createState() => _EscalationCardState();
}

class _EscalationCardState extends ConsumerState<EscalationCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _entryController;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connectionState = ref.watch(connectionStateProvider);
    final notifier = ref.read(connectionStateProvider.notifier);
    final settings = ref.watch(connectionSettingsProvider);
    final name = settings.name.isNotEmpty ? settings.name : settings.host;

    // Only show when offline/reconnecting AND escalation reached AND not dismissed
    final shouldShow =
        (connectionState == ConnectionStatus.offline ||
            connectionState == ConnectionStatus.reconnecting) &&
        notifier.escalationReached &&
        !notifier.escalationDismissed;

    if (!shouldShow) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _entryController,
      builder: (context, child) {
        final curve = Curves.easeOut.transform(_entryController.value);
        return Transform.translate(
          offset: Offset(0, 20 * (1 - curve)),
          child: Opacity(opacity: curve, child: child),
        );
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: KalinkaColors.surfaceRaised,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: KalinkaColors.statusOffline.withValues(alpha: 0.25),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Red info icon tile
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: KalinkaColors.statusOffline.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.info_outline,
                      size: 16,
                      color: KalinkaColors.statusOffline,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '$name is unavailable',
                      style: KalinkaTextStyles.trayRowLabel.copyWith(
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'The server hasn\'t responded for over 30 seconds. '
                'It may be offline or unreachable on the network.',
                style: KalinkaTextStyles.trayRowSublabel.copyWith(
                  fontSize: 10,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 14),
              // Action buttons
              Row(
                children: [
                  // Scan for servers — accent tint
                  GestureDetector(
                    onTap: widget.onScanForServers,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: KalinkaColors.accent),
                      ),
                      child: Text(
                        'Scan for servers',
                        style: KalinkaTextStyles.trayRowLabel.copyWith(
                          color: KalinkaColors.accentTint,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Retry — muted
                  GestureDetector(
                    onTap: () {
                      ref.read(connectionStateProvider.notifier).retryNow();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: KalinkaColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: KalinkaColors.borderDefault),
                      ),
                      child: Text(
                        'Retry',
                        style: KalinkaTextStyles.trayRowLabel.copyWith(
                          color: KalinkaColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data_model/kalinka_ws_api.dart';

import '../providers/app_state_provider.dart';
import '../providers/kalinka_ws_api_provider.dart';
import '../theme/app_theme.dart';
import '../utils/haptics.dart';

/// Actions that can be returned from the queue management tray.
enum TrayAction { clearPlayed, clearAll }

/// Content body for the queue management tray — used directly by
/// [showKalinkaBottomSheet] on phone.
class QueueManagementTrayContent extends ConsumerWidget {
  const QueueManagementTrayContent({super.key});

  void _setRepeatMode(WidgetRef ref, {required bool repeatAll, required bool repeatSingle}) {
    final playbackMode = ref.read(playbackModeProvider);
    ref
        .read(kalinkaWsApiProvider)
        .sendQueueCommand(
          QueueCommand.setPlaybackMode(
            shuffle: playbackMode.shuffle,
            repeatAll: repeatAll,
            repeatSingle: repeatSingle,
          ),
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playbackMode = ref.watch(playbackModeProvider);
    final isRepeatAll = playbackMode.repeatAll;
    final isRepeatOne = playbackMode.repeatSingle;
    final isShuffle = playbackMode.shuffle;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        // Section: PLAYBACK
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text(
            'PLAYBACK',
            style: KalinkaTextStyles.traySectionLabel,
          ),
        ),

        // Shuffle row
        _TrayRow(
          icon: Icons.shuffle,
          iconBgColor: KalinkaColors.gold.withValues(alpha: 0.14),
          iconColor: KalinkaColors.gold,
          label: 'Shuffle',
          sublabel: isShuffle
              ? 'On \u2014 playing in random order'
              : 'Off \u2014 plays in order',
          trailing: _buildToggleSwitch(
            value: isShuffle,
            activeColor: KalinkaColors.gold,
            onTap: () {
              isShuffle
                  ? KalinkaHaptics.lightImpact()
                  : KalinkaHaptics.mediumImpact();
              // Shuffle not yet wired to API
            },
          ),
        ),
        // Divider between rows
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Divider(
            color: Colors.white.withValues(alpha: 0.07),
            height: 1,
          ),
        ),
        // Repeat row — segmented control
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          child: Row(
            children: [
              // Icon container
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: KalinkaColors.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isRepeatOne ? Icons.repeat_one : Icons.repeat,
                  size: 16,
                  color: KalinkaColors.accent,
                ),
              ),
              const SizedBox(width: 14),
              // Label
              Text('Repeat', style: KalinkaTextStyles.trayRowLabel),
              const Spacer(),
              // Segmented control
              _RepeatSegmentedControl(
                repeatAll: isRepeatAll,
                repeatOne: isRepeatOne,
                onChanged: (repeatAll, repeatSingle) {
                  _setRepeatMode(ref, repeatAll: repeatAll, repeatSingle: repeatSingle);
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),
        // Section divider
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Divider(
            color: Colors.white.withValues(alpha: 0.07),
            height: 1,
          ),
        ),
        const SizedBox(height: 12),

        // Section: QUEUE
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text(
            'QUEUE',
            style: KalinkaTextStyles.traySectionLabel,
          ),
        ),

        // Clear played row
        _TrayRow(
          icon: Icons.history,
          iconBgColor: KalinkaColors.surfaceElevated,
          iconColor: KalinkaColors.textSecondary,
          label: 'Clear played',
          sublabel: 'Remove played tracks from history',
          onTap: () {
            KalinkaHaptics.mediumImpact();
            Navigator.pop(context, TrayAction.clearPlayed);
          },
        ),
        // Divider between rows
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Divider(
            color: Colors.white.withValues(alpha: 0.07),
            height: 1,
          ),
        ),
        // Clear all row (danger)
        _TrayRow(
          icon: Icons.delete_outline,
          iconBgColor: KalinkaColors.actionDelete.withValues(alpha: 0.12),
          iconColor: KalinkaColors.actionDelete,
          label: 'Clear all',
          sublabel: 'Remove everything from queue',
          isDanger: true,
          onTap: () {
            KalinkaHaptics.heavyImpact();
            Navigator.pop(context, TrayAction.clearAll);
          },
        ),
      ],
    );
  }

  Widget _buildToggleSwitch({
    required bool value,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        width: 42,
        height: 24,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: value ? activeColor : KalinkaColors.surfaceElevated,
          border: value ? null : Border.all(color: KalinkaColors.borderDefault),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 16,
            height: 16,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: value ? Colors.white : KalinkaColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _TrayRow extends StatelessWidget {
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final String label;
  final String sublabel;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool isDanger;

  const _TrayRow({
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.label,
    required this.sublabel,
    this.trailing,
    this.onTap,
    this.isDanger = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? (trailing != null ? null : () {}),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        child: Row(
          children: [
            // Icon container
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 16, color: iconColor),
            ),
            const SizedBox(width: 14),
            // Label + sublabel
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: isDanger
                        ? KalinkaTextStyles.trayRowLabel.copyWith(
                            color: KalinkaColors.actionDelete,
                          )
                        : KalinkaTextStyles.trayRowLabel,
                  ),
                  const SizedBox(height: 2),
                  Text(sublabel, style: KalinkaTextStyles.trayRowSublabel),
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 12), trailing!],
          ],
        ),
      ),
    );
  }
}

/// Three-segment pill control for repeat mode: Off / All / One.
class _RepeatSegmentedControl extends StatelessWidget {
  final bool repeatAll;
  final bool repeatOne;
  final void Function(bool repeatAll, bool repeatSingle) onChanged;

  const _RepeatSegmentedControl({
    required this.repeatAll,
    required this.repeatOne,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: KalinkaColors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: KalinkaColors.borderDefault),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSegment(
            label: 'Off',
            isActive: !repeatAll && !repeatOne,
            onTap: () => onChanged(false, false),
          ),
          _buildSegment(
            label: 'All',
            isActive: repeatAll,
            onTap: () => onChanged(true, false),
          ),
          _buildSegment(
            label: 'One',
            isActive: repeatOne,
            onTap: () => onChanged(false, true),
          ),
        ],
      ),
    );
  }

  Widget _buildSegment({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        KalinkaHaptics.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? KalinkaColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          label,
          style: KalinkaTextStyles.trayRowSublabel.copyWith(
            color: isActive ? Colors.white : KalinkaColors.textSecondary,
            fontWeight: isActive ? FontWeight.w500 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

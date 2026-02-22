import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data_model/kalinka_ws_api.dart';
import '../providers/add_mode_provider.dart';
import '../providers/app_state_provider.dart';
import '../providers/kalinka_ws_api_provider.dart';
import '../theme/app_theme.dart';
import '../utils/haptics.dart';

/// Management tray — slides up from the bottom with playback and queue controls.
class QueueManagementTray extends ConsumerStatefulWidget {
  final VoidCallback onClose;
  final VoidCallback onClearPlayed;
  final VoidCallback onClearAllRequested;

  const QueueManagementTray({
    super.key,
    required this.onClose,
    required this.onClearPlayed,
    required this.onClearAllRequested,
  });

  @override
  ConsumerState<QueueManagementTray> createState() =>
      _QueueManagementTrayState();
}

class _QueueManagementTrayState extends ConsumerState<QueueManagementTray>
    with SingleTickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _slideController,
            curve: const Cubic(0.4, 0, 0.2, 1),
          ),
        );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _slideController,
        curve: const Interval(0.0, 0.75, curve: Curves.easeOut),
      ),
    );
    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _animateClose() async {
    await _slideController.reverse();
    widget.onClose();
  }

  void _setRepeatMode({required bool repeatAll, required bool repeatSingle}) {
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
  Widget build(BuildContext context) {
    final playbackMode = ref.watch(playbackModeProvider);
    final isRepeatAll = playbackMode.repeatAll;
    final isRepeatOne = playbackMode.repeatSingle;
    final isShuffle = playbackMode.shuffle;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: GestureDetector(
        onTap: _animateClose,
        child: Container(
          color: Colors.black.withValues(alpha: 0.60),
          child: Column(
            children: [
              const Spacer(),
              SlideTransition(
                position: _slideAnimation,
                child: GestureDetector(
                  // Prevent backdrop tap from passing through
                  onTap: () {},
                  child: Container(
                    decoration: BoxDecoration(
                      color: KalinkaColors.miniPlayerSurface,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                      border: const Border(
                        top: BorderSide(color: KalinkaColors.borderElevated),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.7),
                          blurRadius: 60,
                          offset: const Offset(0, -20),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Drag handle
                            Center(
                              child: Container(
                                width: 36,
                                height: 4,
                                margin: const EdgeInsets.only(top: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2A2A32),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                            // Title
                            Padding(
                              padding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
                              child: Center(
                                child: Text(
                                  'QUEUE OPTIONS',
                                  style: KalinkaTextStyles.trayTitle,
                                ),
                              ),
                            ),

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
                              iconBgColor: KalinkaColors.gold.withValues(
                                alpha: 0.14,
                              ),
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              child: Divider(
                                color: Colors.white.withValues(alpha: 0.07),
                                height: 1,
                              ),
                            ),
                            // Repeat row — segmented control
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 13,
                              ),
                              child: Row(
                                children: [
                                  // Icon container
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: KalinkaColors.accent.withValues(
                                        alpha: 0.14,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      isRepeatOne
                                          ? Icons.repeat_one
                                          : Icons.repeat,
                                      size: 16,
                                      color: KalinkaColors.accent,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  // Label
                                  Text(
                                    'Repeat',
                                    style: KalinkaTextStyles.trayRowLabel,
                                  ),
                                  const Spacer(),
                                  // Segmented control
                                  _RepeatSegmentedControl(
                                    repeatAll: isRepeatAll,
                                    repeatOne: isRepeatOne,
                                    onChanged: (repeatAll, repeatSingle) {
                                      _setRepeatMode(
                                        repeatAll: repeatAll,
                                        repeatSingle: repeatSingle,
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 8),
                            // Section divider
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              child: Divider(
                                color: Colors.white.withValues(alpha: 0.07),
                                height: 1,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Section: ADDING
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                              child: Text(
                                'ADDING',
                                style: KalinkaTextStyles.traySectionLabel,
                              ),
                            ),

                            // Adding mode row — segmented control
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 13,
                              ),
                              child: Row(
                                children: [
                                  // Icon container
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: KalinkaColors.gold.withValues(
                                        alpha: 0.14,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.playlist_add,
                                      size: 16,
                                      color: KalinkaColors.gold,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  // Label
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'When adding to queue',
                                          style: KalinkaTextStyles.trayRowLabel,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          ref.watch(addModeProvider).addMode ==
                                                  AddMode.askEachTime
                                              ? 'Choose Play next, Append, or Add to playlist'
                                              : 'Adds to end of queue instantly',
                                          style:
                                              KalinkaTextStyles.trayRowSublabel,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Segmented control
                                  _AddModeSegmentedControl(
                                    addMode: ref.watch(addModeProvider).addMode,
                                    onChanged: (mode) {
                                      ref
                                          .read(addModeProvider.notifier)
                                          .setAddMode(mode);
                                    },
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 8),
                            // Section divider
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
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
                              iconBgColor: KalinkaColors.pillSurface,
                              iconColor: KalinkaColors.textSecondary,
                              label: 'Clear played',
                              sublabel: 'Remove played tracks from history',
                              onTap: () async {
                                KalinkaHaptics.mediumImpact();
                                await _animateClose();
                                widget.onClearPlayed();
                              },
                            ),
                            // Divider between rows
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              child: Divider(
                                color: Colors.white.withValues(alpha: 0.07),
                                height: 1,
                              ),
                            ),
                            // Clear all row (danger)
                            _TrayRow(
                              icon: Icons.delete_outline,
                              iconBgColor: KalinkaColors.deleteRed.withValues(
                                alpha: 0.12,
                              ),
                              iconColor: KalinkaColors.deleteRed,
                              label: 'Clear all',
                              sublabel: 'Remove everything from queue',
                              isDanger: true,
                              onTap: () async {
                                KalinkaHaptics.heavyImpact();
                                await _animateClose();
                                widget.onClearAllRequested();
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
          color: value ? activeColor : KalinkaColors.pillSurface,
          border: value
              ? null
              : Border.all(color: KalinkaColors.borderElevated),
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
                            color: KalinkaColors.deleteRed,
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
        color: KalinkaColors.pillSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: KalinkaColors.borderElevated),
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

/// Two-segment pill control for add mode: Ask each time / Always append.
class _AddModeSegmentedControl extends StatelessWidget {
  final AddMode addMode;
  final void Function(AddMode mode) onChanged;

  const _AddModeSegmentedControl({
    required this.addMode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: KalinkaColors.pillSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: KalinkaColors.borderElevated),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSegment(
            label: 'Ask',
            isActive: addMode == AddMode.askEachTime,
            onTap: () => onChanged(AddMode.askEachTime),
          ),
          _buildSegment(
            label: 'Append',
            isActive: addMode == AddMode.alwaysAppend,
            onTap: () => onChanged(AddMode.alwaysAppend),
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
          color: isActive ? KalinkaColors.gold : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          label,
          style: KalinkaTextStyles.trayRowSublabel.copyWith(
            color: isActive ? Colors.black : KalinkaColors.textSecondary,
            fontWeight: isActive ? FontWeight.w500 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

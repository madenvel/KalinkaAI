import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/selection_state_provider.dart';
import '../providers/kalinka_player_api_provider.dart';
import '../providers/toast_provider.dart';
import '../theme/app_theme.dart';
import '../utils/play_next.dart';
import '../utils/haptics.dart';

/// Bottom batch bar shown during multi-select mode.
/// "N SELECTED" label + Cancel (✕) chip, then Play now / Play next / queue.
class MultiSelectBottomBar extends ConsumerWidget {
  const MultiSelectBottomBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(selectionStateProvider);

    return AnimatedSlide(
      offset: selection.isActive ? Offset.zero : const Offset(0, 1),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutQuart,
      child: AnimatedOpacity(
        opacity: selection.isActive ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: BoxDecoration(
            color: KalinkaColors.surfaceInput,
            border: const Border(
              top: BorderSide(color: KalinkaColors.borderDefault, width: 1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Left-aligned "N SELECTED" label + a labelled Cancel chip on
                // the right (clear tap target, unambiguous action). The label
                // stays generic because selection.count mixes tracks and
                // containers (albums/artists/playlists) — calling them all
                // "tracks" would misreport the count.
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Text(
                        '${selection.count} SELECTED',
                        style: KalinkaTextStyles.batchBarLabel,
                      ),
                      const Spacer(),
                      _CancelChip(
                        onTap: () {
                          KalinkaHaptics.lightImpact();
                          ref
                              .read(selectionStateProvider.notifier)
                              .exitSelectionMode();
                        },
                      ),
                    ],
                  ),
                ),
                // Three buttons: Play now | Play next | Add to queue
                Row(
                  children: [
                    Expanded(
                      child: _BatchActionButton(
                        icon: Icons.play_arrow,
                        label: 'Play now',
                        onTap: selection.count > 0
                            ? () {
                                KalinkaHaptics.mediumImpact();
                                _playNow(ref, selection);
                              }
                            : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _BatchActionButton(
                        icon: Icons.arrow_upward,
                        label: 'Play next',
                        onTap: selection.count > 0
                            ? () {
                                KalinkaHaptics.mediumImpact();
                                _playNext(ref, selection);
                              }
                            : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _BatchActionButton(
                        icon: Icons.playlist_add,
                        label: 'Add to queue',
                        onTap: selection.count > 0
                            ? () {
                                KalinkaHaptics.mediumImpact();
                                _appendToQueue(ref, selection);
                              }
                            : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Each action dismisses the panel immediately and reports progress via the
  // shared spinner. `selection` is a tap-time snapshot, so its count stays
  // valid after exitSelectionMode() as a fallback.

  Future<void> _appendToQueue(WidgetRef ref, SelectionState selection) async {
    final api = ref.read(kalinkaProxyProvider);
    final toast = ref.read(toastProvider.notifier);
    final selectionNotifier = ref.read(selectionStateProvider.notifier);
    final ids = selectionNotifier.resolveIdsForApi();
    selectionNotifier.exitSelectionMode();
    toast.beginQueueActivity('Adding to queue…');
    try {
      // Use the server's expanded count, not selection.count (album = 1 item).
      final added = await api.add(ids);
      final n = added.count ?? selection.count;
      toast.endQueueActivity(
        '$n ${n == 1 ? 'track' : 'tracks'} added to queue',
      );
    } catch (e) {
      toast.endQueueActivity('Failed to add to queue: $e', isError: true);
    }
  }

  Future<void> _playNow(WidgetRef ref, SelectionState selection) async {
    final api = ref.read(kalinkaProxyProvider);
    final toast = ref.read(toastProvider.notifier);
    final selectionNotifier = ref.read(selectionStateProvider.notifier);
    final ids = selectionNotifier.resolveIdsForApi();
    selectionNotifier.exitSelectionMode();
    toast.beginQueueActivity('Starting playback…');
    try {
      await api.clear();
      final added = await api.add(ids);
      // Explicit index 0: avoids a backend race where a stale FINISHED from the
      // cleared stream advances current_track_id, making play() skip track 0.
      await api.play(0);
      final n = added.count ?? selection.count;
      toast.endQueueActivity('Playing $n ${n == 1 ? 'track' : 'tracks'}');
    } catch (e) {
      toast.endQueueActivity('Failed to play: $e', isError: true);
    }
  }

  Future<void> _playNext(WidgetRef ref, SelectionState selection) async {
    final api = ref.read(kalinkaProxyProvider);
    final toast = ref.read(toastProvider.notifier);
    final selectionNotifier = ref.read(selectionStateProvider.notifier);
    final ids = selectionNotifier.resolveIdsForApi();
    final insertIndex = playNextInsertIndex(ref);
    selectionNotifier.exitSelectionMode();
    toast.beginQueueActivity('Queueing next…');
    try {
      final added = await api.add(ids, index: insertIndex);
      final n = added.count ?? selection.count;
      toast.endQueueActivity('$n ${n == 1 ? 'track' : 'tracks'} playing next');
    } catch (e) {
      toast.endQueueActivity('Failed to add: $e', isError: true);
    }
  }
}

/// InkWell overlay for the batch bar: subtle wash on hover, accent on press
/// (matches KalinkaButton).
WidgetStateProperty<Color?> _batchOverlay() =>
    WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.pressed)) {
        return KalinkaColors.accent.withValues(alpha: 0.20);
      }
      if (states.contains(WidgetState.hovered)) {
        return Colors.white.withValues(alpha: 0.07);
      }
      return null;
    });

/// One of the three primary batch-action buttons (Play now / Play next / Add to
/// queue). A null [onTap] renders it disabled.
class _BatchActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _BatchActionButton({
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final fg = enabled ? KalinkaColors.textPrimary : KalinkaColors.textMuted;
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: Material(
        color: KalinkaColors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: KalinkaColors.borderDefault),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          overlayColor: _batchOverlay(),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              children: [
                Icon(icon, size: 16, color: fg),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: KalinkaFonts.sans(
                    fontSize: KalinkaTypography.baseSize + 2,
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Labelled Cancel chip with the same hover/pressed feedback as the action
/// buttons.
class _CancelChip extends StatelessWidget {
  final VoidCallback onTap;

  const _CancelChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: KalinkaColors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: KalinkaColors.borderDefault),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        overlayColor: _batchOverlay(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.close,
                size: 15,
                color: KalinkaColors.textSecondary,
              ),
              const SizedBox(width: 5),
              Text(
                'Cancel',
                style: KalinkaFonts.sans(
                  fontSize: KalinkaTypography.baseSize + 1,
                  fontWeight: FontWeight.w600,
                  color: KalinkaColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

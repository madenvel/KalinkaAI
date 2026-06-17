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

  // All three actions dismiss the panel immediately and report progress via the
  // shared queue-activity spinner (which morphs into the result and survives
  // concurrent adds), so a large add never leaves the user staring at an
  // unresponsive panel. selection is a snapshot captured at tap time, so its
  // count is still valid after exitSelectionMode() as a fallback.

  Future<void> _appendToQueue(WidgetRef ref, SelectionState selection) async {
    final api = ref.read(kalinkaProxyProvider);
    final toast = ref.read(toastProvider.notifier);
    final selectionNotifier = ref.read(selectionStateProvider.notifier);
    final ids = selectionNotifier.resolveIdsForApi();
    selectionNotifier.exitSelectionMode();
    toast.beginQueueActivity('Adding to queue…');
    try {
      // Prefer the server's expanded track count over selection.count, which
      // counts a whole album/playlist as a single item.
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
      // Always start from the first track. Passing an explicit index avoids a
      // backend race where a stale FINISHED event from the just-cleared stream
      // auto-advances current_track_id, making index-less play() skip track 0.
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

/// One of the three primary batch-action buttons (Play now / Play next / Add to
/// queue). Adds hover (desktop) and pressed feedback the plain GestureDetector
/// lacked; passing a null [onTap] renders it disabled.
class _BatchActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _BatchActionButton({
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  State<_BatchActionButton> createState() => _BatchActionButtonState();
}

class _BatchActionButtonState extends State<_BatchActionButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final fg = enabled ? KalinkaColors.textPrimary : KalinkaColors.textMuted;

    final Color bg;
    final Color border;
    if (!enabled) {
      bg = KalinkaColors.surfaceElevated;
      border = KalinkaColors.borderDefault;
    } else if (_pressed) {
      bg = KalinkaColors.accent.withValues(alpha: 0.22);
      border = KalinkaColors.accent;
    } else if (_hovered) {
      bg = KalinkaColors.surfaceRaised;
      border = KalinkaColors.accentTint.withValues(alpha: 0.5);
    } else {
      bg = KalinkaColors.surfaceElevated;
      border = KalinkaColors.borderDefault;
    }

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: enabled ? (_) => setState(() => _hovered = true) : null,
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: bg,
              border: Border.all(color: border, width: 1),
            ),
            child: Column(
              children: [
                Icon(widget.icon, size: 16, color: fg),
                const SizedBox(height: 2),
                Text(
                  widget.label,
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
class _CancelChip extends StatefulWidget {
  final VoidCallback onTap;

  const _CancelChip({required this.onTap});

  @override
  State<_CancelChip> createState() => _CancelChipState();
}

class _CancelChipState extends State<_CancelChip> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final highlighted = _hovered || _pressed;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: highlighted
                ? KalinkaColors.surfaceRaised
                : KalinkaColors.surfaceElevated,
            border: Border.all(
              color: _pressed
                  ? KalinkaColors.accentTint.withValues(alpha: 0.5)
                  : KalinkaColors.borderDefault,
              width: 1,
            ),
          ),
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

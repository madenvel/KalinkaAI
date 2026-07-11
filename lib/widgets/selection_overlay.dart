import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/browse_detail_provider.dart';
import '../providers/selection_state_provider.dart';
import '../providers/kalinka_player_api_provider.dart';
import '../providers/toast_provider.dart';
import '../theme/app_theme.dart';
import '../utils/play_next.dart';
import '../utils/haptics.dart';
import 'search_cards/action_icon_chip.dart';

/// Bottom batch bar shown during multi-select mode. One row:
/// ✕ cancel chip · "N selected / M tracks" summary · divider · the three
/// batch actions as compact icon-over-label buttons (Play now crimson-filled
/// like the section play-all chip, Play next, Queue).
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
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
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
            child: Row(
              children: [
                ActionIconChip(
                  icon: Icons.close,
                  semanticsLabel: 'Cancel selection',
                  onTap: () {
                    KalinkaHaptics.lightImpact();
                    ref
                        .read(selectionStateProvider.notifier)
                        .exitSelectionMode();
                  },
                ),
                const SizedBox(width: 6),
                Expanded(child: _SelectionSummary(selection: selection)),
                const SizedBox(width: 8),
                Container(
                  width: 1,
                  height: 30,
                  color: KalinkaColors.borderDefault,
                ),
                const SizedBox(width: 8),
                _BatchActionButton(
                  icon: Icons.play_arrow_rounded,
                  label: 'Play now',
                  accent: true,
                  onTap: selection.count > 0
                      ? () {
                          KalinkaHaptics.mediumImpact();
                          _playNow(ref, selection);
                        }
                      : null,
                ),
                const SizedBox(width: 8),
                _BatchActionButton(
                  icon: Icons.arrow_upward_rounded,
                  label: 'Play next',
                  onTap: selection.count > 0
                      ? () {
                          KalinkaHaptics.mediumImpact();
                          _playNext(ref, selection);
                        }
                      : null,
                ),
                const SizedBox(width: 8),
                _BatchActionButton(
                  icon: Icons.playlist_add_rounded,
                  label: 'Queue',
                  onTap: selection.count > 0
                      ? () {
                          KalinkaHaptics.mediumImpact();
                          _appendToQueue(ref, selection);
                        }
                      : null,
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

/// Overlay for the accent-filled button, where an accent wash would vanish.
WidgetStateProperty<Color?> _accentOverlay() =>
    WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.pressed)) {
        return Colors.white.withValues(alpha: 0.15);
      }
      if (states.contains(WidgetState.hovered)) {
        return Colors.white.withValues(alpha: 0.07);
      }
      return null;
    });

/// One of the three batch actions: icon-over-label button. All instances
/// share the same fixed width so the trio reads as a set, leaving the spare
/// width to the summary. [accent] fills it solid crimson with white icon and
/// text, the KalinkaButton accent treatment. A null [onTap] renders it
/// disabled.
class _BatchActionButton extends StatelessWidget {
  // Fixed footprint: wide enough for the longest label ("Play next").
  static const double _width = 72;

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool accent;

  const _BatchActionButton({
    required this.icon,
    required this.label,
    this.onTap,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final Color fg = accent || enabled
        ? KalinkaColors.textPrimary
        : KalinkaColors.textMuted;
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: Material(
        color: accent ? KalinkaColors.accent : KalinkaColors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: accent ? KalinkaColors.accent : KalinkaColors.borderDefault,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          // On the crimson fill an accent wash would vanish — use white.
          overlayColor: accent ? _accentOverlay() : _batchOverlay(),
          child: SizedBox(
            width: _width,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 24, color: fg),
                  const SizedBox(height: 1),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KalinkaFonts.sans(
                      fontSize: KalinkaTypography.baseSize - 1,
                      fontWeight: FontWeight.w600,
                      color: fg,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Two-line selection summary: "N selected" (items — tracks and whole
/// albums/playlists), over the resolved track total those items expand to.
/// Container track counts come from [browseDetailProvider] (minus exclusions);
/// while one is still loading the total shows as "M+" ("…" if nothing else is
/// resolved yet).
class _SelectionSummary extends ConsumerWidget {
  final SelectionState selection;

  const _SelectionSummary({required this.selection});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    int tracks = selection.selectedIds.length;
    int unresolved = 0;
    for (final containerId in selection.selectedContainerIds) {
      final items = ref.watch(browseDetailProvider(containerId)).value?.items;
      if (items == null) {
        unresolved++;
        continue;
      }
      final trackCount = items.where((i) => i.track != null).length;
      final excluded = selection.containerExclusions[containerId]?.length ?? 0;
      tracks += (trackCount - excluded).clamp(0, trackCount);
    }
    final tracksLabel = unresolved == 0
        ? '$tracks ${tracks == 1 ? 'track' : 'tracks'}'
        : tracks > 0
        ? '$tracks+ tracks'
        : '…';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${selection.count} selected',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: KalinkaFonts.sans(
            fontSize: KalinkaTypography.baseSize + 1,
            fontWeight: FontWeight.w700,
            color: KalinkaColors.textPrimary,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          tracksLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: KalinkaFonts.sans(
            fontSize: KalinkaTypography.baseSize - 1,
            fontWeight: FontWeight.w500,
            color: KalinkaColors.textMuted,
          ),
        ),
      ],
    );
  }
}

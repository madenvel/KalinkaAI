import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data_model/data_model.dart';
import '../data_model/kalinka_ws_api.dart';
import '../providers/app_state_provider.dart';
import '../providers/kalinka_player_api_provider.dart';
import '../providers/source_modules_provider.dart';
import '../providers/toast_provider.dart';
import '../providers/kalinka_ws_api_provider.dart';
import '../providers/url_resolver.dart';
import '../theme/app_theme.dart';
import '../utils/haptics.dart';
import 'berry_pulse.dart';
import 'procedural_album_art.dart';
import 'source_badge.dart';
import 'swipe_to_delete_row.dart';

/// A single queue item row with thumbnail, title, artist, and trailing slot.
///
/// Up Next rows always show a drag handle. History rows show the track duration
/// and are rendered in a dimmed style (no handle, no swipe-to-delete).
class QueueItemRow extends ConsumerWidget {
  final Track track;
  final int index;
  final int displayIndex;
  final bool isCurrentTrack;
  final bool isHistory;
  final bool isDragging;
  final bool showDragHandle;
  final VoidCallback? onDelete;

  const QueueItemRow({
    super.key,
    required this.track,
    required this.index,
    required this.displayIndex,
    this.isCurrentTrack = false,
    this.isHistory = false,
    this.isDragging = false,
    this.showDragHandle = true,
    this.onDelete,
  });

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remaining = seconds % 60;
    return '$minutes:${remaining.toString().padLeft(2, '0')}';
  }

  int get _upNextPosition => displayIndex + 1;

  double get _titleFadeFactor {
    // Position 1 -> 0.0, position 8+ -> 1.0
    return ((_upNextPosition - 1) / 8).clamp(0.0, 1.0);
  }

  Color _titleColor() {
    if (isHistory) return KalinkaColors.textMuted;
    if (isCurrentTrack) {
      // Requested now-playing accent tone.
      return const Color(0xFFFF6B7A);
    }

    // Smooth progressive fade for Up Next titles.
    return Color.lerp(
      const Color(0xFFE6E6E6),
      const Color(0xFFB0B0B0),
      _titleFadeFactor,
    )!;
  }

  double _upNextArtworkOpacity() {
    if (isCurrentTrack) return 1.0;
    if (isHistory) return 0.75;

    if (_upNextPosition <= 3) return 1.0;
    if (_upNextPosition <= 8) return 0.85;
    return 0.8;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.read(kalinkaWsApiProvider);
    final kalinkaProxy = ref.read(kalinkaProxyProvider);
    final urlResolver = ref.read(urlResolverProvider);

    final imageUrl = track.album?.image?.small;
    final resolvedImageUrl = imageUrl != null
        ? urlResolver.abs(imageUrl)
        : null;

    // Colour tokens vary by state
    final titleColor = _titleColor();

    final artistColor = isHistory
        ? KalinkaColors.textMuted
        : KalinkaColors.textSecondary;

    final rowBg = isCurrentTrack && !isHistory
        ? KalinkaColors.accent.withValues(alpha: 0.08)
        : KalinkaColors.background;

    final isPlaying =
        isCurrentTrack &&
        ref.watch(
          playerStateProvider.select((s) => s.state == PlayerStateType.playing),
        );

    Widget artwork;
    if (isCurrentTrack && !isHistory) {
      artwork = ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Layer 1 — album artwork
              resolvedImageUrl != null
                  ? Image.network(
                      resolvedImageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          ProceduralAlbumArt(trackId: track.id, size: 44),
                    )
                  : ProceduralAlbumArt(trackId: track.id, size: 44),
              // Layer 2 — scrim
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.0, 0.45, 1.0],
                    colors: [
                      Color(0x000A0204),
                      Color(0x8C0A0204),
                      Color(0xD10A0204),
                    ],
                  ),
                ),
              ),
              // Layer 3 — berry pulse animation
              // BerryPulse(isPlaying: isPlaying),
            ],
          ),
        ),
      );
    } else {
      artwork = Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(6)),
        clipBehavior: Clip.antiAlias,
        child: resolvedImageUrl != null
            ? Image.network(
                resolvedImageUrl,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    ProceduralAlbumArt(trackId: track.id, size: 44),
              )
            : ProceduralAlbumArt(trackId: track.id, size: 44),
      );

      artwork = Opacity(opacity: _upNextArtworkOpacity(), child: artwork);
    }

    final rowContent = GestureDetector(
      onTap: () {
        KalinkaHaptics.lightImpact();
        api.sendQueueCommand(QueueCommand.play(index: index));
      },
      child: Container(
        color: rowBg,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            const SizedBox(width: 10),
            // Thumbnail 44×44
            SizedBox(width: 44, height: 44, child: artwork),
            const SizedBox(width: 10),
            // Track info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    track.title,
                    style: KalinkaTextStyles.queueItemTitle.copyWith(
                      color: titleColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SourceBadge(
                        entityId: track.id,
                        size: SourceBadgeSize.small,
                      ),
                      if (ref.watch(sourceCountProvider) > 1)
                        const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          track.performer?.name ?? 'Unknown Artist',
                          style: KalinkaTextStyles.queueItemArtist.copyWith(
                            color: artistColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Trailing: duration for History; duration + drag handle for Up Next.
            if (isHistory)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  _formatDuration(track.duration),
                  style: KalinkaTextStyles.queueItemDuration.copyWith(
                    color: KalinkaColors.textMuted,
                  ),
                ),
              )
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(width: 8),
                  Text(
                    _formatDuration(track.duration),
                    // Keep Up Next duration fixed for fast scanning.
                    style: KalinkaTextStyles.queueItemDuration.copyWith(
                      color: KalinkaColors.textSecondary,
                    ),
                  ),
                  if (showDragHandle) ...[
                    const SizedBox(width: 7),
                    _DragHandle(index: displayIndex),
                  ] else
                    const SizedBox(width: 8),
                ],
              ),
          ],
        ),
      ),
    );

    return SwipeToDeleteRow(
      enabled: !isHistory && !isDragging,
      onDelete: () async {
        onDelete?.call();
        try {
          await kalinkaProxy.remove(index);
          ref.read(toastProvider.notifier).showTrackRemoved(track.title);
        } catch (e) {
          ref
              .read(toastProvider.notifier)
              .show('Failed to remove: $e', isError: true);
        }
      },
      child: rowContent,
    );
  }
}

/// Drag handle widget aligned to the 44px artwork centerline.
class _DragHandle extends StatelessWidget {
  /// The index of this item within the enclosing [SliverReorderableList].
  final int index;

  const _DragHandle({required this.index});

  @override
  Widget build(BuildContext context) {
    return ReorderableDragStartListener(
      index: index,
      child: const SizedBox(
        width: 48,
        height: 44,
        child: Center(
          child: Icon(
            Icons.drag_handle,
            size: 20,
            color: KalinkaColors.textMuted,
          ),
        ),
      ),
    );
  }
}

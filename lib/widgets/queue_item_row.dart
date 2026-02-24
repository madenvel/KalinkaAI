import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data_model/data_model.dart';
import '../data_model/kalinka_ws_api.dart';
import '../providers/kalinka_player_api_provider.dart';
import '../providers/toast_provider.dart';
import '../providers/kalinka_ws_api_provider.dart';
import '../providers/url_resolver.dart';
import '../theme/app_theme.dart';
import '../utils/haptics.dart';
import 'procedural_album_art.dart';
import 'source_badge.dart';
import 'swipe_to_delete_row.dart';

/// A single queue item row with index, thumbnail, title, artist, and duration.
class QueueItemRow extends ConsumerWidget {
  final Track track;
  final int index;
  final int displayIndex;
  final bool isCurrentTrack;
  final VoidCallback? onDelete;

  const QueueItemRow({
    super.key,
    required this.track,
    required this.index,
    required this.displayIndex,
    this.isCurrentTrack = false,
    this.onDelete,
  });

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remaining = seconds % 60;
    return '$minutes:${remaining.toString().padLeft(2, '0')}';
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

    final rowContent = GestureDetector(
      onTap: () {
        KalinkaHaptics.lightImpact();
        api.sendQueueCommand(QueueCommand.play(index: index));
      },
      child: Container(
        color: isCurrentTrack
            ? KalinkaColors.accent.withValues(alpha: 0.08)
            : KalinkaColors.background,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            // Index number
            SizedBox(
              width: 20,
              child: Text(
                '${displayIndex + 1}',
                style: KalinkaTextStyles.queueItemIndex.copyWith(
                  color: isCurrentTrack
                      ? KalinkaColors.accent
                      : KalinkaColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 8),
            // Thumbnail 44x44
            SizedBox(
              width: 44,
              height: 44,
              child: Stack(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                    ),
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
                  ),
                  Positioned(
                    bottom: 1,
                    right: 1,
                    child: SourceBadge(entityId: track.id),
                  ),
                ],
              ),
            ),
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
                      color: isCurrentTrack
                          ? KalinkaColors.accent
                          : KalinkaColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    track.performer?.name ?? 'Unknown Artist',
                    style: KalinkaTextStyles.queueItemArtist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Duration right-aligned
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                _formatDuration(track.duration),
                style: KalinkaTextStyles.queueItemDuration,
              ),
            ),
          ],
        ),
      ),
    );

    return SwipeToDeleteRow(
      onDelete: () async {
        onDelete?.call();
        try {
          await kalinkaProxy.remove(index);
          ref.read(toastProvider.notifier).show('"${track.title}" removed');
        } catch (e) {
          ref.read(toastProvider.notifier).show('Failed to remove: $e', isError: true);
        }
      },
      child: rowContent,
    );
  }
}

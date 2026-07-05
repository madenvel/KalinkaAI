import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data_model/data_model.dart';
import '../../providers/source_modules_provider.dart';
import '../../providers/url_resolver.dart';
import '../../theme/app_theme.dart';
import '../procedural_album_art.dart';
import '../source_badge.dart';
import '../swipe_to_act_row.dart';
import '../track_tile_layout.dart';
import '../search_cards/track_row_support.dart';

/// A single search result row on the staging surface.
///
/// Search is a staging surface: tapping never plays or replaces the queue.
/// The queue is only touched by an explicit swipe — right to add to the end,
/// left to play next — matching the browse/queue rows elsewhere. Both are
/// silent and non-destructive; playback is never interrupted.
class StagingResultRow extends ConsumerStatefulWidget {
  final BrowseItem item;

  const StagingResultRow({super.key, required this.item});

  @override
  ConsumerState<StagingResultRow> createState() => _StagingResultRowState();
}

class _StagingResultRowState extends ConsumerState<StagingResultRow> {
  String get _title =>
      widget.item.track?.title ?? widget.item.name ?? 'Unknown';

  String get _subtitle {
    final item = widget.item;
    switch (item.browseType) {
      case BrowseType.track:
        final artist = item.track?.performer?.name ?? '';
        final album = item.track?.album?.title ?? '';
        return [artist, album].where((s) => s.isNotEmpty).join(' · ');
      case BrowseType.album:
        final artist = item.album?.artist?.name ?? '';
        return artist.isEmpty ? 'Album' : 'Album · $artist';
      case BrowseType.artist:
        return 'Artist';
      case BrowseType.playlist:
        final count = item.playlist?.trackCount;
        return count != null ? 'Playlist · $count tracks' : 'Playlist';
      case BrowseType.catalog:
      case BrowseType.unknown:
        return item.subname ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final urlResolver = ref.read(urlResolverProvider);
    final imageUrl = widget.item.image?.small;
    final resolvedImageUrl = imageUrl != null
        ? urlResolver.abs(imageUrl)
        : null;
    final isArtist = widget.item.browseType == BrowseType.artist;
    final subtitle = _subtitle;
    final track = widget.item.track;
    final duration = track != null
        ? formatTrackDuration(track.duration * 1000)
        : null;

    return SwipeToActRow(
      onAddToQueue: () => addTrackToQueue(widget.item),
      onPlayNext: () => playTrackNext(widget.item),
      child: TrackTileLayout(
        padding: const EdgeInsets.symmetric(vertical: 8),
        leadingStartSpacing: 0,
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(isArtist ? 22 : 6),
          child: resolvedImageUrl != null
              ? Image.network(
                  resolvedImageUrl,
                  width: 44,
                  height: 44,
                  cacheWidth: 132,
                  cacheHeight: 132,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  filterQuality: FilterQuality.low,
                  errorBuilder: (_, __, ___) =>
                      ProceduralAlbumArt(trackId: widget.item.id, size: 44),
                )
              : ProceduralAlbumArt(trackId: widget.item.id, size: 44),
        ),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _title,
              style: KalinkaTextStyles.trackRowTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            if (subtitle.isNotEmpty)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SourceBadge(
                    entityId: widget.item.id,
                    size: SourceBadgeSize.standard,
                  ),
                  if (ref.watch(sourceCountProvider) > 1)
                    const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      subtitle,
                      style: KalinkaTextStyles.trackRowSubtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
          ],
        ),
        trailing: duration != null
            ? Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(duration, style: KalinkaTextStyles.trackRowSubtitle),
              )
            : null,
      ),
    );
  }
}

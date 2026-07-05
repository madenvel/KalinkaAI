import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data_model/data_model.dart';
import '../../providers/kalinka_player_api_provider.dart';
import '../../providers/source_modules_provider.dart';
import '../../providers/toast_provider.dart';
import '../../providers/url_resolver.dart';
import '../../theme/app_theme.dart';
import '../../utils/haptics.dart';
import '../procedural_album_art.dart';
import '../source_badge.dart';
import '../track_tile_layout.dart';

/// A single search result row on the staging surface.
///
/// Unlike the browse/queue rows, tapping never plays or replaces the queue —
/// search is a staging surface. The only mutation is the explicit add-to-queue
/// affordance (the trailing +), which appends to the queue silently and leaves
/// playback untouched.
class StagingResultRow extends ConsumerStatefulWidget {
  final BrowseItem item;

  const StagingResultRow({super.key, required this.item});

  @override
  ConsumerState<StagingResultRow> createState() => _StagingResultRowState();
}

class _StagingResultRowState extends ConsumerState<StagingResultRow> {
  bool _added = false;

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

  Future<void> _add() async {
    if (widget.item.id.isEmpty) return;
    KalinkaHaptics.lightImpact();
    setState(() => _added = true);
    final api = ref.read(kalinkaProxyProvider);
    final title = _title;
    await runQueueActivity(
      pending: 'Adding to queue…',
      action: () => api.add([widget.item.id]),
      done: (_) => '"$title" added to queue',
      failed: (e) => 'Failed to add: $e',
    );
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

    return GestureDetector(
      onTap: _add,
      behavior: HitTestBehavior.opaque,
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
        trailing: _buildAddButton(),
      ),
    );
  }

  Widget _buildAddButton() {
    return Semantics(
      label: 'Add to queue',
      button: true,
      child: GestureDetector(
        onTap: _add,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: _added
                ? KalinkaColors.accentSubtle
                : KalinkaColors.surfaceElevated,
            shape: BoxShape.circle,
            border: Border.all(
              color: _added
                  ? KalinkaColors.accentBorder
                  : KalinkaColors.borderDefault,
              width: 1,
            ),
          ),
          child: Icon(
            _added ? Icons.check_rounded : Icons.add_rounded,
            size: 18,
            color: _added ? KalinkaColors.accentTint : KalinkaColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

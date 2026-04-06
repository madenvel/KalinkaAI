import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data_model/data_model.dart';
import '../../providers/url_resolver.dart';
import '../../theme/app_theme.dart';
import '../procedural_album_art.dart';
import '../source_badge.dart';
import 'expanded_artist_card.dart';

/// Artist section with horizontal strip and tap-to-expand card.
/// Owns all expansion state locally — no parent coordination required.
class ArtistSection extends ConsumerStatefulWidget {
  final List<BrowseItem> artists;

  const ArtistSection({super.key, required this.artists});

  @override
  ConsumerState<ArtistSection> createState() => _ArtistSectionState();
}

class _ArtistSectionState extends ConsumerState<ArtistSection> {
  BrowseItem? _selectedArtist;
  int _showCount = 5;

  void _selectArtist(BrowseItem artist) {
    if (_selectedArtist?.id == artist.id) {
      _collapseArtist();
      return;
    }
    setState(() => _selectedArtist = artist);
  }

  void _collapseArtist() => setState(() => _selectedArtist = null);

  @override
  Widget build(BuildContext context) {
    final artists = widget.artists;
    final effectiveShowCount = _showCount.clamp(0, artists.length);
    final visibleArtists = artists.take(effectiveShowCount).toList();
    final remaining = artists.length - effectiveShowCount;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeOut,
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: _selectedArtist != null
          ? ExpandedArtistCard(
              key: ValueKey('artist_${_selectedArtist!.id}'),
              artist: _selectedArtist!,
              onClose: _collapseArtist,
            )
          : _ArtistStrip(
              key: const ValueKey('strip'),
              artists: visibleArtists,
              remaining: remaining,
              onSelect: _selectArtist,
              onShowMore: () => setState(
                () => _showCount = (_showCount + 10).clamp(0, artists.length),
              ),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Collapsed strip
// ---------------------------------------------------------------------------

class _ArtistStrip extends StatelessWidget {
  final List<BrowseItem> artists;
  final int remaining;
  final void Function(BrowseItem) onSelect;
  final VoidCallback onShowMore;

  const _ArtistStrip({
    super.key,
    required this.artists,
    required this.remaining,
    required this.onSelect,
    required this.onShowMore,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < artists.length; i++)
            Padding(
              padding: EdgeInsets.only(
                right: i == artists.length - 1 && remaining <= 0 ? 0 : 10,
              ),
              child: _ArtistStripTile(
                artist: artists[i],
                onTap: () => onSelect(artists[i]),
              ),
            ),
          if (remaining > 0)
            _ArtistShowMoreTile(
              remainingCount: remaining,
              onTap: onShowMore,
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Individual tile in the strip
// ---------------------------------------------------------------------------

class _ArtistStripTile extends ConsumerWidget {
  final BrowseItem artist;
  final VoidCallback onTap;

  const _ArtistStripTile({
    required this.artist,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = artist.artist?.name ?? artist.name ?? 'Unknown';
    final albumCount = artist.artist?.albumCount;
    final imageUrl = artist.image?.small;
    final resolvedImageUrl =
        imageUrl == null ? null : ref.read(urlResolverProvider).abs(imageUrl);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ArtistAvatarWidget(
              artistId: artist.id,
              resolvedImageUrl: resolvedImageUrl,
              size: 60,
              isActive: false,
            ),
            const SizedBox(height: 6),
            Text(
              name,
              style: KalinkaTextStyles.trackRowTitle.copyWith(fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                SourceBadge(entityId: artist.id, size: SourceBadgeSize.small),
                if (albumCount != null) ...[
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      '$albumCount',
                      style: KalinkaTextStyles.trackRowSubtitle.copyWith(
                        fontSize: 10,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Show more tile at the end of the strip
// ---------------------------------------------------------------------------

class _ArtistShowMoreTile extends StatelessWidget {
  final int remainingCount;
  final VoidCallback onTap;

  const _ArtistShowMoreTile({
    required this.remainingCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: KalinkaColors.surfaceElevated,
                border: Border.all(color: KalinkaColors.borderDefault),
              ),
              child: const Icon(Icons.add, color: KalinkaColors.accent, size: 24),
            ),
            const SizedBox(height: 6),
            Text(
              '+$remainingCount',
              style: KalinkaTextStyles.trackRowTitle.copyWith(fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'more',
              style: KalinkaTextStyles.trackRowSubtitle.copyWith(fontSize: 10),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Artist avatar circle — shared with ExpandedArtistCard
// ---------------------------------------------------------------------------

class ArtistAvatarWidget extends StatelessWidget {
  final String artistId;
  final String? resolvedImageUrl;
  final double size;
  final bool isActive;

  const ArtistAvatarWidget({
    super.key,
    required this.artistId,
    required this.resolvedImageUrl,
    required this.size,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: KalinkaColors.surfaceRaised,
        border: Border.all(
          color: isActive ? KalinkaColors.accent : KalinkaColors.borderDefault,
          width: isActive ? 2.0 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipOval(
        child: resolvedImageUrl != null
            ? Image.network(
                resolvedImageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    ProceduralAlbumArt(trackId: artistId, size: size),
              )
            : ProceduralAlbumArt(trackId: artistId, size: size),
      ),
    );
  }
}

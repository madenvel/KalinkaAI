import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data_model/data_model.dart';
import '../../providers/browse_detail_provider.dart';
import '../../providers/search_state_provider.dart';
import '../../providers/url_resolver.dart';
import '../../theme/app_theme.dart';
import '../procedural_album_art.dart';

/// Artist row for search results.
/// 52x52 circular avatar, name, stats, Browse button.
/// Browse reveals horizontal album strip inline.
class SearchArtistRow extends ConsumerWidget {
  final BrowseItem item;
  final DraggableScrollableController? sheetController;

  const SearchArtistRow({super.key, required this.item, this.sheetController});

  void _togglePreview(WidgetRef ref) {
    final searchNotifier = ref.read(searchStateProvider.notifier);
    final currentPreview = ref.read(searchStateProvider).artistPreviewId;
    if (currentPreview == item.id) {
      searchNotifier.collapseArtistPreview();
    } else {
      searchNotifier.previewArtist(item.id);
      // Auto-snap sheet up if needed
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (sheetController != null && sheetController!.isAttached) {
          final currentSize = sheetController!.size;
          if (currentSize < 0.65) {
            sheetController!.animateTo(
              0.65,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
            );
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchState = ref.watch(searchStateProvider);
    final isPreviewing = searchState.artistPreviewId == item.id;

    final artist = item.artist;
    final name = artist?.name ?? item.name ?? 'Unknown';
    final albumCount = artist?.albumCount;

    final urlResolver = ref.read(urlResolverProvider);
    final imageUrl = item.image?.thumbnail ?? item.image?.small;
    final resolvedImageUrl = imageUrl != null
        ? urlResolver.abs(imageUrl)
        : null;

    final stats = albumCount != null ? '$albumCount albums' : '';

    return Column(
      children: [
        // Main row
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              // Circular avatar 52x52
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: resolvedImageUrl != null
                      ? Image.network(
                          resolvedImageUrl,
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              ProceduralAlbumArt(trackId: item.id, size: 52),
                        )
                      : ProceduralAlbumArt(trackId: item.id, size: 52),
                ),
              ),
              const SizedBox(width: 12),
              // Name + stats
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: KalinkaTextStyles.cardTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (stats.isNotEmpty)
                      Text(stats, style: KalinkaTextStyles.trackRowSubtitle),
                  ],
                ),
              ),
              // Browse button
              GestureDetector(
                onTap: () => _togglePreview(ref),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isPreviewing
                          ? KalinkaColors.accent
                          : KalinkaColors.borderElevated,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    isPreviewing ? 'CLOSE' : 'BROWSE',
                    style: KalinkaTextStyles.browseButtonLabel,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Horizontal album strip
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: isPreviewing
              ? _ArtistAlbumStrip(artistId: item.id)
              : const SizedBox.shrink(),
          crossFadeState: isPreviewing
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 320),
          firstCurve: Curves.easeInOutQuart,
          secondCurve: Curves.easeInOutQuart,
          sizeCurve: Curves.easeInOutQuart,
        ),
      ],
    );
  }
}

class _ArtistAlbumStrip extends ConsumerWidget {
  final String artistId;

  const _ArtistAlbumStrip({required this.artistId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albumsAsync = ref.watch(browseDetailProvider(artistId));

    return albumsAsync.when(
      data: (browseList) {
        final albums = browseList.items;
        if (albums.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'No albums found',
              style: KalinkaTextStyles.trackRowSubtitle,
            ),
          );
        }
        return SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: albums.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final album = albums[index];
              return _AlbumChip(item: album);
            },
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          'Failed to load albums',
          style: KalinkaTextStyles.trackRowSubtitle,
        ),
      ),
    );
  }
}

class _AlbumChip extends ConsumerWidget {
  final BrowseItem item;

  const _AlbumChip({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final urlResolver = ref.read(urlResolverProvider);
    final imageUrl = item.image?.thumbnail ?? item.image?.small;
    final resolvedImageUrl = imageUrl != null
        ? urlResolver.abs(imageUrl)
        : null;

    final title = item.album?.title ?? item.name ?? '';

    return SizedBox(
      width: 80,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: resolvedImageUrl != null
                  ? Image.network(
                      resolvedImageUrl,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          ProceduralAlbumArt(trackId: item.id, size: 80),
                    )
                  : ProceduralAlbumArt(trackId: item.id, size: 80),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: KalinkaTextStyles.trackRowSubtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

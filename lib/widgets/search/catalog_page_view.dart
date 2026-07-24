import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data_model/data_model.dart';
import '../../providers/kalinka_player_api_provider.dart';
import '../../providers/search_session_provider.dart';
import '../../providers/url_resolver.dart';
import '../../theme/app_theme.dart';
import '../browse_rows_shimmer.dart';
import '../infinite_list_view.dart';
import '../search_cards/browse_item_rows.dart';
import '../source_badge.dart';

/// One selected catalog page — the single navigation level below the
/// Catalogs root (back lives in the title bar). The banner scrolls away with
/// the items; albums/artists/playlists unroll inline. Items are pulled in
/// chunks by an [InfiniteListView] straight off the browse endpoint
/// (deterministic — never the AI router).
class CatalogPageView extends ConsumerWidget {
  final CatalogPage page;

  /// Returns to the Catalogs root — used by the error state's action.
  final VoidCallback onBackToCatalogs;

  const CatalogPageView({
    super.key,
    required this.page,
    required this.onBackToCatalogs,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Recomputed per chunk, not per row (O(n²) otherwise).
    final trackIdsMemo = _TrackIdsMemo();

    return InfiniteListView<BrowseItem>(
      key: ValueKey(page.id),
      reloadKey: page.id,
      // No horizontal list padding — the banner bleeds edge to edge; rows and
      // separators carry their own 16px inset instead.
      padding: const EdgeInsets.only(bottom: 24),
      header: _CatalogBanner(page: page),
      fetchChunk: (offset, limit) async {
        final api = ref.read(kalinkaProxyProvider);
        final list = await api.browse(page.id!, offset: offset, limit: limit);
        return ItemChunk(items: list.items, total: list.total);
      },
      separatorBuilder: (context, _) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Divider(
          color: KalinkaColors.borderSubtle,
          thickness: 1,
          height: 14,
        ),
      ),
      itemBuilder: (context, item, index, loaded) {
        // Track rows play the whole loaded list as a queue from the
        // tapped row; as more chunks scroll in, the context grows.
        final trackIds = trackIdsMemo.of(loaded);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: BrowseItemRows.buildRow(
            item,
            queueContextIds: trackIds.isEmpty ? null : trackIds,
          ),
        );
      },
      initialPlaceholder: const Padding(
        padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: BrowseRowsShimmer(count: 8),
      ),
      loadMorePlaceholder: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: BrowseRowsShimmer(count: 3, leadingDivider: true),
      ),
      emptyBuilder: (context) => const _CatalogEmpty(),
      // The error state replaces only the rows, never the banner.
      errorBuilder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CatalogBanner(page: page),
          Expanded(child: _CatalogError(onReturn: onBackToCatalogs)),
        ],
      ),
    );
  }
}

/// Caches the queue-context track ids per loaded-chunk count, so row builds
/// share one list instead of rescanning all loaded items each time.
class _TrackIdsMemo {
  List<String> _ids = const [];
  int _forLength = -1;

  List<String> of(List<BrowseItem> loaded) {
    if (loaded.length != _forLength) {
      _forLength = loaded.length;
      _ids = [
        for (final i in loaded)
          if (i.track != null) i.id,
      ];
    }
    return _ids;
  }
}

/// The scrolling page banner: the catalog card's server-rendered art, blurred
/// and dimmed, bleeding edge to edge of the surface with no frame — it fades
/// out of the page canvas at the top and back into it at the bottom. The
/// Playfair title + attribution keep to the left half so they sit in the
/// art's darker zone.
class _CatalogBanner extends ConsumerWidget {
  final CatalogPage page;

  const _CatalogBanner({required this.page});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artPath = page.artPath;
    final url = (artPath == null || artPath.isEmpty)
        ? null
        : ref.watch(urlResolverProvider).abs(artPath);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ClipRect(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Height tracks width (just under the cards' 3:1); type scales
            // with it, gently.
            final w = constraints.maxWidth;
            final minHeight = (w * 0.42).clamp(150.0, 320.0);
            final scale = (w / 420).clamp(1.0, 1.25);
            return _buildBanner(ref, url, minHeight, scale);
          },
        ),
      ),
    );
  }

  Widget _buildBanner(
    WidgetRef ref,
    String? url,
    double minHeight,
    double scale,
  ) {
    return Stack(
      children: [
        if (url != null) ...[
          Positioned.fill(
            child: Opacity(
              opacity: 0.45,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(
                  sigmaX: 10,
                  sigmaY: 10,
                  tileMode: TileMode.clamp,
                ),
                child: Image.network(
                  url,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  filterQuality: FilterQuality.medium,
                  // The blur erases fine detail — no point decoding the
                  // full-resolution render.
                  cacheWidth: 800,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),
          // No hard edges: the art dissolves out of the page canvas at
          // the top and back into it before the first rows.
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.22, 0.50, 0.95],
                  colors: [
                    KalinkaColors.background,
                    Color(0x00080808),
                    Color(0x00080808),
                    KalinkaColors.background,
                  ],
                ),
              ),
            ),
          ),
        ],
        Container(
          constraints: BoxConstraints(minHeight: minHeight),
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
          // Grows beyond minHeight only if the text needs the room.
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: 0.55,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  page.title ?? '',
                  style: KalinkaFonts.display(
                    fontSize: (KalinkaTypography.baseSize + 21) * scale,
                    fontWeight: FontWeight.w600,
                    color: KalinkaColors.textPrimary,
                  ),
                ),
                if (page.provider != null && page.provider!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Row(
                      children: [
                        SourceBadge(entityId: page.id!),
                        if (sourceBadgeVisible(ref, page.id!))
                          const SizedBox(width: 7),
                        Flexible(
                          child: Text(
                            page.provider!,
                            style: KalinkaTextStyles.trackRowSubtitle
                                .copyWith(color: KalinkaColors.textMuted)
                                .apply(fontSizeFactor: scale),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (page.description != null &&
                    page.description!.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      page.description!,
                      style: KalinkaTextStyles.trackRowSubtitle
                          .copyWith(color: KalinkaColors.textPrimary)
                          .apply(fontSizeFactor: scale),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Inline failure state with a visible way back to Catalogs (MD §13).
class _CatalogError extends StatelessWidget {
  final VoidCallback onReturn;

  const _CatalogError({required this.onReturn});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 40,
              color: KalinkaColors.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              'This catalog is unavailable',
              style: KalinkaTextStyles.cardTitle,
            ),
            const SizedBox(height: 4),
            Text(
              'It may be offline or still indexing.',
              style: KalinkaTextStyles.trackRowSubtitle,
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: onReturn,
              icon: const Icon(Icons.chevron_left_rounded, size: 20),
              label: const Text('Return to Catalogs'),
              style: TextButton.styleFrom(
                foregroundColor: KalinkaColors.accentTint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A catalog that resolved but holds nothing.
class _CatalogEmpty extends StatelessWidget {
  const _CatalogEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.library_music_outlined,
              size: 40,
              color: KalinkaColors.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text('Nothing here yet', style: KalinkaTextStyles.cardTitle),
          ],
        ),
      ),
    );
  }
}

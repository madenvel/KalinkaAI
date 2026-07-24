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

/// One selected catalog page — the single navigation level below the Catalogs
/// root. Only the `‹ Back` link is pinned; the category banner (the catalog
/// card's art, blurred, behind the Playfair title + provider) scrolls away
/// with the items. Albums/artists/playlists unroll inline (they are content
/// state, not further navigation). Items are pulled in chunks by an
/// [InfiniteListView] straight off the browse endpoint (deterministic — never
/// the AI router), so long catalogs scroll endlessly.
class CatalogPageView extends ConsumerWidget {
  final CatalogPage page;

  /// Returns to the Catalogs root (the search screen). Shared by the `‹
  /// Back` link and the back arrow / system back.
  final VoidCallback onBackToCatalogs;

  const CatalogPageView({
    super.key,
    required this.page,
    required this.onBackToCatalogs,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The `‹ Back` bar floats over the list: content scrolls under it and
    // dissolves in its gradient scrim rather than hitting a hard edge.
    return Stack(
      children: [
        Positioned.fill(
          child: InfiniteListView<BrowseItem>(
            key: ValueKey(page.id),
            reloadKey: page.id,
            // No horizontal list padding — the banner bleeds edge to edge;
            // rows and separators carry their own 16px inset instead. The top
            // inset keeps the banner clear of the floating bar at rest.
            padding: const EdgeInsets.only(top: _kBackBarHeight, bottom: 24),
            header: _CatalogBanner(page: page),
            fetchChunk: (offset, limit) async {
              final api = ref.read(kalinkaProxyProvider);
              final list = await api.browse(
                page.id!,
                offset: offset,
                limit: limit,
              );
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
              final trackIds = [
                for (final i in loaded)
                  if (i.track != null) i.id,
              ];
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
            errorBuilder: (context, _) =>
                _CatalogError(onReturn: onBackToCatalogs),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _BackBar(onBack: onBackToCatalogs),
        ),
      ],
    );
  }
}

/// Height of the floating `‹ Back` bar — also the list's top inset, so the
/// banner rests just below it and only slides under when scrolling.
const double _kBackBarHeight = 48;

/// The floating `‹ Back` link — the only part of the page chrome that stays
/// put. Its scrim is the page canvas, solid at the top and dissolving to
/// nothing at the bottom edge, so content scrolling under it fades out
/// instead of hitting a hard line. The chevron's Transform cancels the
/// glyph's left bearing so its stroke lines up with the content edge (16).
class _BackBar extends StatelessWidget {
  final VoidCallback onBack;

  const _BackBar({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _kBackBarHeight,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.0, 0.55, 1.0],
          colors: [
            KalinkaColors.background,
            KalinkaColors.background,
            Color(0x00080808),
          ],
        ),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onBack,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.translate(
                    offset: const Offset(-4, 0),
                    child: const Icon(
                      Icons.chevron_left_rounded,
                      size: 18,
                      color: KalinkaColors.textSecondary,
                    ),
                  ),
                  Text(
                    'Back',
                    style: KalinkaTextStyles.dialogBody.copyWith(
                      color: KalinkaColors.textSecondary,
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
            // The banner keeps its proportions as the surface stretches: its
            // height tracks the width (just under the cards' 3:1) and the
            // type scales with it, instead of staying a fixed-height strip
            // that leaves the art peeking out only on the right.
            final w = constraints.maxWidth;
            final minHeight = (w * 0.42).clamp(150.0, 320.0);
            final scale = (w / 380).clamp(1.0, 1.7);
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
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 14),
          alignment: Alignment.bottomLeft,
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

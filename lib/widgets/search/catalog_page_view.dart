import 'dart:ui' as ui;

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

/// Height of the banner zone (art fade + title block) for a given surface
/// width. Grows slowly and caps low: the near-3:1 phone proportions turned
/// into a mostly-empty 320px slab on desktop widths, with the text block
/// centred in ~90px of dead art above and below. ~168px at a 400dp phone.
double _bannerZoneHeight(double width) =>
    (120 + width * 0.12).clamp(150.0, 230.0);

/// The blurred catalog art as a full-bleed backdrop for the page — painted at
/// the surface Stack level (like the Discover-root bloom) so it runs from the
/// very top of the screen, behind the status inset and title bar, and fades
/// into the page canvas before the first rows. The scrolling content passes
/// over it; at 0.45 opacity under a bake-time blur it reads as a colour wash.
class CatalogArtBackdrop extends ConsumerWidget {
  final String artPath;

  const CatalogArtBackdrop({super.key, required this.artPath});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (artPath.isEmpty) return const SizedBox.shrink();
    final url = ref.watch(urlResolverProvider).abs(artPath);
    final topInset = MediaQuery.paddingOf(context).top;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Chrome above + the banner zone (matching _CatalogBanner's height
        // curve), so the fade lands right where the rows begin.
        final height =
            topInset +
            kKalinkaTopBarHeight +
            _bannerZoneHeight(constraints.maxWidth);
        return SizedBox(
          height: height,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Opacity(opacity: 0.45, child: _BakedBlurImage(url: url)),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.45, 0.97],
                    colors: [Color(0x00080808), KalinkaColors.background],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The scrolling page banner: the Playfair title + attribution over the
/// left half of [CatalogArtBackdrop]'s art zone (the art itself is fixed at
/// the surface level and does not scroll with this header).
class _CatalogBanner extends StatelessWidget {
  final CatalogPage page;

  const _CatalogBanner({required this.page});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final minHeight = _bannerZoneHeight(w);
          // Type scales with width, gently.
          final scale = (w / 420).clamp(1.0, 1.25);
          return _buildBanner(minHeight, scale);
        },
      ),
    );
  }

  Widget _buildBanner(double minHeight, double scale) {
    return Consumer(
      builder: (context, ref, _) {
        return Container(
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
        );
      },
    );
  }
}

/// The banner art blurred ONCE into an offscreen raster when it loads, then
/// drawn as a plain texture. A live ImageFiltered re-ran its Gaussian pass on
/// the raster thread every scrolled frame (120→60fps while visible); a tiny
/// decode upscaled by the sampler was cheap but read pixelated on wide
/// windows. Shows nothing until the bake lands (same as the old load/error
/// behaviour); a url change keeps the previous bake until the new one is in.
class _BakedBlurImage extends StatefulWidget {
  final String url;

  const _BakedBlurImage({required this.url});

  @override
  State<_BakedBlurImage> createState() => _BakedBlurImageState();
}

class _BakedBlurImageState extends State<_BakedBlurImage> {
  // Bake resolution: small enough that the one-shot blur is negligible, big
  // enough that the cover-fit upscale stays smooth. Sigma is in bake pixels,
  // so on-screen softness grows with the window — fine, it's a backdrop.
  static const int _bakeWidth = 320;
  static const double _sigma = 14;

  ImageStream? _stream;
  ImageStreamListener? _listener;
  ui.Image? _baked;

  /// Bumped per resolve; a bake finishing under an older generation (url
  /// changed, widget reused) drops its result.
  int _bakeGen = 0;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(_BakedBlurImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) _resolve();
  }

  void _resolve() {
    final oldStream = _stream;
    final oldListener = _listener;
    final gen = ++_bakeGen;
    _listener = ImageStreamListener(
      (info, _) => _bake(info, gen),
      onError: (_, __) {}, // No art is a valid banner — keep what's shown.
    );
    _stream = ResizeImage(
      NetworkImage(widget.url),
      width: _bakeWidth,
    ).resolve(ImageConfiguration.empty);
    _stream!.addListener(_listener!);
    if (oldStream != null && oldListener != null) {
      oldStream.removeListener(oldListener);
    }
  }

  Future<void> _bake(ImageInfo info, int gen) async {
    final src = info.image;
    final outW = _bakeWidth;
    final outH = (outW * src.height / src.width).round().clamp(1, 1024);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()
      ..imageFilter = ui.ImageFilter.blur(
        sigmaX: _sigma,
        sigmaY: _sigma,
        tileMode: TileMode.clamp,
      );
    canvas.drawImageRect(
      src,
      Rect.fromLTWH(0, 0, src.width.toDouble(), src.height.toDouble()),
      Rect.fromLTWH(0, 0, outW.toDouble(), outH.toDouble()),
      paint,
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(outW, outH);
    picture.dispose();
    info.dispose();
    if (!mounted || gen != _bakeGen) {
      image.dispose();
      return;
    }
    setState(() {
      _baked?.dispose();
      _baked = image;
    });
  }

  @override
  void dispose() {
    if (_listener != null) _stream?.removeListener(_listener!);
    _baked?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baked = _baked;
    if (baked == null) return const SizedBox.shrink();
    return RawImage(
      image: baked,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
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

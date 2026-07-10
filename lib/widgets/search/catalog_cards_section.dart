import 'dart:math' show Random, min;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data_model/data_model.dart';
import '../../providers/catalog_cards_provider.dart';
import '../../providers/connection_state_provider.dart';
import '../../providers/source_modules_provider.dart';
import '../../providers/url_resolver.dart';
import '../../theme/app_theme.dart';

const double _kMinCardWidth = 200;
const double _kCardGap = 14;
const double _kCardRunGap = 16;
const int _kMaxColumns = 4;

/// Advertisement cards for the browsable catalogs, grouped by source, on the
/// search zero state. Two-stage load: the plans (source → categories) resolve
/// first and lay out the final grid as shimmer cards; each card swaps to real
/// content as its preview items arrive.
class CatalogCardsSection extends ConsumerWidget {
  /// Fires an AI search when a card is tapped — its title scoped to the card's
  /// source, e.g. "Popular Tracks on Jamendo".
  final ValueChanged<String> onSubmit;

  const CatalogCardsSection({super.key, required this.onSubmit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Plans and previews cache indefinitely between the 12-hour refreshes;
    // after a reconnect drop them so the section re-fetches instead of
    // keeping pre-outage data or a stuck error.
    ref.listen(connectionStateProvider, (prev, next) {
      if (next == ConnectionStatus.connected &&
          prev != ConnectionStatus.connected) {
        ref.invalidate(catalogCardGroupsProvider);
        ref.invalidate(catalogCardPreviewProvider); // family → all cards
      }
    });

    final groupsAsync = ref.watch(catalogCardGroupsProvider);

    return groupsAsync.when(
      // Counts unknown yet — one nominal shimmer group so the section doesn't
      // pop in. Once plans resolve, each source gets its exact card count.
      loading: () => _sectionColumn([
        _ShimmerBar(width: 120, height: 12),
        const SizedBox(height: 12),
        const _CardGrid(cardCount: 3, children: null),
      ]),
      error: (_, __) => const SizedBox.shrink(),
      data: (groups) {
        if (groups.isEmpty) return const SizedBox.shrink();
        return _sectionColumn([
          for (final group in groups) ...[
            _SourceGroupHeader(group: group),
            const SizedBox(height: 10),
            _CardGrid(
              cardCount: group.cards.length,
              children: [
                for (final plan in group.cards)
                  _CatalogCard(
                    plan: plan,
                    tint: _tintFor(group.sourceName),
                    onTap: () => onSubmit(_queryFor(plan, group)),
                  ),
              ],
            ),
            const SizedBox(height: 18),
          ],
        ]);
      },
    );
  }

  Widget _sectionColumn(List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        Text('EXPLORE THE CATALOGS', style: KalinkaTextStyles.sectionLabel),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  /// The AI query a card fires: its title scoped to the card's source.
  String _queryFor(CatalogCardPlan plan, CatalogCardGroup group) {
    final source = isLocalSource(group.sourceName)
        ? 'Local library'
        : group.sourceTitle;
    return '${plan.title} on $source';
  }
}

Color _tintFor(String sourceName) => colorForSourceName(sourceName);

/// Source attribution header: letter badge + tinted uppercase title. The
/// local-files source is the unmarked default — no badge, generic title —
/// mirroring the result-card conventions.
class _SourceGroupHeader extends StatelessWidget {
  final CatalogCardGroup group;

  const _SourceGroupHeader({required this.group});

  @override
  Widget build(BuildContext context) {
    final isLocal = isLocalSource(group.sourceName);
    final tint = _tintFor(group.sourceName);
    final title = isLocal ? 'Local library' : group.sourceTitle;

    return Row(
      children: [
        if (!isLocal && title.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.14),
              border: Border.all(color: tint.withValues(alpha: 0.30), width: 1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              title[0].toUpperCase(),
              style: KalinkaTextStyles.sourceBadgeLetter.copyWith(
                fontSize: 11,
                color: tint,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            title.toUpperCase(),
            style: KalinkaTextStyles.sectionLabel.copyWith(color: tint),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Responsive card grid: 1–4 equal columns, never more, sized from the
/// available width. With [children] null it renders [cardCount] shimmer
/// cards instead (the plans-loading state).
class _CardGrid extends StatelessWidget {
  final int cardCount;
  final List<Widget>? children;

  const _CardGrid({required this.cardCount, required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final columns = ((w + _kCardGap) / (_kMinCardWidth + _kCardGap))
            .floor()
            .clamp(1, _kMaxColumns);
        final itemWidth = (w - (columns - 1) * _kCardGap) / columns;

        return Wrap(
          spacing: _kCardGap,
          runSpacing: _kCardRunGap,
          children: [
            for (int i = 0; i < cardCount; i++)
              SizedBox(
                width: itemWidth,
                child: children != null
                    ? children![i]
                    : const _ShimmerCatalogCard(),
              ),
          ],
        );
      },
    );
  }
}

/// One category card: shimmer until its preview resolves, then the tinted
/// advertisement card. A failed preview fetch still shows the card — the
/// title and description are already known — with a procedural strip.
class _CatalogCard extends ConsumerWidget {
  final CatalogCardPlan plan;
  final Color tint;
  final VoidCallback? onTap;

  const _CatalogCard({required this.plan, required this.tint, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final previewAsync = ref.watch(catalogCardPreviewProvider(plan.id));
    return previewAsync.when(
      loading: () => const _ShimmerCatalogCard(),
      error: (_, __) => _CardBody(
        plan: plan,
        tint: tint,
        preview: CatalogCardPreview.procedural,
        onTap: onTap,
      ),
      data: (preview) =>
          _CardBody(plan: plan, tint: tint, preview: preview, onTap: onTap),
    );
  }
}

// Shared geometry between the real card and its shimmer twin, so the swap
// doesn't shift the grid. A composed hero card: background + icon + title +
// description, with a row of small previews pinned near the bottom.
const double _kCardRadius = 16;
const EdgeInsets _kCardPadding = EdgeInsets.all(14);
const double _kBadgeSize = 30;
const double _kPreviewGap = 8;
const double _kPreviewRadius = 8;
// White text sits over artwork, so a soft drop shadow keeps it legible on
// bright backgrounds.
const List<Shadow> _kTextShadow = [
  Shadow(color: Color(0xCC000000), blurRadius: 8, offset: Offset(0, 1)),
];

class _CardBody extends StatefulWidget {
  final CatalogCardPlan plan;
  final Color tint;
  final CatalogCardPreview preview;
  final VoidCallback? onTap;

  const _CardBody({
    required this.plan,
    required this.tint,
    required this.preview,
    this.onTap,
  });

  @override
  State<_CardBody> createState() => _CardBodyState();
}

class _CardBodyState extends State<_CardBody> {
  bool _hovered = false;
  bool _pressed = false;

  void _setHover(bool value) {
    if (value != _hovered) setState(() => _hovered = value);
  }

  void _setPressed(bool value) {
    if (value != _pressed) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final tint = widget.tint;
    final description = plan.description?.trim() ?? '';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _setHover(true),
      onExit: (_) => _setHover(false),
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: _pressed ? 0.98 : 1.0,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              color: KalinkaColors.surfaceRaised,
              borderRadius: BorderRadius.circular(_kCardRadius),
              border: Border.all(
                color: tint.withValues(alpha: _hovered ? 0.55 : 0.22),
                width: 1,
              ),
            ),
            // Clip one step inside the frame, else the image runs under the
            // border and swallows the rounded corners.
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_kCardRadius - 1),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _CardBackground(plan: plan, preview: widget.preview),
                  ),
                  Padding(
                    padding: _kCardPadding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            _iconBadge(tint),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                plan.title,
                                style: KalinkaFonts.sans(
                                  fontSize: KalinkaTypography.baseSize + 4,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  height: 1.15,
                                ).copyWith(shadows: _kTextShadow),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            description,
                            style: KalinkaFonts.sans(
                              fontSize: KalinkaTypography.baseSize - 1,
                              color: Colors.white.withValues(alpha: 0.68),
                              height: 1.25,
                            ).copyWith(shadows: _kTextShadow),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 14),
                        if (widget.preview.fill == CatalogCardFill.textual)
                          _TextualPreview(
                            names: widget.preview.names,
                            itemCount: widget.preview.itemCount,
                          )
                        else
                          _PreviewRow(plan: plan, preview: widget.preview),
                      ],
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

  Widget _iconBadge(Color tint) {
    return Container(
      width: _kBadgeSize,
      height: _kBadgeSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          tint.withValues(alpha: 0.30),
          Colors.black.withValues(alpha: 0.38),
        ),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: tint.withValues(alpha: 0.60), width: 1),
      ),
      child: Icon(
        _contentIcon(widget.plan.contentType),
        size: 17,
        color: Colors.white,
      ),
    );
  }

  IconData _contentIcon(PreviewContentType? type) {
    switch (type) {
      case PreviewContentType.artist:
        return Icons.person_outline;
      case PreviewContentType.playlist:
        return Icons.queue_music_rounded;
      case PreviewContentType.track:
        return Icons.music_note_rounded;
      case PreviewContentType.catalog:
        return Icons.grid_view_rounded;
      case PreviewContentType.album:
      case PreviewContentType.unknown:
      case null:
        return Icons.album_outlined;
    }
  }
}

/// Post-blur tone for the backdrop: ~-12% brightness, ~0.85 saturation,
/// luminance-preserving so the cover's dominant colour survives.
const ColorFilter _kArtworkTone = ColorFilter.matrix(<double>[
  0.7761, 0.0944, 0.0095, 0, 0,
  0.0281, 0.8424, 0.0095, 0, 0,
  0.0281, 0.0944, 0.7575, 0, 0,
  0, 0, 0, 1, 0,
]);

/// Card backdrop: the hero cover, blurred and toned, under near-black overlays
/// so cards read dark and vary mainly by the artwork's colour.
class _CardBackground extends ConsumerWidget {
  final CatalogCardPlan plan;
  final CatalogCardPreview preview;

  const _CardBackground({required this.plan, required this.preview});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final arts = preview.fill == CatalogCardFill.arts
        ? preview.artPaths
        : const <String>[];

    final Widget base;
    if (arts.isNotEmpty) {
      final resolver = ref.watch(urlResolverProvider);
      final heroPath = arts.length > 3 ? arts[3] : arts.first;
      // ColorFilter is an ImageFilter, so compose keeps blur+tone to one
      // save-layer. Clamp keeps blurred edges opaque; 400px decode suffices.
      base = ImageFiltered(
        imageFilter: ImageFilter.compose(
          outer: _kArtworkTone,
          inner: ImageFilter.blur(
            sigmaX: 10,
            sigmaY: 10,
            tileMode: TileMode.clamp,
          ),
        ),
        child: _tileImage(
          resolver.abs(heroPath),
          '${plan.id}/hero',
          cacheWidth: 400,
        ),
      );
    } else {
      base = CustomPaint(painter: _ProceduralStripPainter(plan.id));
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        base,
        // Flat floor, then a top-left-deep directional gradient, a bottom
        // scrim, and an edge vignette.
        const ColoredBox(color: Color(0x61000000)),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.centerRight,
              colors: [Color(0xB3000000), Color(0x47000000), Color(0x00000000)],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x00000000), Color(0x00000000), Color(0x61000000)],
              stops: [0.0, 0.55, 1.0],
            ),
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.0,
              colors: [Color(0x00000000), Color(0x3D000000)],
              stops: [0.7, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}

/// The row of up to three small preview thumbnails at the foot of the card —
/// circular for artists, rounded squares otherwise, procedural where a cover
/// is missing.
class _PreviewRow extends ConsumerWidget {
  final CatalogCardPlan plan;
  final CatalogCardPreview preview;

  const _PreviewRow({required this.plan, required this.preview});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final circle = plan.contentType == PreviewContentType.artist;
    final arts = preview.fill == CatalogCardFill.arts
        ? preview.artPaths.take(3).toList()
        : const <String>[];
    final resolver = arts.isNotEmpty ? ref.watch(urlResolverProvider) : null;

    return Row(
      children: [
        for (int i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(width: _kPreviewGap),
          Expanded(
            child: _previewThumb(
              url: i < arts.length ? resolver!.abs(arts[i]) : null,
              seed: '${plan.id}/p$i',
              circle: circle,
            ),
          ),
        ],
      ],
    );
  }
}

/// A stable colour per category name.
Color _categoryColor(String name) {
  final hue = (name.toLowerCase().hashCode % 360).toDouble().abs();
  return HSLColor.fromAHSL(1, hue, 0.55, 0.66).toColor();
}

/// Category names for a coverless (textual) catalog, in the same footprint as
/// the three-thumbnail row so card heights match. Corner badge shows the total.
class _TextualPreview extends StatelessWidget {
  final List<String> names;
  final int? itemCount;

  const _TextualPreview({required this.names, this.itemCount});

  @override
  Widget build(BuildContext context) {
    final showCount = itemCount != null && itemCount! > 0;
    return LayoutBuilder(
      builder: (context, constraints) {
        // Height of the three square thumbnails the artwork cards show here.
        final h = (constraints.maxWidth - 2 * _kPreviewGap) / 3;
        return SizedBox(
          height: h,
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.only(right: showCount ? 34 : 0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final name in names.take(3))
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _categoryColor(name),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              name,
                              style: KalinkaFonts.sans(
                                fontSize: KalinkaTypography.baseSize,
                                fontWeight: FontWeight.w600,
                                color: _categoryColor(name),
                              ).copyWith(shadows: _kTextShadow),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              if (showCount)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      '$itemCount',
                      style: KalinkaFonts.sans(
                        fontSize: KalinkaTypography.baseSize - 1,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
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

/// One square preview thumbnail — a cover, or procedural abstract art when
/// absent. Sized by its parent (see [_PreviewRow]).
Widget _previewThumb({
  required String? url,
  required String seed,
  required bool circle,
}) {
  return AspectRatio(
    aspectRatio: 1,
    child: Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(_kPreviewRadius),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: url != null
          ? _tileImage(url, seed, cacheWidth: 200)
          : CustomPaint(painter: _ProceduralStripPainter(seed)),
    ),
  );
}

/// One cover image, falling back to procedural art if it fails to load.
Widget _tileImage(String url, String seed, {int cacheWidth = 300}) {
  return Image.network(
    url,
    fit: BoxFit.cover,
    cacheWidth: cacheWidth,
    gaplessPlayback: true,
    filterQuality: FilterQuality.medium,
    errorBuilder: (_, __, ___) =>
        CustomPaint(painter: _ProceduralStripPainter(seed)),
  );
}

/// Abstract one-piece art for categories without usable covers: layered
/// radial blobs in the berry/brass hue family, faint rings and accent dots —
/// the wide-rectangle sibling of [ProceduralAlbumArt].
class _ProceduralStripPainter extends CustomPainter {
  final String seed;

  _ProceduralStripPainter(this.seed);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(seed.hashCode);
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    canvas.drawRect(rect, Paint()..color = KalinkaColors.background);

    // Three soft blobs in the berry/brass range (340–400°), like the album
    // art painter but scattered across the wide rectangle.
    for (int i = 0; i < 3; i++) {
      final hue = (340.0 + rng.nextDouble() * 60.0) % 360.0;
      final color = HSLColor.fromAHSL(1, hue, 0.55, 0.24).toColor();
      final center = Offset(
        size.width * rng.nextDouble(),
        size.height * rng.nextDouble(),
      );
      final radius = size.height * (0.7 + rng.nextDouble() * 0.9);
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [color.withValues(alpha: 0.85), color.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, paint);
    }

    // Faint concentric rings echoing the album art motif.
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    final ringCenter = Offset(
      size.width * (0.2 + rng.nextDouble() * 0.6),
      size.height * rng.nextDouble(),
    );
    ringPaint.color = Colors.white.withValues(alpha: 0.05);
    canvas.drawCircle(ringCenter, size.height * 0.75, ringPaint);
    ringPaint.color = Colors.white.withValues(alpha: 0.04);
    canvas.drawCircle(ringCenter, size.height * 0.45, ringPaint);

    // Berry and brass accent dots.
    canvas.drawCircle(
      Offset(
        size.width * (0.1 + rng.nextDouble() * 0.8),
        size.height * (0.2 + rng.nextDouble() * 0.6),
      ),
      min(size.height * 0.05, 2.5),
      Paint()..color = KalinkaColors.accent,
    );
    canvas.drawCircle(
      Offset(
        size.width * (0.1 + rng.nextDouble() * 0.8),
        size.height * (0.2 + rng.nextDouble() * 0.6),
      ),
      min(size.height * 0.04, 1.8),
      Paint()..color = KalinkaColors.gold,
    );
  }

  @override
  bool shouldRepaint(_ProceduralStripPainter oldDelegate) =>
      oldDelegate.seed != seed;
}

/// Shimmer twin of a catalog card: same paddings and slot heights, neutral
/// surfaces, pulsing opacity like [ZeroStateShimmer].
class _ShimmerCatalogCard extends StatefulWidget {
  const _ShimmerCatalogCard();

  @override
  State<_ShimmerCatalogCard> createState() => _ShimmerCatalogCardState();
}

class _ShimmerCatalogCardState extends State<_ShimmerCatalogCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _opacity = Tween<double>(
      begin: 0.4,
      end: 0.7,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacity,
      builder: (context, child) =>
          Opacity(opacity: _opacity.value, child: child),
      child: Container(
        padding: _kCardPadding,
        decoration: BoxDecoration(
          color: KalinkaColors.surfaceRaised,
          borderRadius: BorderRadius.circular(_kCardRadius),
          border: Border.all(color: KalinkaColors.borderSubtle, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: _kBadgeSize,
              height: _kBadgeSize,
              decoration: BoxDecoration(
                color: KalinkaColors.surfaceInput,
                borderRadius: BorderRadius.circular(9),
              ),
            ),
            const SizedBox(height: 12),
            _ShimmerBar(width: 120, height: 14),
            const SizedBox(height: 8),
            _ShimmerBar(width: 150, height: 10),
            const SizedBox(height: 16),
            Row(
              children: [
                for (int i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: _kPreviewGap),
                  Expanded(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: KalinkaColors.surfaceInput,
                          borderRadius: BorderRadius.circular(_kPreviewRadius),
                        ),
                      ),
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

class _ShimmerBar extends StatelessWidget {
  final double width;
  final double height;

  const _ShimmerBar({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: KalinkaColors.surfaceInput,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

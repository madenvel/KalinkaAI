import 'dart:math' show Random, min;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data_model/data_model.dart';
import '../../providers/catalog_cards_provider.dart';
import '../../providers/connection_state_provider.dart';
import '../../providers/source_modules_provider.dart';
import '../../providers/url_resolver.dart';
import '../../theme/app_theme.dart';

const double _kMinCardWidth = 160;
const double _kCardGap = 10;
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
          runSpacing: _kCardGap,
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
// doesn't shift the grid.
const _kCardPadding = EdgeInsets.all(12);
const double _kCardRadius = 16;
const double _kNameRowHeight = 20;
const double _kStripAspect = 3.0;
const double _kStripRadius = 9;

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

    // Hover and press both brighten the tinted border and fill; press also
    // dips the scale a touch for tactile "it registered" feedback.
    final borderAlpha = _pressed
        ? 0.70
        : _hovered
        ? 0.50
        : 0.22;
    final fillAlpha = _pressed
        ? 0.22
        : _hovered
        ? 0.17
        : 0.10;

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
          // Same attribution recipe as the search result section cards.
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            padding: _kCardPadding,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: const [0.0, 0.55],
                colors: [
                  Color.alphaBlend(
                    tint.withValues(alpha: fillAlpha),
                    KalinkaColors.surfaceRaised,
                  ),
                  KalinkaColors.surfaceRaised,
                ],
              ),
              borderRadius: BorderRadius.circular(_kCardRadius),
              border: Border.all(
                color: tint.withValues(alpha: borderAlpha),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: _kNameRowHeight,
                  child: Row(
                    children: [
                      Icon(
                        _contentIcon(plan.contentType),
                        size: 15,
                        color: tint,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          plan.title,
                          style: KalinkaFonts.sans(
                            fontSize: KalinkaTypography.baseSize + 2,
                            fontWeight: FontWeight.w600,
                            color: KalinkaColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                // Only reserve space for a description when there is one —
                // otherwise the card closes straight up to the preview.
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    description,
                    style: KalinkaTextStyles.trackRowSubtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 10),
                _PreviewStrip(plan: plan, preview: widget.preview),
              ],
            ),
          ),
        ),
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

/// The 3:1 preview strip in one of its three fills: three distinct covers,
/// names over a seeded gradient, or one abstract procedural rectangle.
class _PreviewStrip extends ConsumerWidget {
  final CatalogCardPlan plan;
  final CatalogCardPreview preview;

  const _PreviewStrip({required this.plan, required this.preview});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Widget fill;
    switch (preview.fill) {
      case CatalogCardFill.arts:
        final resolver = ref.watch(urlResolverProvider);
        fill = Row(
          children: [
            for (int i = 0; i < preview.artPaths.length; i++) ...[
              if (i > 0) const SizedBox(width: 1),
              Expanded(
                child: Image.network(
                  resolver.abs(preview.artPaths[i]),
                  fit: BoxFit.cover,
                  cacheWidth: 180,
                  gaplessPlayback: true,
                  filterQuality: FilterQuality.low,
                  errorBuilder: (_, __, ___) => CustomPaint(
                    painter: _ProceduralStripPainter('${plan.id}/$i'),
                  ),
                ),
              ),
            ],
          ],
        );
      case CatalogCardFill.textual:
        fill = _TextualFill(seed: plan.id, names: preview.names);
      case CatalogCardFill.procedural:
        fill = CustomPaint(painter: _ProceduralStripPainter(plan.id));
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: KalinkaColors.borderSubtle, width: 1),
        borderRadius: BorderRadius.circular(_kStripRadius),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_kStripRadius - 1),
        child: AspectRatio(aspectRatio: _kStripAspect, child: fill),
      ),
    );
  }
}

/// Names over a dark two-tone gradient seeded from the category id — the
/// textual catalogs' answer to cover art.
class _TextualFill extends StatelessWidget {
  final String seed;
  final List<String> names;

  const _TextualFill({required this.seed, required this.names});

  @override
  Widget build(BuildContext context) {
    final rng = Random(seed.hashCode);
    final hue = rng.nextDouble() * 360;
    final colors = [
      HSLColor.fromAHSL(1, hue, 0.45, 0.22).toColor(),
      HSLColor.fromAHSL(1, (hue + 40) % 360, 0.50, 0.13).toColor(),
    ];

    final rows = names.take(3).toList();
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Container(height: 1, color: Colors.white.withValues(alpha: 0.06)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 9),
                child: Row(
                  children: [
                    Container(
                      width: 3,
                      height: 3,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        rows[i],
                        style: KalinkaFonts.mono(
                          fontSize: KalinkaTypography.baseSize - 2,
                          color: KalinkaColors.textPrimary.withValues(
                            alpha: 0.88,
                          ),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: _kNameRowHeight,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _ShimmerBar(width: 110, height: 12),
              ),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(_kStripRadius),
              child: const AspectRatio(
                aspectRatio: _kStripAspect,
                child: ColoredBox(color: KalinkaColors.surfaceInput),
              ),
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

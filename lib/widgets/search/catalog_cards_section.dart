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

// The server renders card backgrounds at 16:9; the card frame matches so the
// art fills it without letterboxing.
const double _kCardAspect = 16 / 9;

// Left fraction of the card the server keeps dark for text (its TEXT_ZONE_W).
// The client bounds its title/description column to the same fraction so the
// two agree on where text lives and where the artwork is free to show.
const double _kTextZoneWidth = 0.62;

/// Advertisement cards for the browsable catalogs, grouped by source, on the
/// search zero state. The plans (source → categories) resolve first and lay
/// out the grid; each card's background is a single server-rendered image
/// referenced by the plan (or a black backdrop until the server produces it).
class CatalogCardsSection extends ConsumerWidget {
  /// Fires an AI search when a card is tapped — its title scoped to the card's
  /// source, e.g. "Popular Tracks on Jamendo".
  final ValueChanged<String> onSubmit;

  const CatalogCardsSection({super.key, required this.onSubmit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Plans cache between refreshes; after a reconnect drop them so the section
    // re-fetches instead of keeping pre-outage data or a stuck error.
    ref.listen(connectionStateProvider, (prev, next) {
      if (next == ConnectionStatus.connected &&
          prev != ConnectionStatus.connected) {
        ref.invalidate(catalogCardGroupsProvider);
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

// Shared geometry between the real card and its shimmer twin, so the swap
// doesn't shift the grid.
const double _kCardRadius = 16;
const EdgeInsets _kCardPadding = EdgeInsets.all(14);
const double _kBadgeSize = 30;
// White text sits over the server artwork; a soft drop shadow keeps it legible
// even where the baked-in scrim is lightest.
const List<Shadow> _kTextShadow = [
  Shadow(color: Color(0xCC000000), blurRadius: 8, offset: Offset(0, 1)),
];

/// One category card: the server-rendered background (or black until it
/// exists) with the icon, title and description drawn on top.
class _CatalogCard extends StatefulWidget {
  final CatalogCardPlan plan;
  final Color tint;
  final VoidCallback? onTap;

  const _CatalogCard({required this.plan, required this.tint, this.onTap});

  @override
  State<_CatalogCard> createState() => _CatalogCardState();
}

class _CatalogCardState extends State<_CatalogCard> {
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
          child: AspectRatio(
            aspectRatio: _kCardAspect,
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
                    Positioned.fill(child: _CardBackground(plan: plan)),
                    Padding(
                      padding: _kCardPadding,
                      // Bound the text to the left column the server keeps dark
                      // (its TEXT_ZONE_W), so the title/description never sprawl
                      // across the artwork on the right.
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final cardWidth =
                              constraints.maxWidth + _kCardPadding.horizontal;
                          final textMax =
                              (cardWidth * _kTextZoneWidth - _kCardPadding.left)
                                  .clamp(0.0, constraints.maxWidth);
                          return Align(
                            alignment: Alignment.topLeft,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: textMax),
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
                                            fontSize:
                                                KalinkaTypography.baseSize + 4,
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
                                        color: Colors.white.withValues(
                                          alpha: 0.68,
                                        ),
                                        height: 1.25,
                                      ).copyWith(shadows: _kTextShadow),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
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

/// Card backdrop: the server-rendered background image, or a plain black
/// rectangle until the server has produced it (and while it loads / on error).
/// A key on the resolved URL forces a re-decode when the link changes.
class _CardBackground extends ConsumerWidget {
  final CatalogCardPlan plan;

  const _CardBackground({required this.plan});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = plan.artPath;
    if (path == null || path.isEmpty) {
      return const ColoredBox(color: Colors.black);
    }
    final url = ref.watch(urlResolverProvider).abs(path);
    return Image.network(
      url,
      key: ValueKey(url),
      fit: BoxFit.cover,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      // Fade in once decoded so the swap from black isn't a hard cut.
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
          child: child,
        );
      },
      errorBuilder: (_, __, ___) => const ColoredBox(color: Colors.black),
    );
  }
}

/// Shimmer twin of a catalog card: same frame and aspect, neutral surfaces,
/// pulsing opacity like [ZeroStateShimmer].
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
      child: AspectRatio(
        aspectRatio: _kCardAspect,
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
              Row(
                children: [
                  Container(
                    width: _kBadgeSize,
                    height: _kBadgeSize,
                    decoration: BoxDecoration(
                      color: KalinkaColors.surfaceInput,
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: _ShimmerBar(width: 120, height: 14)),
                ],
              ),
              const SizedBox(height: 12),
              _ShimmerBar(width: 150, height: 10),
            ],
          ),
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

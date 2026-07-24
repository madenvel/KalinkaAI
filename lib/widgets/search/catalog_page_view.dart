import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data_model/data_model.dart';
import '../../providers/kalinka_player_api_provider.dart';
import '../../providers/search_session_provider.dart';
import '../../theme/app_theme.dart';
import '../browse_rows_shimmer.dart';
import '../infinite_list_view.dart';
import '../search_cards/browse_item_rows.dart';
import '../source_badge.dart';

/// One selected catalog page — the single navigation level below the Catalogs
/// root. A pinned two-item context header (`‹ Catalogs` + the Playfair category
/// title + provider) sits over the browsed items; albums/artists/playlists
/// unroll inline (they are content state, not further navigation). Items are
/// pulled in chunks by an [InfiniteListView] straight off the browse endpoint
/// (deterministic — never the AI router), so long catalogs scroll endlessly.
class CatalogPageView extends ConsumerWidget {
  final CatalogPage page;

  /// Returns to the Catalogs root (the search screen). Shared by the `‹
  /// Catalogs` link and the back arrow / system back.
  final VoidCallback onBackToCatalogs;

  const CatalogPageView({
    super.key,
    required this.page,
    required this.onBackToCatalogs,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ContextHeader(page: page, onBack: onBackToCatalogs),
        Expanded(
          child: InfiniteListView<BrowseItem>(
            key: ValueKey(page.id),
            reloadKey: page.id,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            fetchChunk: (offset, limit) async {
              final api = ref.read(kalinkaProxyProvider);
              final list = await api.browse(
                page.id!,
                offset: offset,
                limit: limit,
              );
              return ItemChunk(items: list.items, total: list.total);
            },
            separatorBuilder: (context, _) => const Divider(
              color: KalinkaColors.borderSubtle,
              thickness: 1,
              height: 14,
            ),
            itemBuilder: (context, item, index, loaded) {
              // Track rows play the whole loaded list as a queue from the
              // tapped row; as more chunks scroll in, the context grows.
              final trackIds = [
                for (final i in loaded)
                  if (i.track != null) i.id,
              ];
              return BrowseItemRows.buildRow(
                item,
                queueContextIds: trackIds.isEmpty ? null : trackIds,
              );
            },
            initialPlaceholder: const Padding(
              padding: EdgeInsets.only(top: 4),
              child: BrowseRowsShimmer(count: 8),
            ),
            loadMorePlaceholder: const BrowseRowsShimmer(
              count: 3,
              leadingDivider: true,
            ),
            emptyBuilder: (context) => const _CatalogEmpty(),
            errorBuilder: (context, _) =>
                _CatalogError(onReturn: onBackToCatalogs),
          ),
        ),
      ],
    );
  }
}

/// `‹ Catalogs` parent link over the Playfair category title and provider
/// subtitle — the whole context, never more than two items.
class _ContextHeader extends ConsumerWidget {
  final CatalogPage page;
  final VoidCallback onBack;

  const _ContextHeader({required this.page, required this.onBack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Everything in this header hangs off one left edge (16). The `‹ CATALOGS`
    // eyebrow cancels the chevron glyph's own left bearing (Transform) so its
    // stroke — not the icon box — lines up with the title beneath it.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
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
                        style: KalinkaTextStyles.sectionLabel.copyWith(
                          color: KalinkaColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            page.title ?? '',
            style: KalinkaFonts.display(
              fontSize: KalinkaTypography.baseSize + 12,
              fontWeight: FontWeight.w600,
              color: KalinkaColors.textPrimary,
            ),
          ),
          // Attribution: the source badge (hidden for the local library / a
          // single source) beside the provider name, then the description.
          if (page.provider != null && page.provider!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  SourceBadge(entityId: page.id!),
                  if (sourceBadgeVisible(ref, page.id!))
                    const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      page.provider!,
                      style: KalinkaTextStyles.trackRowSubtitle.copyWith(
                        color: KalinkaColors.textMuted,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          if (page.description != null && page.description!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                page.description!,
                style: KalinkaTextStyles.trackRowSubtitle.copyWith(
                  color: KalinkaColors.textPrimary,
                ),
              ),
            ),
        ],
      ),
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

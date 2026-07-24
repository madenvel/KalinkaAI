import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/browse_detail_provider.dart';
import '../../providers/search_session_provider.dart';
import '../../theme/app_theme.dart';
import '../search_cards/browse_item_rows.dart';

/// One selected catalog page — the single navigation level below the Catalogs
/// root. A pinned two-item context header (`‹ Catalogs` + the Playfair category
/// title + provider) sits over the browsed items; albums/artists/playlists
/// unroll inline (they are content state, not further navigation). Its data is
/// fetched deterministically via [browseDetailProvider] — never the AI router.
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
    final async = ref.watch(browseDetailProvider(page.id!));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ContextHeader(page: page, onBack: onBackToCatalogs),
        Expanded(
          child: async.when(
            loading: () => const Center(
              child: SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: KalinkaColors.accent,
                ),
              ),
            ),
            error: (_, __) => _CatalogError(onReturn: onBackToCatalogs),
            data: (list) {
              final items = list.items;
              if (items.isEmpty) {
                return const _CatalogEmpty();
              }
              // Track-only catalogs play as one queue from the tapped row.
              final trackIds = [
                for (final i in items)
                  if (i.track != null) i.id,
              ];
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  BrowseItemRows(
                    items: items,
                    dividers: true,
                    queueContextIds: trackIds.isEmpty ? null : trackIds,
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// `‹ Catalogs` parent link over the Playfair category title and provider
/// subtitle — the whole context, never more than two items.
class _ContextHeader extends StatelessWidget {
  final CatalogPage page;
  final VoidCallback onBack;

  const _ContextHeader({required this.page, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            onPressed: onBack,
            icon: const Icon(Icons.chevron_left_rounded, size: 20),
            label: const Text('Catalogs'),
            style: TextButton.styleFrom(
              foregroundColor: KalinkaColors.textSecondary,
              textStyle: KalinkaTextStyles.trackRowSubtitle.copyWith(
                fontWeight: FontWeight.w600,
              ),
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              page.title ?? '',
              style: KalinkaFonts.display(
                fontSize: KalinkaTypography.baseSize + 8,
                fontWeight: FontWeight.w600,
                color: KalinkaColors.textPrimary,
              ),
            ),
          ),
          if (page.provider != null && page.provider!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 2),
              child: Text(
                page.provider!,
                style: KalinkaTextStyles.trackRowSubtitle.copyWith(
                  color: KalinkaColors.textMuted,
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

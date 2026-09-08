import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/catalog_cards_provider.dart';
import '../../providers/collections_provider.dart';
import '../../providers/connection_state_provider.dart';
import '../../theme/app_theme.dart';
import '../browse_rows_shimmer.dart';
import '../collection_art_tile.dart';
import '../kalinka_button.dart';
import 'new_collection_sheet.dart';
import '../search_cards/collection_row.dart';
import '../shelf_heading.dart';

/// Your collections on the Discover root: a heading with the count, the
/// first few as rows, and VIEW ALL into the rest. With none yet it shows
/// what a collection is and where making one will live. Absent entirely when
/// the server has no collections source.
///
/// The rows are shortcuts into the Collections screen rather than a second
/// place to unroll a collection — the root has to keep a settled height.
class CollectionsSection extends ConsumerWidget {
  /// Opens the Collections screen — where VIEW ALL and every row lead.
  final OpenCatalog onOpenCatalog;

  const CollectionsSection({super.key, required this.onOpenCatalog});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(connectionStateProvider, (prev, next) {
      if (next == ConnectionStatus.connected &&
          prev != ConnectionStatus.connected) {
        ref.invalidate(collectionsShelfProvider);
      }
    });

    final shelfAsync = ref.watch(collectionsShelfProvider);

    return shelfAsync.when(
      loading: () => _section(
        heading: const ShelfHeading(title: 'YOUR COLLECTIONS'),
        body: const BrowseRowsShimmer(count: 3),
      ),
      // A shelf that failed to load is not worth a message on the root; the
      // catalogs below still work, and the next reload tries again.
      error: (_, __) => const SizedBox.shrink(),
      data: (shelf) {
        if (shelf == null) return const SizedBox.shrink();
        if (shelf.isEmpty) {
          return _section(
            heading: ShelfHeading(title: shelf.plan.title.toUpperCase()),
            body: const CollectionsEmptyCard(),
          );
        }
        return _section(
          heading: ShelfHeading(
            title: shelf.plan.title.toUpperCase(),
            count: shelf.total,
            subtitle: shelf.plan.description,
            onViewAll: () => onOpenCatalog(shelf.plan, shelf.plan.title),
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < shelf.items.length; i++) ...[
                if (i > 0)
                  const Divider(
                    color: KalinkaColors.borderSubtle,
                    thickness: 1,
                    height: 1,
                  ),
                CollectionShelfRow(
                  item: shelf.items[i],
                  onOpen: () => onOpenCatalog(
                    shelf.plan,
                    shelf.plan.title,
                    focusItemId: shelf.items[i].id,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _section({required Widget heading, required Widget body}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        heading,
        const SizedBox(height: 10),
        body,
        const SizedBox(height: 26),
      ],
    );
  }
}

/// What stands where the collections will be: the tile a collection gets
/// before it has a cover, a line on what one is, and the action that makes
/// one.
class CollectionsEmptyCard extends ConsumerWidget {
  const CollectionsEmptyCard({super.key});

  static const _tileSize = 128.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: KalinkaColors.surfaceRaised,
        border: Border.all(color: KalinkaColors.borderSubtle, width: 1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 380;
          final tile = CollectionArtTile(
            seed: 'collections',
            size: _tileSize,
            radius: 14,
          );
          final words = Column(
            crossAxisAlignment: stacked
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'No collections yet',
                style: KalinkaTextStyles.emptyQueueTitle,
                textAlign: stacked ? TextAlign.center : TextAlign.start,
              ),
              const SizedBox(height: 6),
              Text(
                'Mix tracks from any source into your own ordered lists.',
                style: KalinkaTextStyles.emptyQueueSubtitle,
                textAlign: stacked ? TextAlign.center : TextAlign.start,
              ),
              const SizedBox(height: 16),
              KalinkaButton(
                label: 'CREATE COLLECTION',
                leading: const Icon(Icons.add, size: 18),
                onTap: () => showNewCollectionSheet(context, ref),
              ),
            ],
          );

          if (stacked) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [tile, const SizedBox(height: 16), words],
            );
          }
          return Row(
            children: [
              tile,
              const SizedBox(width: 20),
              Expanded(child: words),
            ],
          );
        },
      ),
    );
  }
}

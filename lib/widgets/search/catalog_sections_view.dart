import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data_model/browse_filters.dart';
import '../../data_model/data_model.dart';
import '../../providers/catalog_section_provider.dart';
import '../../providers/search_session_provider.dart';
import '../../theme/app_theme.dart';
import '../browse_rows_shimmer.dart';
import '../hover_text_action.dart';
import '../search_cards/browse_item_rows.dart';

/// Items a shelf shows when its source did not say.
const _defaultPreviewLimit = 5;

/// A catalog made of several shelves — one per entity kind it holds — each
/// filled by its own browse request.
///
/// The page shows this only while no kind is chosen; choosing one narrows the
/// catalog itself to a flat list, which is the same listing a shelf shows.
/// Shelves load independently, so a slow one never holds up the rest.
class CatalogSectionsView extends StatelessWidget {
  final CatalogPage page;
  final BrowseFilterQuery query;

  /// The page banner and its active-filter chips, scrolling with the shelves.
  final Widget header;

  /// Opens one shelf in full, by narrowing the page to that kind.
  final ValueChanged<SearchType> onViewAll;

  const CatalogSectionsView({
    super.key,
    required this.page,
    required this.query,
    required this.header,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: page.sections.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) return header;
        final section = page.sections[index - 1];
        return _SectionShelf(
          section: section,
          query: query,
          onViewAll: onViewAll,
        );
      },
    );
  }
}

class _SectionShelf extends ConsumerWidget {
  final BrowseItem section;
  final BrowseFilterQuery query;
  final ValueChanged<SearchType> onViewAll;

  const _SectionShelf({
    required this.section,
    required this.query,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = section.catalog;
    if (catalog == null) return const SizedBox.shrink();

    // Built from what this shelf declared, never the page's: a constraint the
    // shelf cannot honour is dropped here rather than refused by its source.
    final capabilities = BrowseFilterCapabilities.fromSpecs(
      catalog.filters,
      catalogId: section.id,
    );
    final limit = catalog.previewConfig?.itemsCount ?? _defaultPreviewLimit;
    final preview = ref.watch(
      catalogSectionProvider((
        id: section.id,
        filter: query.encoded(capabilities),
        limit: limit,
      )),
    );
    final title = section.name ?? catalog.title;
    final type = CatalogPage.typeOf(section);

    return preview.when(
      loading: () =>
          _Shelf(title: title, child: const BrowseRowsShimmer(count: 3)),
      // A shelf that failed says so in its own space; the rest of the page,
      // and the filters that could undo it, stay usable.
      error: (_, __) => _Shelf(
        title: title,
        child: Text(
          'Could not load',
          style: KalinkaTextStyles.trackRowSubtitle.copyWith(
            color: KalinkaColors.textMuted,
          ),
        ),
      ),
      data: (list) {
        if (list.items.isEmpty) return const SizedBox.shrink();
        final trackIds = <String>[
          for (final item in list.items)
            if (item.track != null) item.id,
        ];
        return _Shelf(
          title: title,
          count: list.total,
          onViewAll: type == null || list.total <= list.items.length
              ? null
              : () => onViewAll(type),
          child: BrowseItemRows(
            items: list.items,
            queueContextIds: trackIds.isEmpty ? null : trackIds,
          ),
        );
      },
    );
  }
}

/// One shelf: its heading, then whatever stands in for its items.
class _Shelf extends StatelessWidget {
  final String title;
  final int? count;
  final VoidCallback? onViewAll;
  final Widget child;

  const _Shelf({
    required this.title,
    required this.child,
    this.count,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                title.toUpperCase(),
                style: KalinkaTextStyles.sectionLabel.copyWith(
                  color: KalinkaColors.textPrimary,
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 8),
                Text(
                  '· $count',
                  style: KalinkaTextStyles.sectionLabel.copyWith(
                    color: KalinkaColors.textMuted,
                  ),
                ),
              ],
              const SizedBox(width: 12),
              const Expanded(
                child: Divider(
                  color: KalinkaColors.borderSubtle,
                  thickness: 1,
                  height: 1,
                ),
              ),
              if (onViewAll != null) ...[
                const SizedBox(width: 12),
                // Mono and unfilled like RESET ALL, so it reads as the
                // heading's action rather than a control of its own.
                HoverTextAction(
                  label: 'VIEW ALL',
                  semanticsLabel: 'View all',
                  onTap: onViewAll!,
                  color: KalinkaColors.accentTint,
                  hoverColor: KalinkaColors.textPrimary,
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

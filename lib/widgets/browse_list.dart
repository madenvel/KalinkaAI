import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data_model/data_model.dart';
import '../providers/browse_navigation_provider.dart';
import '../providers/kalinka_player_api_provider.dart';
import '../providers/url_resolver.dart';
import '../theme/app_theme.dart';
import 'path_bar.dart';
import 'procedural_album_art.dart';

/// Displays a section of browse items: collage preview -> expanded list ->
/// inline drill-down with PathBar. Replaces SectionCollage.
class BrowseList extends ConsumerStatefulWidget {
  final BrowseItem section;
  final bool isSearchResult;
  final Set<String>? selectedIds;
  final bool selectionMode;
  final ValueChanged<String>? onSelectionToggle;
  final VoidCallback? onSelectionStart;

  const BrowseList({
    super.key,
    required this.section,
    this.isSearchResult = false,
    this.selectedIds,
    this.selectionMode = false,
    this.onSelectionToggle,
    this.onSelectionStart,
  });

  @override
  ConsumerState<BrowseList> createState() => _BrowseListState();
}

class _BrowseListState extends ConsumerState<BrowseList> {
  int _displayedItems = 5;

  String get _sectionId => widget.section.id;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = widget.section.sections ?? [];

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    final browseState = ref.watch(browseNavigationProvider(_sectionId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.section.name != null && !widget.isSearchResult)
          Text(
            widget.section.name!,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        if (widget.section.name != null && !widget.isSearchResult)
          const SizedBox(height: 12),
        if (!browseState.isExpanded)
          InkWell(
            onTap: () {
              ref.read(browseNavigationProvider(_sectionId).notifier).expand();
            },
            borderRadius: BorderRadius.circular(12),
            child: Column(
              children: [
                _buildCollage(items, theme),
                const SizedBox(height: 8),
                _buildSummaryText(items, theme),
              ],
            ),
          )
        else
          _buildExpandedContent(theme, browseState, items),
      ],
    );
  }

  Widget _buildExpandedContent(
    ThemeData theme,
    BrowseNavigationState browseState,
    List<BrowseItem> rootItems,
  ) {
    // If drilled in, show the current drill-down level
    final displayItems = browseState.current?.items ?? rootItems;
    final visibleItems = displayItems.take(_displayedItems).toList();
    final totalItems = browseState.current?.totalItems ?? displayItems.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (browseState.stack.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: PathBar(
              segments: browseState.pathSegments,
              onNavigate: (index) {
                if (index < 0) {
                  ref
                      .read(browseNavigationProvider(_sectionId).notifier)
                      .navigateToLevel(-1);
                } else {
                  ref
                      .read(browseNavigationProvider(_sectionId).notifier)
                      .navigateToLevel(index);
                }
                setState(() {
                  _displayedItems = 5;
                });
              },
            ),
          ),
        ...visibleItems.map((item) => _buildListItem(item, theme)),
        if (browseState.isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          )
        else if (displayItems.length > _displayedItems ||
            displayItems.length < totalItems)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: TextButton.icon(
              onPressed: () {
                if (_displayedItems < displayItems.length) {
                  setState(() {
                    _displayedItems += 10;
                  });
                } else if (browseState.current != null) {
                  ref
                      .read(browseNavigationProvider(_sectionId).notifier)
                      .loadMore(browseState.current!.id);
                }
              },
              icon: const Icon(Icons.expand_more),
              label: const Text('Load more'),
            ),
          ),
      ],
    );
  }

  Widget _buildCollage(List<BrowseItem> items, ThemeData theme) {
    final urlResolver = ref.read(urlResolverProvider);

    final images = items.take(4).map((item) {
      final imageUrl = item.image?.thumbnail ?? item.image?.small;
      return imageUrl != null ? urlResolver.abs(imageUrl) : null;
    }).toList();

    return AspectRatio(
      aspectRatio: 1.0,
      child: Container(
        decoration: BoxDecoration(
          color: KalinkaColors.inputSurface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
            ),
            itemCount: 4,
            itemBuilder: (context, index) {
              if (index < images.length && images[index] != null) {
                return Image.network(
                  images[index]!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return _buildPlaceholder(theme);
                  },
                );
              } else {
                return _buildPlaceholder(theme);
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(ThemeData theme) {
    return Container(
      color: KalinkaColors.inputSurface,
      child: const Icon(Icons.album, size: 40, color: Color(0x4D98989A)),
    );
  }

  Widget _buildSummaryText(List<BrowseItem> items, ThemeData theme) {
    final names = items.take(2).map((item) {
      return item.name ?? item.album?.title ?? item.track?.title ?? 'Unknown';
    }).toList();

    final summaryText = items.length > 2
        ? '${names.join(', ')} and ${items.length - 2} others'
        : names.join(', ');

    return Text(
      summaryText,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildListItem(BrowseItem item, ThemeData theme) {
    final urlResolver = ref.read(urlResolverProvider);
    final imageUrl = item.image?.thumbnail ?? item.image?.small;
    final resolvedImageUrl = imageUrl != null
        ? urlResolver.abs(imageUrl)
        : null;
    final isSelected = widget.selectedIds?.contains(item.id) ?? false;

    return InkWell(
      onTap: () {
        if (widget.selectionMode) {
          widget.onSelectionToggle?.call(item.id);
        } else if (item.canBrowse) {
          ref
              .read(browseNavigationProvider(_sectionId).notifier)
              .drillDown(item);
          setState(() {
            _displayedItems = 5;
          });
        } else if (item.canAdd) {
          _addToQueue(item);
        }
      },
      onLongPress: widget.selectionMode
          ? null
          : () {
              HapticFeedback.mediumImpact();
              widget.onSelectionStart?.call();
              widget.onSelectionToggle?.call(item.id);
            },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            // Thumbnail or checkbox
            if (widget.selectionMode)
              SizedBox(
                width: 48,
                height: 48,
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Checkbox(
                      key: ValueKey('chk_${item.id}_$isSelected'),
                      value: isSelected,
                      onChanged: (_) => widget.onSelectionToggle?.call(item.id),
                    ),
                  ),
                ),
              )
            else
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: KalinkaColors.inputSurface,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: resolvedImageUrl != null
                      ? Image.network(
                          resolvedImageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return ProceduralAlbumArt(
                              trackId: item.id,
                              size: 48,
                            );
                          },
                        )
                      : ProceduralAlbumArt(trackId: item.id, size: 48),
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name ??
                        item.album?.title ??
                        item.track?.title ??
                        'Unknown',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: isSelected ? theme.colorScheme.primary : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.subname != null)
                    Text(
                      item.subname!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (!widget.selectionMode) ...[
              if (item.canBrowse)
                Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              if (item.canAdd && !item.canBrowse)
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  color: KalinkaColors.gold,
                  onPressed: () => _addToQueue(item),
                  tooltip: 'Add to queue',
                ),
              if (item.canAdd && item.canBrowse)
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  color: KalinkaColors.gold,
                  onPressed: () => _addToQueue(item),
                  tooltip: 'Add to queue',
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _addToQueue(BrowseItem item) async {
    try {
      final api = ref.read(kalinkaProxyProvider);
      await api.add([item.id]);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added "${item.name ?? 'item'}" to queue'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to add to queue: $e')));
      }
    }
  }
}

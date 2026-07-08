import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data_model/data_model.dart';
import '../../providers/kalinka_player_api_provider.dart';
import '../../providers/selection_state_provider.dart';
import '../../providers/source_modules_provider.dart';
import '../../providers/toast_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/haptics.dart';
import '../search_cards/browse_item_rows.dart';

/// Renders one query block's results as per-source section cards. Results are
/// never merged into a single ranked list — each backend section (a per-source
/// catalog) becomes its own bordered card, tinted to its source colour. The
/// rows are the shared search tiles ([BrowseItemRows]): per-type sizes,
/// hierarchical unrolling (album → tracks, artist → albums), and swipe to add
/// to queue / play next.
class StagingResultSections extends StatelessWidget {
  final BrowseItemsList results;
  final Set<String> expandedSections;
  final ValueChanged<String> onToggleSection;

  const StagingResultSections({
    super.key,
    required this.results,
    required this.expandedSections,
    required this.onToggleSection,
  });

  @override
  Widget build(BuildContext context) {
    final sections = results.items
        .where((s) => s.catalog != null && (s.sections?.isNotEmpty ?? false))
        .toList();

    if (sections.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Column(
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 40,
              color: KalinkaColors.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text('No matches', style: KalinkaTextStyles.cardTitle),
            const SizedBox(height: 4),
            Text(
              'Try rephrasing your request',
              style: KalinkaTextStyles.trackRowSubtitle,
            ),
          ],
        ),
      );
    }

    final children = <Widget>[];
    for (int i = 0; i < sections.length; i++) {
      if (i > 0) children.add(const SizedBox(height: 20));
      final section = sections[i];
      children.add(
        _SourceSectionCard(
          section: section,
          isExpanded: expandedSections.contains(section.id),
          onToggleExpand: () => onToggleSection(section.id),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

class _SourceSectionCard extends ConsumerWidget {
  final BrowseItem section;
  final bool isExpanded;
  final VoidCallback onToggleExpand;

  static const _defaultVisible = 5;

  const _SourceSectionCard({
    required this.section,
    required this.isExpanded,
    required this.onToggleExpand,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = section.sections ?? const <BrowseItem>[];
    final title = section.name ?? '';
    final tint = _sectionAccent(section);
    final icon = _sectionIcon(section.catalog?.previewConfig?.icon);
    final sourceLabel = _sourceLabel(ref, section);

    // Every track in the card, including any hidden behind "show more" — the
    // batch actions cover the whole set, not just the visible rows.
    final trackIds = <String>[
      for (final item in items)
        if (item.browseType == BrowseType.track) item.id,
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(
        color: tint == null ? KalinkaColors.surfaceRaised : null,
        gradient: tint == null
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: const [0.0, 0.55],
                colors: [
                  Color.alphaBlend(
                    tint.withValues(alpha: 0.10),
                    KalinkaColors.surfaceRaised,
                  ),
                  KalinkaColors.surfaceRaised,
                ],
              ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: tint == null
              ? KalinkaColors.borderSubtle
              : tint.withValues(alpha: 0.22),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: tint ?? KalinkaColors.accentTint),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.toUpperCase(),
                      style: KalinkaTextStyles.sectionLabel.copyWith(
                        color: tint ?? KalinkaColors.accentTint,
                      ),
                    ),
                    if (sourceLabel != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        sourceLabel,
                        style: KalinkaTextStyles.trackRowSubtitle,
                      ),
                    ],
                  ],
                ),
              ),
              // One-tap enqueue for the whole card; Select all routes the rest
              // (play now / play next) through the multi-select toolbar.
              if (trackIds.isNotEmpty) ...[
                _EnqueueAllButton(trackIds: trackIds),
                const SizedBox(width: 6),
                _SelectAllButton(trackIds: trackIds),
              ],
            ],
          ),
          const Divider(
            color: KalinkaColors.borderSubtle,
            thickness: 1,
            height: 16,
          ),
          // The shared search tiles: per-type sizes + hierarchical unrolling.
          BrowseItemRows(
            items: items,
            visibleLimit: _defaultVisible,
            isExpanded: isExpanded,
            onToggleExpand: onToggleExpand,
          ),
        ],
      ),
    );
  }
}

/// One-tap enqueue for every track in a card. Silent and non-destructive:
/// appends to the queue and reports via the shared activity toast, which is
/// captured up front so it survives the card scrolling away mid-request.
class _EnqueueAllButton extends ConsumerWidget {
  final List<String> trackIds;

  const _EnqueueAllButton({required this.trackIds});

  Future<void> _enqueue(WidgetRef ref) async {
    KalinkaHaptics.mediumImpact();
    final api = ref.read(kalinkaProxyProvider);
    final toast = ref.read(toastProvider.notifier);
    final n = trackIds.length;
    toast.beginQueueActivity('Adding $n track${n == 1 ? '' : 's'}…');
    try {
      await api.add(trackIds);
      toast.endQueueActivity('$n track${n == 1 ? '' : 's'} added to queue');
    } catch (e) {
      toast.endQueueActivity('Failed to add: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Semantics(
      label: 'Add all to queue',
      button: true,
      child: GestureDetector(
        onTap: () => _enqueue(ref),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: KalinkaColors.surfaceElevated,
            border: Border.all(color: KalinkaColors.borderDefault, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.playlist_add_rounded,
                size: 15,
                color: KalinkaColors.textPrimary,
              ),
              const SizedBox(width: 5),
              Text(
                'Add All',
                style: KalinkaFonts.sans(
                  fontSize: KalinkaTypography.baseSize + 1,
                  fontWeight: FontWeight.w600,
                  color: KalinkaColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Select / clear all of a card's tracks (including any hidden behind "show
/// more"), surfacing the multi-select toolbar for play now / play next / add.
class _SelectAllButton extends ConsumerWidget {
  final List<String> trackIds;

  const _SelectAllButton({required this.trackIds});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allSelected = ref.watch(
      selectionStateProvider.select(
        (s) => trackIds.every(s.selectedIds.contains),
      ),
    );
    return Semantics(
      label: allSelected ? 'Clear selection' : 'Select all tracks',
      button: true,
      child: GestureDetector(
        onTap: () {
          KalinkaHaptics.lightImpact();
          final notifier = ref.read(selectionStateProvider.notifier);
          if (allSelected) {
            notifier.deselectTracks(trackIds);
          } else {
            notifier.selectTracks(trackIds);
          }
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: allSelected
                ? KalinkaColors.accentSubtle
                : KalinkaColors.surfaceElevated,
            border: Border.all(
              color: allSelected
                  ? KalinkaColors.accentBorder
                  : KalinkaColors.borderDefault,
              width: 1,
            ),
          ),
          child: Text(
            allSelected ? 'Clear' : 'Select all',
            style: KalinkaFonts.sans(
              fontSize: KalinkaTypography.baseSize + 1,
              fontWeight: FontWeight.w600,
              color: allSelected
                  ? KalinkaColors.accentTint
                  : KalinkaColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Maps a backend section icon id to a concrete icon; unknown ids render none.
IconData? _sectionIcon(String? id) {
  switch (id) {
    case 'best_match':
      return Icons.star_rounded;
    case 'ai_suggestions':
      return Icons.auto_awesome;
    case 'album':
      return Icons.album_outlined;
    case 'artist':
      return Icons.person_outline;
    default:
      return null;
  }
}

/// Source-badge colour for a section, when it resolves to exactly one source.
Color? _sectionAccent(BrowseItem section) {
  final source = _singleSource(section);
  if (source == null || source.isEmpty) return null;
  return colorForSourceName(source);
}

/// Human-readable source label ("Qobuz", "Local library", …) for single-source
/// sections — this is what makes the per-source grouping explicit.
String? _sourceLabel(WidgetRef ref, BrowseItem section) {
  final source = _singleSource(section);
  if (source == null || source.isEmpty) return null;
  if (isLocalSource(source)) return 'Local library';
  final info = ref.watch(sourceDisplayInfoProvider)[source];
  return info?.title ?? source;
}

/// The single source a section belongs to, or null when cross-source /
/// unattributable. Prefers the catalog's declared sources, falling back to the
/// source segment of the section id.
String? _singleSource(BrowseItem section) {
  final sources = section.catalog?.sources ?? const <String>[];
  if (sources.length == 1) return sources.first;
  if (sources.isEmpty) {
    try {
      final idSource = EntityId.fromString(section.id).source;
      if (idSource.isNotEmpty && idSource != 'server') return idSource;
    } catch (_) {
      return null;
    }
  }
  return null;
}

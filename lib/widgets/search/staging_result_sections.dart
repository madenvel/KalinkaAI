import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data_model/data_model.dart';
import '../../providers/source_modules_provider.dart';
import '../../theme/app_theme.dart';
import '../search_cards/show_more_row.dart';
import 'staging_result_row.dart';

/// Renders one query block's results as per-source section cards. Results are
/// never merged into a single ranked list — each backend section (a per-source
/// catalog) becomes its own bordered card, tinted to its source colour. Rows
/// stage silently: add to queue / play next by swipe (see [StagingResultRow]).
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
      if (i > 0) children.add(const SizedBox(height: 12));
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

    final shown = isExpanded ? items : items.take(_defaultVisible).toList();
    final hiddenCount = items.length - shown.length;

    final rows = <Widget>[];
    for (int i = 0; i < shown.length; i++) {
      rows.add(StagingResultRow(item: shown[i]));
      if (i < shown.length - 1) {
        rows.add(const Divider(
          color: KalinkaColors.borderSubtle,
          thickness: 1,
          height: 14,
        ));
      }
    }
    if ((hiddenCount > 0 || isExpanded) && items.length > _defaultVisible) {
      rows.add(ShowMoreRow(
        remainingCount: items.length - _defaultVisible,
        isExpanded: isExpanded,
        onTap: onToggleExpand,
      ));
    }

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
            ],
          ),
          const Divider(
            color: KalinkaColors.borderSubtle,
            thickness: 1,
            height: 16,
          ),
          ...rows,
        ],
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

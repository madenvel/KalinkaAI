import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data_model/data_model.dart';
import '../../providers/kalinka_player_api_provider.dart';
import '../../providers/source_modules_provider.dart';
import '../../providers/toast_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/haptics.dart';
import '../search_cards/show_more_row.dart';
import 'staging_result_row.dart';

/// Renders one query block's results as per-source section cards. Results are
/// never merged into a single ranked list — each backend section (a per-source
/// catalog) becomes its own bordered card, tinted to its source colour.
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

class _SourceSectionCard extends ConsumerStatefulWidget {
  final BrowseItem section;
  final bool isExpanded;
  final VoidCallback onToggleExpand;

  const _SourceSectionCard({
    required this.section,
    required this.isExpanded,
    required this.onToggleExpand,
  });

  @override
  ConsumerState<_SourceSectionCard> createState() => _SourceSectionCardState();
}

class _SourceSectionCardState extends ConsumerState<_SourceSectionCard> {
  static const _defaultVisible = 5;

  Future<void> _addAll(List<String> trackIds) async {
    if (trackIds.isEmpty) return;
    KalinkaHaptics.mediumImpact();
    final api = ref.read(kalinkaProxyProvider);
    await runQueueActivity(
      pending: 'Adding ${trackIds.length} tracks…',
      action: () => api.add(trackIds),
      done: (_) => '${trackIds.length} tracks added to queue',
      failed: (e) => 'Failed to add: $e',
    );
  }

  @override
  Widget build(BuildContext context) {
    final section = widget.section;
    final items = section.sections ?? const <BrowseItem>[];
    final title = section.name ?? '';
    final tint = _sectionAccent(section);
    final icon = _sectionIcon(section.catalog?.previewConfig?.icon);
    final sourceLabel = _sourceLabel(ref, section);

    final trackIds = <String>[
      for (final item in items)
        if (item.browseType == BrowseType.track) item.id,
    ];

    final shown = widget.isExpanded
        ? items
        : items.take(_defaultVisible).toList();
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
    if (hiddenCount > 0 || widget.isExpanded) {
      if (items.length > _defaultVisible) {
        rows.add(ShowMoreRow(
          remainingCount: items.length - _defaultVisible,
          isExpanded: widget.isExpanded,
          onTap: widget.onToggleExpand,
        ));
      }
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
              if (trackIds.isNotEmpty)
                _AddAllButton(onTap: () => _addAll(trackIds)),
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

class _AddAllButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddAllButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Add all to queue',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                'Add all',
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

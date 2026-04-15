import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data_model/data_model.dart';
import '../../providers/search_state_provider.dart';
import '../../theme/app_theme.dart';

/// Type-based filter chip row for search results.
/// Shows: All | Artists | Albums | Tracks | Playlists.
/// Only chips with >0 results are shown.
class ResultsFilterChipRow extends StatelessWidget {
  final ResultsFilterType activeFilter;
  final Map<SearchType, int> counts;
  final ValueChanged<ResultsFilterType> onFilterChanged;

  const ResultsFilterChipRow({
    super.key,
    required this.activeFilter,
    required this.counts,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: KalinkaColors.surfaceBase,
        border: Border(bottom: BorderSide(color: Color(0x1AFFFFFF), width: 1)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 0, 10),
      child: Row(
        children: [
          // "All" pill — pinned
          _Chip(
            label: 'All',
            isActive: activeFilter == ResultsFilterType.all,
            onTap: () => onFilterChanged(ResultsFilterType.all),
          ),

          // Vertical divider
          Container(
            width: 1,
            height: 16,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: const Color(0x1AFFFFFF),
          ),

          // Scrollable type chips
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  if ((counts[SearchType.artist] ?? 0) > 0) ...[
                    _Chip(
                      label: 'Artists',
                      isActive: activeFilter == ResultsFilterType.artists,
                      onTap: () =>
                          onFilterChanged(ResultsFilterType.artists),
                    ),
                    const SizedBox(width: 6),
                  ],
                  if ((counts[SearchType.album] ?? 0) > 0) ...[
                    _Chip(
                      label: 'Albums',
                      isActive: activeFilter == ResultsFilterType.albums,
                      onTap: () =>
                          onFilterChanged(ResultsFilterType.albums),
                    ),
                    const SizedBox(width: 6),
                  ],
                  if ((counts[SearchType.track] ?? 0) > 0) ...[
                    _Chip(
                      label: 'Tracks',
                      isActive: activeFilter == ResultsFilterType.tracks,
                      onTap: () =>
                          onFilterChanged(ResultsFilterType.tracks),
                    ),
                    const SizedBox(width: 6),
                  ],
                  if ((counts[SearchType.playlist] ?? 0) > 0) ...[
                    _Chip(
                      label: 'Playlists',
                      isActive: activeFilter == ResultsFilterType.playlists,
                      onTap: () =>
                          onFilterChanged(ResultsFilterType.playlists),
                    ),
                  ],
                  const SizedBox(width: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isActive ? KalinkaColors.accentFaded : KalinkaColors.surfaceRaised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isActive ? KalinkaColors.accent : const Color(0x17FFFFFF),
          width: 0.1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) {
            return Colors.white.withValues(alpha: 0.08);
          }
          return null;
        }),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            label,
            style: isActive
                ? KalinkaTextStyles.filterPillActive
                : KalinkaTextStyles.filterPillInactive,
          ),
        ),
      ),
    );
  }
}

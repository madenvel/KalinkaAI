import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data_model/browse_filters.dart';
import '../../data_model/data_model.dart' show Genre;
import '../../providers/browse_genres_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/haptics.dart';
import 'browse_filter_form.dart';

/// One removable chip per active answer, shown above the rows.
///
/// This is what makes folding the controls away safe: the list is never
/// quietly filtered. Renders nothing when no filter is set.
class ActiveFilterChips extends ConsumerWidget {
  final BrowseFilterCapabilities capabilities;
  final BrowseFilterQuery query;
  final ValueChanged<BrowseFilterQuery> onChanged;

  final EdgeInsets padding;

  const ActiveFilterChips({
    super.key,
    required this.capabilities,
    required this.query,
    required this.onChanged,
    this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 12),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (query.isEmpty) return const SizedBox.shrink();

    // Only reached with genres applied, which needs the capability anyway.
    final genres = query.genreIds.isEmpty
        ? null
        : ref.watch(browseGenresProvider(capabilities.genreSource ?? '')).value;

    final chips = <Widget>[
      if (query.type != null)
        _Chip(
          label: filterTypeLabel(query.type!),
          onRemove: () => onChanged(query.copyWith(clearType: true)),
        ),
      if (query.text.isNotEmpty)
        _Chip(
          label: '“${query.text}”',
          onRemove: () => onChanged(query.copyWith(text: '')),
        ),
      for (final id in query.genreIds)
        _Chip(
          label: _genreName(genres, id),
          onRemove: () => onChanged(
            query.copyWith(
              genreIds: [...query.genreIds.where((other) => other != id)],
            ),
          ),
        ),
    ];

    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Wrap(spacing: 8, runSpacing: 8, children: chips)),
          // Dropping four filters one X at a time is four reloads; this is
          // one. Only worth its space once there is more than one to drop.
          if (chips.length > 1) ...[
            const SizedBox(width: 10),
            _ResetAll(onTap: () => onChanged(const BrowseFilterQuery())),
          ],
        ],
      ),
    );
  }

  /// Falls back to the raw id if the taxonomy has not landed — a chip with an
  /// ugly label still beats a filter with no chip.
  static String _genreName(List<Genre>? genres, String id) {
    if (genres == null) return id;
    for (final genre in genres) {
      if (genre.id == id) return genre.name;
    }
    return id;
  }
}

/// One applied filter. Crimson-tinted like a selected pill in the overlay,
/// and white-labelled for the same reason: the fill says it is on.
class _Chip extends StatefulWidget {
  final String label;
  final VoidCallback onRemove;

  const _Chip({required this.label, required this.onRemove});

  @override
  State<_Chip> createState() => _ChipState();
}

class _ChipState extends State<_Chip> {
  bool _hovering = false;

  void _setHovering(bool value) {
    if (value == _hovering) return;
    setState(() => _hovering = value);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Remove filter ${widget.label}',
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => _setHovering(true),
        onExit: (_) => _setHovering(false),
        child: GestureDetector(
          onTap: () {
            KalinkaHaptics.selectionClick();
            widget.onRemove();
          },
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 130),
            curve: Curves.easeOut,
            height: 34,
            padding: const EdgeInsets.only(left: 14, right: 10),
            decoration: BoxDecoration(
              color: _hovering
                  ? KalinkaColors.accent.withValues(alpha: 0.22)
                  : KalinkaColors.accentSubtle,
              borderRadius: BorderRadius.circular(17),
              border: Border.all(
                color: _hovering
                    ? KalinkaColors.accentTint
                    : KalinkaColors.accentBorder,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.label,
                  style: KalinkaFonts.sans(
                    fontSize: KalinkaTypography.baseSize + 1,
                    fontWeight: FontWeight.w500,
                    color: KalinkaColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.close_rounded,
                  size: 15,
                  color: _hovering
                      ? KalinkaColors.textPrimary
                      : KalinkaColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Clears every active filter at once. Mono and unfilled, so it reads as the
/// row's action rather than a fifth chip — and neutral, because crimson here
/// would compete with the chips it is meant to sit beside.
class _ResetAll extends StatefulWidget {
  final VoidCallback onTap;

  const _ResetAll({required this.onTap});

  @override
  State<_ResetAll> createState() => _ResetAllState();
}

class _ResetAllState extends State<_ResetAll> {
  bool _hovering = false;

  void _setHovering(bool value) {
    if (value == _hovering) return;
    setState(() => _hovering = value);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Reset all filters',
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => _setHovering(true),
        onExit: (_) => _setHovering(false),
        child: GestureDetector(
          onTap: () {
            KalinkaHaptics.selectionClick();
            widget.onTap();
          },
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            // Matches a chip so the label sits on the first row's centre line.
            height: 34,
            child: Center(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 130),
                curve: Curves.easeOut,
                style: KalinkaFonts.mono(
                  fontSize: KalinkaTypography.baseSize,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.4,
                  color: _hovering
                      ? KalinkaColors.textPrimary
                      : KalinkaColors.textSecondary,
                ),
                child: const Text('RESET ALL'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

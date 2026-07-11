import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data_model/data_model.dart';
import '../../providers/kalinka_player_api_provider.dart';
import '../../providers/selection_state_provider.dart';
import '../../providers/source_modules_provider.dart';
import '../../providers/toast_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/haptics.dart';
import '../search_cards/action_icon_chip.dart';
import '../search_cards/browse_item_rows.dart';

/// Renders one query block's results as per-source sections. Results are
/// never merged into a single ranked list — each backend section (a per-source
/// catalog) becomes its own flat section (no card chrome), its heading tinted
/// to its source colour. The rows are the shared search tiles ([BrowseItemRows]):
/// per-type sizes, hierarchical unrolling (album → tracks, artist → albums),
/// and swipe to add to queue / play next.
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
      // The only divider on the results is between sections — rows within a
      // section stack cleanly, no rules between them.
      if (i > 0) {
        children.add(
          const Divider(
            color: KalinkaColors.borderSubtle,
            thickness: 1,
            height: 32,
          ),
        );
      }
      final section = sections[i];
      children.add(
        _SourceSection(
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

class _SourceSection extends ConsumerWidget {
  final BrowseItem section;
  final bool isExpanded;
  final VoidCallback onToggleExpand;

  static const _defaultVisible = 5;

  const _SourceSection({
    required this.section,
    required this.isExpanded,
    required this.onToggleExpand,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = section.sections ?? const <BrowseItem>[];
    final tint = _sectionAccent(section);
    final icon = _sectionIcon(section.catalog?.previewConfig?.icon);
    final sourceLabel = _sourceLabel(ref, section);
    // The source shows on its own line below, so strip a trailing "· Qobuz"
    // the backend appended to the section name rather than repeat it.
    final title = _displayTitle(section, sourceLabel);

    // Every track in the section, including any hidden behind "show more" — the
    // batch actions cover the whole set, not just the visible rows.
    final trackIds = <String>[
      for (final item in items)
        if (item.browseType == BrowseType.track) item.id,
    ];
    final selectionMode = ref.watch(
      selectionStateProvider.select((s) => s.isActive),
    );

    // No card chrome: a flat section is a tinted heading, a hairline rule, then
    // the rows — the source colour still signals grouping via the title.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 24, color: tint ?? KalinkaColors.textPrimary),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.toUpperCase(),
                    // Source badge colour; bright neutral (never accent) when
                    // cross-source.
                    style: KalinkaTextStyles.sectionLabel.copyWith(
                      color: tint ?? KalinkaColors.textPrimary,
                    ),
                  ),
                  if (sourceLabel != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      sourceLabel,
                      style: KalinkaTextStyles.trackRowSubtitle.copyWith(
                        color: KalinkaColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Section-wide actions as icon chips: play-all replaces the queue
            // with this section's tracks, add-all appends without touching
            // playback. In multi-select mode they give way to Select all.
            // Album/artist sections have no trackIds, so nothing shows here.
            if (trackIds.isNotEmpty && selectionMode) ...[
              _SelectAllButton(trackIds: trackIds),
            ],
            if (trackIds.isNotEmpty && !selectionMode) ...[
              _PlayAllChip(trackIds: trackIds),
              const SizedBox(width: 8),
              _AddAllChip(trackIds: trackIds),

              // Lands the 32px chip on the chevrons' 8px right-edge inset.
            ],
            const SizedBox(width: 2),
          ],
        ),
        const SizedBox(height: 10),
        // The shared search tiles: per-type sizes + hierarchical unrolling. No
        // dividers between rows — the section divider is the only rule.
        BrowseItemRows(
          items: items,
          visibleLimit: _defaultVisible,
          isExpanded: isExpanded,
          onToggleExpand: onToggleExpand,
          dividers: false,
          // Tapping a loose track plays the whole section from that track —
          // the section becomes the queue, giving it a coherent identity.
          queueContextIds: trackIds,
        ),
      ],
    );
  }
}

/// Play a whole section now: its tracks become the queue, starting from the
/// first. The berry tint marks it as the default action; the additive
/// add-all chip beside it stays neutral.
class _PlayAllChip extends ConsumerStatefulWidget {
  final List<String> trackIds;

  const _PlayAllChip({required this.trackIds});

  @override
  ConsumerState<_PlayAllChip> createState() => _PlayAllChipState();
}

class _PlayAllChipState extends ConsumerState<_PlayAllChip> {
  bool _busy = false;

  Future<void> _playAll() async {
    if (_busy) return;
    setState(() => _busy = true);
    KalinkaHaptics.mediumImpact();
    final api = ref.read(kalinkaProxyProvider);
    final n = widget.trackIds.length;
    await runQueueActivity(
      pending: 'Starting playback…',
      action: () async {
        await api.clear();
        await api.add(widget.trackIds);
        await api.play(0);
      },
      done: (_) => 'Playing $n track${n == 1 ? '' : 's'}',
      failed: (e) => 'Failed to play: $e',
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return ActionIconChip(
      icon: Icons.play_arrow_rounded,
      accent: true,
      enabled: !_busy,
      onTap: _playAll,
      semanticsLabel: 'Play all tracks in this section',
    );
  }
}

/// Enqueue every track in a section, reporting via the shared activity toast.
/// Idle → busy (request in flight) → added (3s confirmation) → idle.
enum _AddStatus { idle, busy, added }

class _AddAllChip extends ConsumerStatefulWidget {
  final List<String> trackIds;

  const _AddAllChip({required this.trackIds});

  @override
  ConsumerState<_AddAllChip> createState() => _AddAllChipState();
}

class _AddAllChipState extends ConsumerState<_AddAllChip> {
  _AddStatus _status = _AddStatus.idle;
  Timer? _resetTimer;

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  Future<void> _enqueue() async {
    if (_status != _AddStatus.idle) return;
    // Busy (disabled) while the request is in flight — the "Added ✓"
    // confirmation only appears once the add actually succeeds.
    setState(() => _status = _AddStatus.busy);
    KalinkaHaptics.mediumImpact();
    final api = ref.read(kalinkaProxyProvider);
    final toast = ref.read(toastProvider.notifier);
    final n = widget.trackIds.length;
    toast.beginQueueActivity('Adding $n track${n == 1 ? '' : 's'}…');
    try {
      await api.add(widget.trackIds);
      toast.endQueueActivity('$n track${n == 1 ? '' : 's'} added to queue');
      if (!mounted) return;
      setState(() => _status = _AddStatus.added);
      _resetTimer?.cancel();
      _resetTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _status = _AddStatus.idle);
      });
    } catch (e) {
      // Failed — back to idle so they can retry immediately.
      if (mounted) setState(() => _status = _AddStatus.idle);
      toast.endQueueActivity('Failed to add: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final added = _status == _AddStatus.added;
    return ActionIconChip(
      icon: added ? Icons.check_rounded : Icons.playlist_add_rounded,
      // Enabled only when idle — no re-add while adding or confirming.
      enabled: _status == _AddStatus.idle,
      onTap: _enqueue,
      iconOverride: added ? KalinkaColors.gold : null,
      borderOverride: added ? KalinkaColors.gold.withValues(alpha: 0.4) : null,
      semanticsLabel: added
          ? 'Added to queue'
          : _status == _AddStatus.busy
          ? 'Adding to queue'
          : 'Add all to queue',
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
        // Same 44px slot as the Play all / Add all chips it replaces, so the
        // header height doesn't jump when selection mode toggles.
        child: SizedBox(
          height: 44,
          child: Center(
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

/// The section's display title with a trailing source suffix stripped. The
/// backend names sections like "Best match · Qobuz", but the source is already
/// shown on its own line ([_sourceLabel]), so repeating it in the title reads
/// as noise. Drops a trailing separator (· • | / – — -) followed by the source
/// label or its raw id (case-insensitive); a no-op when nothing matches.
String _displayTitle(BrowseItem section, String? sourceLabel) {
  var title = section.name ?? '';
  for (final token in <String?>[sourceLabel, _singleSource(section)]) {
    if (token == null || token.isEmpty) continue;
    final pattern = RegExp(
      r'\s*[·•|/–—-]+\s*' + RegExp.escape(token) + r'\s*$',
      caseSensitive: false,
    );
    final stripped = title.replaceFirst(pattern, '').trim();
    if (stripped.isNotEmpty) title = stripped;
  }
  return title;
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

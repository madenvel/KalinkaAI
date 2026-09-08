import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data_model/data_model.dart';
import '../../providers/catalog_cards_provider.dart';
import '../../providers/kalinka_player_api_provider.dart';
import '../../providers/row_expansion_provider.dart';
import '../../providers/search_session_provider.dart';
import '../../providers/selection_state_provider.dart';
import '../../providers/toast_provider.dart';
import '../../providers/url_resolver.dart';
import '../../theme/app_theme.dart';
import '../../utils/click_cursor.dart';
import '../../utils/haptics.dart';
import '../collection_art_tile.dart';
import '../search/collection_name_sheet.dart';
import '../source_badge.dart';
import 'action_pill_button.dart';
import 'expand_chevron_button.dart';
import 'expanded_track_list.dart';
import 'long_press_ring_painter.dart';
import 'track_row_support.dart';

/// A collection on the Collections screen: its cover, what it holds, and its
/// tracks when it is unrolled. A collection is never a screen of its own —
/// the listing is where you look at one and where you will edit it — so this
/// row opens downwards like any other container.
///
/// Long-press takes it into the selection, as every other container row does.
class CollectionRow extends ConsumerStatefulWidget {
  final BrowseItem item;

  const CollectionRow({super.key, required this.item});

  @override
  ConsumerState<CollectionRow> createState() => _CollectionRowState();
}

class _CollectionRowState extends ConsumerState<CollectionRow>
    with SingleTickerProviderStateMixin, LongPressRingMixin {
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    _glow.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _greetIfFocused());
  }

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  /// Brings the row the screen was opened on into view and marks it, so the
  /// jump from a Discover card reads as having landed somewhere. The focus is
  /// spent here: it is an instruction for the arrival, not a page state.
  void _greetIfFocused() {
    if (!mounted) return;
    final session = ref.read(searchSessionProvider.notifier);
    if (ref.read(searchSessionProvider).catalogPage.focusItemId !=
        widget.item.id) {
      return;
    }
    session.catalogFocusReached();
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOut,
      alignment: 0.1,
    );
    if (!MediaQuery.of(context).disableAnimations) _glow.forward(from: 0);
  }

  void _toggle() {
    KalinkaHaptics.lightImpact();
    ref.read(rowExpansionProvider.notifier).toggleUnrolled(widget.item.id);
  }

  void _select() =>
      ref.read(selectionStateProvider.notifier).toggleContainer(widget.item.id);

  @override
  Widget build(BuildContext context) {
    final expanded = ref.watch(
      rowExpansionProvider.select((s) => s.unrolled.contains(widget.item.id)),
    );
    // Scoped watches so unrelated selection changes don't rebuild the row.
    final selecting = ref.watch(
      selectionStateProvider.select((s) => s.isActive),
    );
    final selected = ref.watch(
      selectionStateProvider.select(
        (s) => s.isContainerSelected(widget.item.id),
      ),
    );
    final partial = ref.watch(
      selectionStateProvider.select(
        (s) => s.isContainerPartial(widget.item.id),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CollectionFace(
          item: widget.item,
          raised: expanded,
          glow: _glow.isAnimating ? 1 - _glow.value : 0,
          selected: selected,
          partial: partial,
          pressProgress: longPressing ? longPressProgress : 0,
          onTap: selecting ? _select : _toggle,
          onSelectPressStart: selecting
              ? null
              : () => startLongPressRing(_select),
          onSelectPressStop: selecting ? null : cancelLongPressRing,
          trailing: ExpandChevronButton(isExpanded: expanded, onTap: _toggle),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: expanded
              ? Container(
                  margin: const EdgeInsets.only(left: 16),
                  decoration: const BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: KalinkaColors.borderSubtle,
                        width: 1,
                      ),
                    ),
                  ),
                  child: ExpandedContainerTracks(
                    item: widget.item,
                    emptyLabel: 'Nothing in this collection yet',
                    headerAction: widget.item.canEdit
                        ? _RenameButton(item: widget.item)
                        : null,
                  ),
                )
              : const SizedBox.shrink(),
          crossFadeState: expanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
          firstCurve: Curves.easeOut,
          secondCurve: Curves.easeOut,
          sizeCurve: Curves.easeOut,
        ),
      ],
    );
  }
}

/// Renames the collection its header belongs to. It sits apart from Play all
/// and Enqueue because it acts on the list rather than on its music.
class _RenameButton extends ConsumerWidget {
  final BrowseItem item;

  const _RenameButton({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ActionPillButton(
      icon: Icons.edit_rounded,
      semanticsLabel:
          'Rename ${item.playlist?.name ?? item.name ?? 'this collection'}',
      onTap: () => showRenameCollectionSheet(context, ref, item),
    );
  }
}

/// A collection on the Discover root: a shortcut, not a row that opens here.
/// Tapping it goes to the Collections screen and lands on this collection;
/// the play button starts it without going anywhere.
class CollectionShelfRow extends ConsumerStatefulWidget {
  final BrowseItem item;

  /// Opens the Collections screen on this collection.
  final VoidCallback onOpen;

  const CollectionShelfRow({
    super.key,
    required this.item,
    required this.onOpen,
  });

  @override
  ConsumerState<CollectionShelfRow> createState() => _CollectionShelfRowState();
}

class _CollectionShelfRowState extends ConsumerState<CollectionShelfRow> {
  bool _starting = false;

  Future<void> _play() async {
    if (_starting) return;
    setState(() => _starting = true);
    KalinkaHaptics.mediumImpact();
    final api = ref.read(kalinkaProxyProvider);
    await runQueueActivity(
      pending: 'Starting playback…',
      action: () async {
        await api.clear();
        final added = await api.add([widget.item.id]);
        await api.play(0);
        return added;
      },
      done: (r) {
        final n = r.count ?? widget.item.playlist?.trackCount ?? 0;
        return 'Playing $_name — $n ${n == 1 ? 'track' : 'tracks'}';
      },
      failed: (e) => 'Failed to play: $e',
    );
    if (mounted) setState(() => _starting = false);
  }

  @override
  Widget build(BuildContext context) {
    final empty = (widget.item.playlist?.trackCount ?? 0) == 0;

    return CollectionFace(
      item: widget.item,
      onTap: () {
        KalinkaHaptics.lightImpact();
        widget.onOpen();
      },
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Nothing to start when there is nothing in it.
          if (!empty)
            _PlayCircleButton(busy: _starting, onTap: _play, name: _name),
          const Icon(
            Icons.chevron_right_rounded,
            size: 24,
            color: KalinkaColors.textMuted,
          ),
        ],
      ),
    );
  }

  String get _name =>
      widget.item.playlist?.name ?? widget.item.name ?? 'collection';
}

/// The look of a collection wherever it is listed: cover, name, the sources
/// it draws on and the line that says what it holds. Only what sits at its
/// right end and what a gesture does differ between the two places one
/// appears.
class CollectionFace extends ConsumerWidget {
  final BrowseItem item;
  final Widget trailing;
  final VoidCallback onTap;

  /// Drawn as an unrolled row — raised ground, crimson edge.
  final bool raised;

  /// Strength of the arrival mark, 0 when the row was not jumped to.
  final double glow;

  /// Drawn as taken by the selection, and [partial] where some of its tracks
  /// have since been dropped from it.
  final bool selected;
  final bool partial;

  /// How far the long press that would select it has run, 0 when none is.
  final double pressProgress;

  /// Begins and abandons that press. Null where the row cannot be selected.
  final VoidCallback? onSelectPressStart;
  final VoidCallback? onSelectPressStop;

  const CollectionFace({
    super.key,
    required this.item,
    required this.trailing,
    required this.onTap,
    this.raised = false,
    this.glow = 0,
    this.selected = false,
    this.partial = false,
    this.pressProgress = 0,
    this.onSelectPressStart,
    this.onSelectPressStop,
  });

  static const _thumb = 64.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlist = item.playlist;
    final title = playlist?.name ?? item.name ?? 'Unknown';
    final artPath = artPathOf(item);
    final marked = raised || glow > 0 || selected;
    final sources = item.catalog?.sources ?? const <String>[];

    return Semantics(
      button: true,
      label: title,
      child: GestureDetector(
        onTap: onTap,
        onLongPressStart: onSelectPressStart == null
            ? null
            : (_) => onSelectPressStart!(),
        onLongPressEnd: onSelectPressStop == null
            ? null
            : (_) => onSelectPressStop!(),
        onLongPressCancel: onSelectPressStop,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          // The 3px the edge takes comes out of the inset, so unrolling does
          // not nudge the row sideways.
          padding: EdgeInsets.only(top: 10, bottom: 10, left: marked ? 0 : 3),
          decoration: BoxDecoration(
            color: selected
                ? KalinkaColors.accent.withValues(alpha: 0.07)
                : Color.lerp(
                    raised ? KalinkaColors.surfaceRaised : Colors.transparent,
                    KalinkaColors.accent.withValues(alpha: 0.18),
                    glow,
                  ),
            border: marked
                ? Border(
                    left: BorderSide(
                      color: selected
                          ? KalinkaColors.accent
                          : KalinkaColors.accent.withValues(
                              alpha: 0.40 + 0.6 * glow,
                            ),
                      width: 3,
                    ),
                  )
                : null,
          ),
          child: Row(
            children: [
              SizedBox(
                width: _thumb,
                height: _thumb,
                child: Stack(
                  children: [
                    CollectionCover(
                      artUrl: artPath == null
                          ? null
                          : ref.read(urlResolverProvider).abs(artPath),
                      trackCount: playlist?.trackCount,
                      seed: item.id,
                      size: _thumb,
                      radius: 10,
                    ),
                    if (pressProgress > 0)
                      Positioned.fill(
                        child: CustomPaint(
                          painter: LongPressRingPainter(
                            progress: pressProgress,
                            color: KalinkaColors.accent,
                          ),
                        ),
                      ),
                    if (selected)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: KalinkaColors.accent.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            partial ? Icons.remove : Icons.check,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: KalinkaTextStyles.listName.copyWith(
                        color: selected ? KalinkaColors.accentTint : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        for (final source in sources) ...[
                          SourceLetter(source: source, size: 18),
                          const SizedBox(width: 5),
                        ],
                        Expanded(
                          child: Text(
                            collectionSummary(item),
                            style: KalinkaTextStyles.trackRowSubtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

/// What a collection holds, in one line: how many tracks and how long it
/// runs. Which sources they came from is said beside it, in their own
/// colours. An empty collection says so instead of counting to zero.
String collectionSummary(BrowseItem item) {
  final count = item.playlist?.trackCount;
  if (count == 0) return 'Empty collection';
  final duration = item.playlist?.duration;
  return [
    if (count != null) '$count ${count == 1 ? 'track' : 'tracks'}',
    if (duration != null && duration > 0) formatTotalDuration(duration),
  ].join(' · ');
}

/// The one live action on a Discover collection card. Hover warms the circle
/// so it reads as its own control rather than as part of the row it sits on.
class _PlayCircleButton extends StatefulWidget {
  final bool busy;
  final VoidCallback onTap;
  final String name;

  const _PlayCircleButton({
    required this.busy,
    required this.onTap,
    required this.name,
  });

  @override
  State<_PlayCircleButton> createState() => _PlayCircleButtonState();
}

class _PlayCircleButtonState extends State<_PlayCircleButton> {
  bool _hovering = false;

  void _setHover(bool value) {
    if (value == _hovering) return;
    setState(() => _hovering = value);
  }

  @override
  Widget build(BuildContext context) {
    final hot = _hovering && !widget.busy;

    return Semantics(
      button: true,
      label: 'Play ${widget.name}',
      child: MouseRegion(
        cursor: clickCursor(interactive: !widget.busy),
        onEnter: (_) => _setHover(true),
        onExit: (_) => _setHover(false),
        child: GestureDetector(
          onTap: widget.busy ? null : widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hot
                      ? KalinkaColors.accentBorder
                      : KalinkaColors.accentSubtle,
                  border: Border.all(
                    color: hot
                        ? KalinkaColors.accent
                        : KalinkaColors.accentBorder,
                  ),
                ),
                child: Icon(
                  widget.busy
                      ? Icons.hourglass_empty_rounded
                      : Icons.play_arrow_rounded,
                  size: 18,
                  color: KalinkaColors.accentTint,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

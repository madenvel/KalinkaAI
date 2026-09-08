import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data_model/data_model.dart';
import '../../providers/catalog_cards_provider.dart';
import '../../providers/kalinka_player_api_provider.dart';
import '../../providers/row_expansion_provider.dart';
import '../../providers/search_session_provider.dart';
import '../../providers/toast_provider.dart';
import '../../providers/url_resolver.dart';
import '../../theme/app_theme.dart';
import '../../utils/haptics.dart';
import '../collection_art_tile.dart';
import 'expand_chevron_button.dart';
import 'expanded_track_list.dart';
import 'track_row_support.dart';

/// A collection on the Collections screen: its cover, what it holds, and its
/// tracks when it is unrolled. A collection is never a screen of its own —
/// the listing is where you look at one and where you will edit it — so this
/// row opens downwards like any other container.
class CollectionRow extends ConsumerStatefulWidget {
  final BrowseItem item;

  const CollectionRow({super.key, required this.item});

  @override
  ConsumerState<CollectionRow> createState() => _CollectionRowState();
}

class _CollectionRowState extends ConsumerState<CollectionRow>
    with SingleTickerProviderStateMixin {
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

  @override
  Widget build(BuildContext context) {
    final expanded = ref.watch(
      rowExpansionProvider.select((s) => s.unrolled.contains(widget.item.id)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CollectionFace(
          item: widget.item,
          raised: expanded,
          glow: _glow.isAnimating ? 1 - _glow.value : 0,
          onTap: _toggle,
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

/// The look of a collection wherever it is listed: cover, name, and the line
/// that says what it holds. Only what sits at its right end and what a tap
/// does differ between the two places one appears.
class CollectionFace extends ConsumerWidget {
  final BrowseItem item;
  final Widget trailing;
  final VoidCallback onTap;

  /// Drawn as an unrolled row — raised ground, crimson edge.
  final bool raised;

  /// Strength of the arrival mark, 0 when the row was not jumped to.
  final double glow;

  const CollectionFace({
    super.key,
    required this.item,
    required this.trailing,
    required this.onTap,
    this.raised = false,
    this.glow = 0,
  });

  static const _thumb = 64.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlist = item.playlist;
    final title = playlist?.name ?? item.name ?? 'Unknown';
    final artPath = artPathOf(item);
    final marked = raised || glow > 0;

    return Semantics(
      button: true,
      label: title,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          // The 3px the edge takes comes out of the inset, so unrolling does
          // not nudge the row sideways.
          padding: EdgeInsets.only(top: 10, bottom: 10, left: marked ? 0 : 3),
          decoration: BoxDecoration(
            color: Color.lerp(
              raised ? KalinkaColors.surfaceRaised : Colors.transparent,
              KalinkaColors.accent.withValues(alpha: 0.18),
              glow,
            ),
            border: marked
                ? Border(
                    left: BorderSide(
                      color: KalinkaColors.accent.withValues(
                        alpha: 0.40 + 0.6 * glow,
                      ),
                      width: 3,
                    ),
                  )
                : null,
          ),
          child: Row(
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
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: KalinkaTextStyles.listName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      collectionSummary(item),
                      style: KalinkaTextStyles.trackRowSubtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

/// What a collection holds, in one line: how many tracks, how many sources
/// they came from, how long it runs. Each part appears only where the server
/// knew it; an empty collection says so instead of counting to zero.
String collectionSummary(BrowseItem item) {
  final count = item.playlist?.trackCount;
  if (count == 0) return 'Empty collection';
  final sources = item.catalog?.sources ?? const [];
  final duration = item.playlist?.duration;
  return [
    if (count != null) '$count ${count == 1 ? 'track' : 'tracks'}',
    if (sources.isNotEmpty)
      '${sources.length} ${sources.length == 1 ? 'source' : 'sources'}',
    if (duration != null && duration > 0) formatTotalDuration(duration),
  ].join(' · ');
}

/// The one live action on a Discover collection card.
class _PlayCircleButton extends StatelessWidget {
  final bool busy;
  final VoidCallback onTap;
  final String name;

  const _PlayCircleButton({
    required this.busy,
    required this.onTap,
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Play $name',
      child: GestureDetector(
        onTap: busy ? null : onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: KalinkaColors.accentSubtle,
                border: Border.all(color: KalinkaColors.accentBorder),
              ),
              child: Icon(
                busy ? Icons.hourglass_empty_rounded : Icons.play_arrow_rounded,
                size: 18,
                color: KalinkaColors.accentTint,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

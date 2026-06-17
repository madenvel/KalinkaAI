import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data_model/data_model.dart';
import '../../providers/app_state_provider.dart';
import '../../providers/kalinka_player_api_provider.dart';
import '../../providers/selection_state_provider.dart';
import '../../providers/toast_provider.dart';
import '../../providers/url_resolver.dart';
import '../../providers/source_modules_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/play_next.dart';
import '../procedural_album_art.dart';
import '../source_badge.dart';
import '../swipe_to_act_row.dart';
import '../track_tile_layout.dart';
import 'long_press_ring_painter.dart';

/// Track row for search results.
/// ~60px height, 44x44 thumbnail, title/artist/duration.
/// Tap row = play now (replaces queue).
/// Swipe right = add to queue / play next.
/// Long-press row = enter multi-select.
class SearchTrackRow extends ConsumerStatefulWidget {
  final BrowseItem item;

  const SearchTrackRow({super.key, required this.item});

  @override
  ConsumerState<SearchTrackRow> createState() => _SearchTrackRowState();
}

class _SearchTrackRowState extends ConsumerState<SearchTrackRow>
    with SingleTickerProviderStateMixin {
  // Long-press ring animation (row long-press → multi-select)
  bool _longPressing = false;
  double _longPressProgress = 0.0;
  Timer? _longPressTimer;

  // ── Play-on-tap flash animation ──────────────────────────────────────────
  late final AnimationController _flashController;
  late final Animation<Color?> _flashColorAnim;
  bool _tappedToPlay = false;

  @override
  void initState() {
    super.initState();
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _flashColorAnim = TweenSequence<Color?>([
      TweenSequenceItem(
        tween: ColorTween(
          begin: Colors.transparent,
          end: KalinkaColors.accent.withValues(alpha: 0.15),
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: ColorTween(
          begin: KalinkaColors.accent.withValues(alpha: 0.15),
          end: KalinkaColors.accentSubtle,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 2,
      ),
    ]).animate(_flashController);
  }

  @override
  void dispose() {
    _flashController.dispose();
    _longPressTimer?.cancel();
    super.dispose();
  }

  Future<void> _playTrack() async {
    // Start flash animation immediately on tap, before the async API call.
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    setState(() => _tappedToPlay = true);
    if (!reduceMotion) _flashController.forward(from: 0.0);

    final api = ref.read(kalinkaProxyProvider);
    try {
      await api.clear();
      await api.add([widget.item.id]);
      // Explicit index 0 avoids a backend race where a stale FINISHED event
      // from the just-cleared stream advances current_track_id before play().
      await api.play(0);
    } catch (e) {
      // API failed — revert optimistic flash.
      if (mounted) {
        _flashController.reset();
        setState(() => _tappedToPlay = false);
      }
      showSafeToast('Failed to play: $e', isError: true);
    }
  }

  Future<void> _addToQueue() async {
    final api = ref.read(kalinkaProxyProvider);
    final title = widget.item.track?.title ?? widget.item.name ?? 'track';
    try {
      await api.add([widget.item.id]);
      showSafeToast('"$title" added to queue');
    } catch (e) {
      showSafeToast('Failed to add: $e', isError: true);
    }
  }

  Future<void> _playNext() async {
    final api = ref.read(kalinkaProxyProvider);
    final title = widget.item.track?.title ?? widget.item.name ?? 'track';
    try {
      await api.add([widget.item.id], index: playNextInsertIndex(ref));
      showSafeToast('"$title" playing next');
    } catch (e) {
      showSafeToast('Failed to add: $e', isError: true);
    }
  }

  // --- Row long-press (multi-select) ---

  void _startLongPress() {
    _longPressing = true;
    _longPressProgress = 0.0;
    const tickDuration = Duration(milliseconds: 16);
    _longPressTimer = Timer.periodic(tickDuration, (timer) {
      if (!mounted || !_longPressing) {
        timer.cancel();
        if (mounted) setState(() => _longPressProgress = 0.0);
        return;
      }
      setState(() {
        _longPressProgress = min(1.0, _longPressProgress + 16 / 500);
      });
      if (_longPressProgress >= 1.0) {
        timer.cancel();
        HapticFeedback.mediumImpact();
        if (!mounted) return;
        ref
            .read(selectionStateProvider.notifier)
            .enterSelectionMode(widget.item.id);
        setState(() {
          _longPressing = false;
          _longPressProgress = 0.0;
        });
      }
    });
  }

  void _cancelLongPress() {
    _longPressing = false;
    _longPressTimer?.cancel();
    if (mounted) setState(() => _longPressProgress = 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final selection = ref.watch(selectionStateProvider);
    final isSelected = selection.selectedIds.contains(widget.item.id);
    final selectionMode = selection.isActive;

    final track = widget.item.track;
    final title = track?.title ?? widget.item.name ?? 'Unknown';
    final artist = track?.performer?.name ?? '';
    final album = track?.album?.title ?? '';
    final subtitle = [
      artist,
      album,
    ].where((s) => s.isNotEmpty).join(' \u00B7 ');
    final duration = _formatDuration(
      track?.duration != null ? track!.duration * 1000 : null,
    );

    final urlResolver = ref.read(urlResolverProvider);
    final imageUrl = widget.item.image?.small;
    final resolvedImageUrl = imageUrl != null
        ? urlResolver.abs(imageUrl)
        : null;

    // Only rebuild on currentTrack ID changes — not on every position tick.
    // PlaybackState.position updates frequently while playing; watching the
    // whole state would re-`build()` every visible track row each tick.
    final currentTrackId =
        ref.watch(playerStateProvider.select((s) => s.currentTrack?.id));
    final isCurrentTrack =
        widget.item.id.isNotEmpty && currentTrackId == widget.item.id;
    // Clear optimistic flash once server confirms this track is current,
    // or instantly revert if a different track became current.
    ref.listen(
      playerStateProvider.select((s) => s.currentTrack?.id),
      (prev, next) {
        if (!mounted) return;
        if (next == widget.item.id && _tappedToPlay) {
          setState(() => _tappedToPlay = false);
        } else if (_tappedToPlay && next != null && next != widget.item.id) {
          // A different track was chosen — clear our flash instantly.
          _flashController.reset();
          setState(() => _tappedToPlay = false);
        }
      },
    );

    // Now-playing row decoration
    final showNowPlaying =
        !selectionMode && (_tappedToPlay || isCurrentTrack);
    final Color baseRowBg;
    if (selectionMode && isSelected) {
      baseRowBg = KalinkaColors.accent.withValues(alpha: 0.07);
    } else if (showNowPlaying) {
      baseRowBg = KalinkaColors.accentSubtle;
    } else {
      baseRowBg = Colors.transparent;
    }

    // Left-edge indicator bar drawn as an overlay so it doesn't push content
    // right the way a Border would.
    final Color? barColor = (selectionMode && isSelected)
        ? KalinkaColors.accent
        : (showNowPlaying ? KalinkaColors.accentBorder : null);

    final tileChild = TrackTileLayout(
      leadingStartSpacing: 0,
      leading: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: resolvedImageUrl != null
                ? Image.network(
                    resolvedImageUrl,
                    width: 44,
                    height: 44,
                    cacheWidth: 132,
                    cacheHeight: 132,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    filterQuality: FilterQuality.low,
                    errorBuilder: (_, __, ___) => ProceduralAlbumArt(
                      trackId: widget.item.id,
                      size: 44,
                    ),
                  )
                : ProceduralAlbumArt(
                    trackId: widget.item.id, size: 44),
          ),
          if (_longPressing && _longPressProgress > 0)
            Positioned.fill(
              child: CustomPaint(
                painter: LongPressRingPainter(
                  progress: _longPressProgress,
                  color: KalinkaColors.accent,
                ),
              ),
            ),
          if (selectionMode && isSelected)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: KalinkaColors.accent.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
        ],
      ),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: KalinkaTextStyles.trackRowTitle.copyWith(
              color: selectionMode && isSelected
                  ? KalinkaColors.accentTint
                  : null,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          if (subtitle.isNotEmpty)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SourceBadge(
                  entityId: widget.item.id,
                  size: SourceBadgeSize.standard,
                ),
                if (ref.watch(sourceCountProvider) > 1)
                  const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    subtitle,
                    style: KalinkaTextStyles.trackRowSubtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
        ],
      ),
      trailing: duration != null
          ? Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                duration,
                style: KalinkaTextStyles.trackRowSubtitle,
              ),
            )
          : null,
    );

    return SwipeToActRow(
      enabled: !selectionMode,
      onAddToQueue: _addToQueue,
      onPlayNext: _playNext,
      child: GestureDetector(
        onTap: () {
          if (selectionMode) {
            ref.read(selectionStateProvider.notifier).toggle(widget.item.id);
          } else {
            _playTrack();
          }
        },
        onLongPressStart: selectionMode ? null : (_) => _startLongPress(),
        onLongPressEnd: selectionMode ? null : (_) => _cancelLongPress(),
        onLongPressCancel: selectionMode ? null : _cancelLongPress,
        child: Stack(
          children: [
            // The flash animation only repaints the background — `tileChild`
            // is captured outside the AnimatedBuilder so its image, badges,
            // and text don't rebuild on every animation tick.
            AnimatedBuilder(
              animation: _flashController,
              builder: (context, child) {
                final Color rowBg =
                    (showNowPlaying && _flashController.isAnimating)
                        ? (_flashColorAnim.value ?? baseRowBg)
                        : baseRowBg;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(color: rowBg),
                  child: child,
                );
              },
              child: tileChild,
            ),
            if (barColor != null)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: Container(width: 2, color: barColor),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String? _formatDuration(int? ms) {
    if (ms == null) return null;
    final seconds = ms ~/ 1000;
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

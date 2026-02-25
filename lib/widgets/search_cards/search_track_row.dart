import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data_model/data_model.dart';
import '../../providers/kalinka_player_api_provider.dart';
import '../../providers/selection_state_provider.dart';
import '../../providers/toast_provider.dart';
import '../../providers/url_resolver.dart';
import '../../providers/source_modules_provider.dart';
import '../../theme/app_theme.dart';
import '../procedural_album_art.dart';
import '../source_badge.dart';
import '../swipe_to_act_row.dart';
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

class _SearchTrackRowState extends ConsumerState<SearchTrackRow> {
  // Long-press ring animation (row long-press → multi-select)
  bool _longPressing = false;
  double _longPressProgress = 0.0;
  Timer? _longPressTimer;

  @override
  void dispose() {
    _longPressTimer?.cancel();
    super.dispose();
  }

  Future<void> _playTrack() async {
    try {
      final api = ref.read(kalinkaProxyProvider);
      await api.clear();
      await api.add([widget.item.id]);
      await api.play();
    } catch (e) {
      ref
          .read(toastProvider.notifier)
          .show('Failed to play: $e', isError: true);
    }
  }

  Future<void> _addToQueue() async {
    try {
      final api = ref.read(kalinkaProxyProvider);
      await api.add([widget.item.id]);
      final title = widget.item.track?.title ?? widget.item.name ?? 'track';
      ref.read(toastProvider.notifier).show('"$title" added to queue');
    } catch (e) {
      ref.read(toastProvider.notifier).show('Failed to add: $e', isError: true);
    }
  }

  Future<void> _playNext() async {
    try {
      final api = ref.read(kalinkaProxyProvider);
      await api.add([widget.item.id]);
      final title = widget.item.track?.title ?? widget.item.name ?? 'track';
      ref.read(toastProvider.notifier).show('"$title" playing next');
    } catch (e) {
      ref.read(toastProvider.notifier).show('Failed to add: $e', isError: true);
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
          decoration: BoxDecoration(
            color: selectionMode && isSelected
                ? KalinkaColors.accent.withValues(alpha: 0.07)
                : Colors.transparent,
            border: selectionMode && isSelected
                ? const Border(
                    left: BorderSide(color: KalinkaColors.accent, width: 2),
                  )
                : null,
          ),
          child: Row(
            children: [
              // Thumbnail
              SizedBox(
                width: 44,
                height: 44,
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: resolvedImageUrl != null
                          ? Image.network(
                              resolvedImageUrl,
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => ProceduralAlbumArt(
                                trackId: widget.item.id,
                                size: 44,
                              ),
                            )
                          : ProceduralAlbumArt(
                              trackId: widget.item.id,
                              size: 44,
                            ),
                    ),
                    // Long-press ring
                    if (_longPressing && _longPressProgress > 0)
                      Positioned.fill(
                        child: CustomPaint(
                          painter: LongPressRingPainter(
                            progress: _longPressProgress,
                            color: KalinkaColors.accent,
                          ),
                        ),
                      ),
                    // Selection checkmark overlay
                    if (selectionMode && isSelected)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: KalinkaColors.accent.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(8),
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
              ),
              const SizedBox(width: 12),
              // Title + artist
              Expanded(
                child: Column(
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
              ),
              const SizedBox(width: 12),
              // Duration
              if (duration != null)
                Text(duration, style: KalinkaTextStyles.trackRowSubtitle),
              const SizedBox(width: 12),
            ],
          ),
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

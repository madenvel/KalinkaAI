import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data_model/data_model.dart';
import '../../providers/add_mode_provider.dart';
import '../../providers/kalinka_player_api_provider.dart';
import '../../providers/selection_state_provider.dart';
import '../../providers/url_resolver.dart';
import '../../theme/app_theme.dart';
import '../procedural_album_art.dart';
import '../source_badge.dart';
import 'add_context_menu.dart';
import 'long_press_ring_painter.dart';

/// Track row for search results.
/// ~60px height, 44x44 thumbnail, title/artist/duration, + button.
/// Tap row = play immediately. Tap + = mode-dependent add.
/// Long-press row = enter multi-select.
/// Long-press + button = escape hatch context menu.
class SearchTrackRow extends ConsumerStatefulWidget {
  final BrowseItem item;

  const SearchTrackRow({super.key, required this.item});

  @override
  ConsumerState<SearchTrackRow> createState() => _SearchTrackRowState();
}

class _SearchTrackRowState extends ConsumerState<SearchTrackRow>
    with TickerProviderStateMixin {
  late AnimationController _confirmController;
  late Animation<double> _scaleAnimation;
  late Animation<Color?> _colorAnimation;
  bool _showCheck = false;
  Timer? _resetTimer;

  // Long-press ring animation (row long-press → multi-select)
  bool _longPressing = false;
  double _longPressProgress = 0.0;
  Timer? _longPressTimer;

  // + button long-press (escape hatch)
  bool _plusLongPressing = false;
  double _plusLongPressProgress = 0.0;
  Timer? _plusLongPressTimer;

  // Tooltip overlay
  OverlayEntry? _tooltipOverlay;
  Timer? _tooltipDismissTimer;

  @override
  void initState() {
    super.initState();
    _confirmController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _scaleAnimation =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.85), weight: 20),
          TweenSequenceItem(tween: Tween(begin: 0.85, end: 1.12), weight: 50),
          TweenSequenceItem(tween: Tween(begin: 1.12, end: 1.0), weight: 30),
        ]).animate(
          CurvedAnimation(parent: _confirmController, curve: Curves.easeInOut),
        );
    _colorAnimation = ColorTween(
      begin: KalinkaColors.gold,
      end: KalinkaColors.confirmGreen,
    ).animate(_confirmController);
  }

  @override
  void dispose() {
    _confirmController.dispose();
    _resetTimer?.cancel();
    _longPressTimer?.cancel();
    _plusLongPressTimer?.cancel();
    _tooltipDismissTimer?.cancel();
    _tooltipOverlay?.remove();
    super.dispose();
  }

  Future<void> _handleAddTap(BuildContext context) async {
    final addModeState = ref.read(addModeProvider);

    // First-encounter intercept
    if (!addModeState.firstEncounterShown) {
      ref.read(addModeProvider.notifier).triggerFirstEncounter(widget.item);
      return;
    }

    if (addModeState.addMode == AddMode.askEachTime) {
      _showContextMenu(context, showAddToPlaylist: true);
      return;
    }

    // Mode B: instant append
    await _instantAppend();
  }

  Future<void> _instantAppend() async {
    try {
      final api = ref.read(kalinkaProxyProvider);
      await api.add([widget.item.id]);

      if (!mounted) return;
      setState(() => _showCheck = true);
      _confirmController.forward(from: 0);
      _resetTimer?.cancel();
      _resetTimer = Timer(const Duration(milliseconds: 1600), () {
        if (mounted) {
          setState(() => _showCheck = false);
          _confirmController.reset();
        }
      });

      if (mounted) {
        final title = widget.item.track?.title ?? widget.item.name ?? 'track';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"$title" appended'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to add: $e')));
      }
    }
  }

  void _showContextMenu(BuildContext context, {bool showAddToPlaylist = true}) {
    final renderBox = context.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (ctx) => AddContextMenu(
        item: widget.item,
        showAddToPlaylist: showAddToPlaylist,
        anchorPosition: Offset(
          position.dx + size.width - 40,
          position.dy + size.height / 2,
        ),
        onConfirm: () {
          setState(() => _showCheck = true);
          _confirmController.forward(from: 0);
          _resetTimer?.cancel();
          _resetTimer = Timer(const Duration(milliseconds: 1600), () {
            if (mounted) {
              setState(() => _showCheck = false);
              _confirmController.reset();
            }
          });
        },
      ),
    );
  }

  Future<void> _playTrack() async {
    try {
      final api = ref.read(kalinkaProxyProvider);
      await api.add([widget.item.id]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to play: $e')));
      }
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

  // --- + button long-press (escape hatch) ---

  void _startPlusLongPress() {
    _plusLongPressing = true;
    _plusLongPressProgress = 0.0;
    const tickDuration = Duration(milliseconds: 16);
    _plusLongPressTimer = Timer.periodic(tickDuration, (timer) {
      if (!mounted || !_plusLongPressing) {
        timer.cancel();
        if (mounted) setState(() => _plusLongPressProgress = 0.0);
        return;
      }
      setState(() {
        _plusLongPressProgress = min(1.0, _plusLongPressProgress + 16 / 400);
      });
      if (_plusLongPressProgress >= 1.0) {
        timer.cancel();
        HapticFeedback.mediumImpact();
        setState(() {
          _plusLongPressing = false;
          _plusLongPressProgress = 0.0;
        });

        // Show "Hold for options" tooltip in Mode B (once per session)
        final addModeState = ref.read(addModeProvider);
        if (addModeState.addMode == AddMode.alwaysAppend &&
            !addModeState.holdForOptionsTooltipShown) {
          ref.read(addModeProvider.notifier).markHoldTooltipShown();
          _showHoldTooltip();
        }

        // Open context menu (escape hatch — one-time, doesn't change mode)
        _showContextMenu(context, showAddToPlaylist: true);
      }
    });
  }

  void _cancelPlusLongPress() {
    _plusLongPressing = false;
    _plusLongPressTimer?.cancel();
    if (mounted) setState(() => _plusLongPressProgress = 0.0);
  }

  void _showHoldTooltip() {
    final renderBox = context.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    _tooltipOverlay?.remove();
    _tooltipOverlay = OverlayEntry(
      builder: (context) => Positioned(
        left: position.dx + size.width - 100,
        top: position.dy + size.height + 4,
        child: IgnorePointer(
          child: Material(
            color: Colors.transparent,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              builder: (context, value, child) {
                return Opacity(opacity: value, child: child);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: KalinkaColors.miniPlayerSurface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: KalinkaColors.borderDefault),
                ),
                child: Text(
                  'Hold for options',
                  style: KalinkaTextStyles.trackRowSubtitle.copyWith(
                    color: const Color(0xFF48485A),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_tooltipOverlay!);

    _tooltipDismissTimer?.cancel();
    _tooltipDismissTimer = Timer(const Duration(milliseconds: 1200), () {
      _tooltipOverlay?.remove();
      _tooltipOverlay = null;
    });
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

    // Scale for + button during long-press (1.0 → 0.88)
    final plusScale = _plusLongPressing
        ? 1.0 - (0.12 * _plusLongPressProgress)
        : 1.0;

    return GestureDetector(
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
                        : ProceduralAlbumArt(trackId: widget.item.id, size: 44),
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
                  // Source badge
                  if (!(selectionMode && isSelected))
                    Positioned(
                      bottom: 1,
                      right: 1,
                      child: SourceBadge(entityId: widget.item.id),
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
                          ? KalinkaColors.accent
                          : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: KalinkaTextStyles.trackRowSubtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Duration
            if (duration != null)
              Text(duration, style: KalinkaTextStyles.trackRowSubtitle),
            const SizedBox(width: 12),
            // + button (hidden in selection mode)
            if (!selectionMode)
              AnimatedBuilder(
                animation: _confirmController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _confirmController.isAnimating
                        ? _scaleAnimation.value
                        : plusScale,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _handleAddTap(context),
                      onLongPressStart: (_) => _startPlusLongPress(),
                      onLongPressEnd: (_) => _cancelPlusLongPress(),
                      onLongPressCancel: _cancelPlusLongPress,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color:
                              (_showCheck
                                      ? _colorAnimation.value
                                      : KalinkaColors.gold)
                                  ?.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color:
                                (_showCheck
                                    ? _colorAnimation.value
                                    : KalinkaColors.gold) ??
                                KalinkaColors.gold,
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          _showCheck ? Icons.check : Icons.add,
                          size: 16,
                          color: _showCheck
                              ? _colorAnimation.value
                              : KalinkaColors.gold,
                        ),
                      ),
                    ),
                  );
                },
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

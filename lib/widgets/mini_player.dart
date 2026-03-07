import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data_model/data_model.dart';
import '../data_model/kalinka_ws_api.dart';
import '../providers/app_state_provider.dart';
import '../providers/connection_settings_provider.dart';
import '../providers/connection_state_provider.dart';
import '../providers/kalinka_ws_api_provider.dart';
import '../providers/playback_time_provider.dart';
import '../providers/search_state_provider.dart';
import '../providers/url_resolver.dart';
import '../theme/app_theme.dart';
import '../utils/haptics.dart';
import '../utils/playback_utils.dart';
import 'gradient_progress_line.dart';
import 'procedural_album_art.dart';
import 'source_badge.dart';

/// Fixed bottom mini player — 72px tall plus safe area inset.
/// Fades out when keyboard is visible during search.
///
/// Swipe gestures:
/// - Swipe left  = next track (with resistance; haptic + auto-complete at 1/3)
/// - Swipe right = previous track
/// - Swipe up    = open now-playing overlay (same as tap)
///
/// Only the track title/artist text participates in the carousel slide.
/// Album art and play/pause button remain stationary.
class MiniPlayer extends ConsumerStatefulWidget {
  final VoidCallback? onTap;

  const MiniPlayer({super.key, this.onTap});

  @override
  ConsumerState<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends ConsumerState<MiniPlayer>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  Timer? _keyboardDismissTimer;
  late AnimationController _marchController;

  // ── Carousel swipe state ──────────────────────────────────────────────────
  /// Normalized offset: -1.0 = next track centred, 0 = current, +1.0 = prev centred.
  late AnimationController _carouselController;

  /// Width of the text area, cached from LayoutBuilder each frame.
  double _textAreaWidth = 200.0;

  /// Swipe direction lock: null = idle, true = going next (left), false = going prev (right).
  bool? _swipeIsNext;
  bool _swipeHapticFired = false;
  Track? _incomingTrackSnapshot;
  Track? _latchedCurrentTrack;

  /// True while the auto-complete animation is running so gesture updates are ignored.
  bool _committed = false;

  /// Visual gap between adjacent track slots as a fraction of textAreaWidth.
  /// 1.0 keeps track slots fully separated to avoid text overlap while swiping.
  static const double _carouselGap = 1.15;

  /// Auto-commit threshold as a fraction of the configured gap.
  static const double _commitThreshold = 0.4;

  /// Content moves at 70% of finger speed — gives a tactile "dragging against something" feel.
  static const double _carouselResistance = 0.70;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _marchController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _carouselController = AnimationController(
      vsync: this,
      lowerBound: -1.2,
      upperBound: 1.2,
      duration: const Duration(milliseconds: 250),
    );
    _carouselController.value =
        0.0; // AnimationController defaults to lowerBound
    _carouselController.addListener(() => setState(() {}));
  }

  void _setMarching(bool enabled) {
    if (enabled) {
      if (!_marchController.isAnimating) {
        _marchController.repeat();
      }
      return;
    }

    if (_marchController.isAnimating) {
      _marchController.stop();
      _marchController.value = 0.0;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _keyboardDismissTimer?.cancel();
    _marchController.dispose();
    _carouselController.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final bottomInset = view.viewInsets.bottom / view.devicePixelRatio;
    final isKeyboard = bottomInset > 100;

    if (isKeyboard) {
      _keyboardDismissTimer?.cancel();
      ref.read(searchStateProvider.notifier).setKeyboardVisible(true);
    } else {
      _keyboardDismissTimer?.cancel();
      _keyboardDismissTimer = Timer(const Duration(milliseconds: 80), () {
        if (mounted) {
          ref.read(searchStateProvider.notifier).setKeyboardVisible(false);
        }
      });
    }
  }

  // ── Gesture handlers ──────────────────────────────────────────────────────

  void _onHorizontalDragStart(DragStartDetails _) {
    if (_committed) return;
    _carouselController.stop();
    _swipeHapticFired = false;
    _incomingTrackSnapshot = null;
  }

  void _onHorizontalDragUpdate(DragUpdateDetails d) {
    if (_committed) return;

    final normalizedDelta = d.delta.dx / _textAreaWidth;

    // Lock direction on first meaningful movement.
    if (_swipeIsNext == null && normalizedDelta.abs() > 0.001) {
      setState(() {
        _swipeIsNext = normalizedDelta < 0; // left = next
        _incomingTrackSnapshot = _peekIncomingTrack(_swipeIsNext!);
      });
    }

    var newOffset =
        _carouselController.value + normalizedDelta * _carouselResistance;

    // Prevent reversing direction mid-swipe; clamp to the gap range.
    if (_swipeIsNext == true) {
      newOffset = newOffset.clamp(-_carouselGap, 0.0);
    } else if (_swipeIsNext == false) {
      newOffset = newOffset.clamp(0.0, _carouselGap);
    }

    _carouselController.value = newOffset; // triggers addListener → setState

    // Haptic once at 1/2 of the gap, then auto-complete.
    if (!_swipeHapticFired &&
        newOffset.abs() >= _carouselGap * _commitThreshold) {
      _swipeHapticFired = true;
      KalinkaHaptics.mediumImpact();
      _autoComplete();
    }
  }

  void _onHorizontalDragEnd(DragEndDetails _) {
    if (_committed) return;
    _snapBack();
  }

  /// Animates the carousel to ±1.0, sends the queue command, then resets.
  void _autoComplete() {
    if (_committed) return;
    _committed = true;

    final target = _swipeIsNext == true ? -_carouselGap : _carouselGap;
    final remaining = (target - _carouselController.value).abs();
    // Duration scales with remaining distance so fast mid-swipe feels instant.
    final ms = (remaining * 200.0).round().clamp(60, 280);

    _carouselController
        .animateTo(
          target,
          duration: Duration(milliseconds: ms),
          curve: Curves.easeOut,
        )
        .then((_) {
          if (!mounted) return;
          final connectionState = ref.read(connectionStateProvider);
          final isOffline =
              connectionState == ConnectionStatus.reconnecting ||
              connectionState == ConnectionStatus.offline;
          final sentCommand = !isOffline;
          if (!isOffline) {
            ref
                .read(kalinkaWsApiProvider)
                .sendQueueCommand(
                  _swipeIsNext == true
                      ? const QueueCommand.next()
                      : const QueueCommand.prev(),
                );
          }
          // Reset carousel to centre; new track info arrives via WebSocket.
          setState(() {
            if (sentCommand && _incomingTrackSnapshot != null) {
              _latchedCurrentTrack = _incomingTrackSnapshot;
            }
            _committed = false;
            _swipeIsNext = null;
            _swipeHapticFired = false;
            _incomingTrackSnapshot = null;
          });
          _carouselController.value = 0.0;
        });
  }

  /// User released before the commit threshold — snap text back to centre.
  void _snapBack() {
    setState(() {
      _swipeIsNext = null;
      _swipeHapticFired = false;
      _incomingTrackSnapshot = null;
    });
    _carouselController.animateTo(
      0.0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  Track? _peekIncomingTrack(bool isNext) {
    final queueState = ref.read(playQueueStateStoreProvider);
    final trackList = queueState.trackList;
    final currentIndex = queueState.playbackState.index ?? 0;

    if (isNext) {
      return currentIndex + 1 < trackList.length
          ? trackList[currentIndex + 1]
          : null;
    }
    return currentIndex > 0 ? trackList[currentIndex - 1] : null;
  }

  @override
  Widget build(BuildContext context) {
    final queueSnapshot = ref.watch(
      playQueueStateStoreProvider.select(
        (s) => (
          trackList: s.trackList,
          playbackIndex: s.playbackState.index ?? 0,
          playerState: s.playbackState.state,
          fallbackTrackId: s.playbackState.currentTrack?.id,
          fallbackTrackTitle: s.playbackState.currentTrack?.title,
          fallbackTrackArtist: s.playbackState.currentTrack?.performer?.name,
          fallbackTrackDurationSec: s.playbackState.currentTrack?.duration ?? 0,
          fallbackTrackImageSmall:
              s.playbackState.currentTrack?.album?.image?.small,
        ),
      ),
    );
    final trackList = queueSnapshot.trackList;
    final playbackIndex = queueSnapshot.playbackIndex;

    Track? currentTrack;
    if (playbackIndex >= 0 && playbackIndex < trackList.length) {
      currentTrack = trackList[playbackIndex];
    } else if (queueSnapshot.fallbackTrackId != null) {
      currentTrack = Track(
        id: queueSnapshot.fallbackTrackId!,
        title: queueSnapshot.fallbackTrackTitle ?? 'No track',
        duration: queueSnapshot.fallbackTrackDurationSec,
        performer: queueSnapshot.fallbackTrackArtist == null
            ? null
            : Artist(id: '', name: queueSnapshot.fallbackTrackArtist!),
        album: queueSnapshot.fallbackTrackImageSmall == null
            ? null
            : Album(
                id: '',
                title: '',
                image: AlbumImage(small: queueSnapshot.fallbackTrackImageSmall),
              ),
      );
    }

    final effectiveCurrentTrack = _latchedCurrentTrack ?? currentTrack;
    final playerState = queueSnapshot.playerState;
    final urlResolver = ref.read(urlResolverProvider);

    if (_latchedCurrentTrack != null &&
        currentTrack?.id == _latchedCurrentTrack?.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _latchedCurrentTrack == null) return;
        setState(() {
          _latchedCurrentTrack = null;
        });
      });
    }

    // Queue peek for carousel incoming-track preview.
    final currentIndex = playbackIndex;
    final nextTrack = currentIndex + 1 < trackList.length
        ? trackList[currentIndex + 1]
        : null;
    final prevTrack = currentIndex > 0 ? trackList[currentIndex - 1] : null;
    final incomingTrack = _swipeIsNext == null
        ? null
        : _incomingTrackSnapshot ??
              (_swipeIsNext == true ? nextTrack : prevTrack);

    final searchState = ref.watch(searchStateProvider);
    final shouldHide = searchState.searchActive && searchState.keyboardVisible;

    final connectionState = ref.watch(connectionStateProvider);
    ref.listen(connectionStateProvider, (prev, next) {
      if (prev == null) return;
      if (prev != ConnectionStatus.offline &&
          next == ConnectionStatus.offline) {
        KalinkaHaptics.doublePulse();
      } else if (prev != ConnectionStatus.connected &&
          next == ConnectionStatus.connected) {
        KalinkaHaptics.mediumImpact();
      }
    });
    final settings = ref.watch(connectionSettingsProvider);
    final isOffline =
        connectionState == ConnectionStatus.reconnecting ||
        connectionState == ConnectionStatus.offline;
    _setMarching(isOffline);

    final durationMs = (effectiveCurrentTrack?.duration ?? 0) * 1000;

    final imageUrl = effectiveCurrentTrack?.album?.image?.small;
    final resolvedImageUrl = imageUrl != null
        ? urlResolver.abs(imageUrl)
        : null;

    final carouselOffset = _carouselController.value; // -1..1

    // Precompute offline subtitle so it isn't repeated in two branches.
    final String offlineSubtitle =
        connectionState == ConnectionStatus.reconnecting
        ? 'Reconnecting to ${settings.name.isNotEmpty ? settings.name : settings.host}\u2026'
        : '${settings.name.isNotEmpty ? settings.name : settings.host} unreachable';
    final Color offlineSubtitleColor =
        connectionState == ConnectionStatus.reconnecting
        ? KalinkaColors.statusPending
        : KalinkaColors.statusError;

    return AnimatedSize(
      duration: Duration(milliseconds: shouldHide ? 120 : 200),
      curve: Curves.easeOut,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        height: shouldHide ? 0.0 : null,
        child: AnimatedOpacity(
          opacity: shouldHide ? 0.0 : 1.0,
          duration: Duration(milliseconds: shouldHide ? 120 : 200),
          curve: Curves.easeOut,
          child: Container(
            decoration: const BoxDecoration(
              color: KalinkaColors.surfaceRaised,
              border: Border(
                top: BorderSide(color: KalinkaColors.borderDefault, width: 1),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 2px progress line — marching dashes when offline, gradient when online
                  RepaintBoundary(
                    child: isOffline
                        ? AnimatedBuilder(
                            animation: _marchController,
                            builder: (context, _) => CustomPaint(
                              size: const Size(double.infinity, 2),
                              painter: _MarchingDashesPainter(
                                progress: _marchController.value,
                              ),
                            ),
                          )
                        : Consumer(
                            builder: (context, ref, _) {
                              final playbackTimeMs = ref.watch(
                                playbackTimeMsProvider,
                              );
                              final progress = durationMs > 0
                                  ? (playbackTimeMs / durationMs).clamp(
                                      0.0,
                                      1.0,
                                    )
                                  : 0.0;
                              return GradientProgressLine(progress: progress);
                            },
                          ),
                  ),

                  // Main content — 70px + gesture detection
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onTap,
                    onHorizontalDragStart: _latchedCurrentTrack == null
                        ? _onHorizontalDragStart
                        : null,
                    onHorizontalDragUpdate: _latchedCurrentTrack == null
                        ? _onHorizontalDragUpdate
                        : null,
                    onHorizontalDragEnd: _latchedCurrentTrack == null
                        ? _onHorizontalDragEnd
                        : null,
                    onVerticalDragEnd: (d) {
                      // Swipe up → open now-playing
                      if ((d.primaryVelocity ?? 0) < -200) widget.onTap?.call();
                    },
                    child: SizedBox(
                      height: 70,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            // ── Album art — stationary, updates via server event ──
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: resolvedImageUrl != null
                                  ? Image.network(
                                      resolvedImageUrl,
                                      width: 46,
                                      height: 46,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          ProceduralAlbumArt(
                                            trackId:
                                                effectiveCurrentTrack?.id ?? '',
                                            size: 46,
                                          ),
                                    )
                                  : ProceduralAlbumArt(
                                      trackId: effectiveCurrentTrack?.id ?? '',
                                      size: 46,
                                    ),
                            ),
                            const SizedBox(width: 10),

                            // ── Carousel text area ────────────────────────────────
                            Expanded(
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  // Cache width so gesture handlers can normalise deltas.
                                  _textAreaWidth = math.max(
                                    constraints.maxWidth,
                                    1.0,
                                  );

                                  return ClipRect(
                                    child: Stack(
                                      children: [
                                        // Current track — slides away during swipe.
                                        Transform.translate(
                                          offset: Offset(
                                            carouselOffset * _textAreaWidth,
                                            0,
                                          ),
                                          child: _TrackLabel(
                                            title: effectiveCurrentTrack?.title,
                                            subtitle: isOffline
                                                ? offlineSubtitle
                                                : effectiveCurrentTrack
                                                      ?.performer
                                                      ?.name,
                                            subtitleColor: isOffline
                                                ? offlineSubtitleColor
                                                : null,
                                            entityId: isOffline
                                                ? null
                                                : effectiveCurrentTrack?.id,
                                          ),
                                        ),

                                        // Incoming track — slides in from the opposite edge.
                                        // Gap is _carouselGap * textAreaWidth so it starts
                                        // closer than the full width.
                                        if (incomingTrack != null)
                                          Transform.translate(
                                            offset: Offset(
                                              _swipeIsNext == true
                                                  // Next: enters from the right
                                                  ? (carouselOffset +
                                                            _carouselGap) *
                                                        _textAreaWidth
                                                  // Prev: enters from the left
                                                  : (carouselOffset -
                                                            _carouselGap) *
                                                        _textAreaWidth,
                                              0,
                                            ),
                                            child: _TrackLabel(
                                              title: incomingTrack.title,
                                              subtitle:
                                                  incomingTrack.performer?.name,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              entityId: incomingTrack.id,
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 8),

                            // ── Play/pause — stationary, 46×46 ───────────────────
                            IgnorePointer(
                              ignoring: isOffline,
                              child: Opacity(
                                opacity: isOffline ? 0.3 : 1.0,
                                child: GestureDetector(
                                  onTapDown: isPlayPauseDisabled(playerState)
                                      ? null
                                      : (_) =>
                                            playerState ==
                                                PlayerStateType.playing
                                            ? KalinkaHaptics.lightImpact()
                                            : KalinkaHaptics.mediumImpact(),
                                  onTap: isPlayPauseDisabled(playerState)
                                      ? null
                                      : () => sendPlayPauseCommand(
                                          ref,
                                          playerState,
                                        ),
                                  child: Container(
                                    width: 46,
                                    height: 46,
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                    child:
                                        playerState == PlayerStateType.buffering
                                        ? const Padding(
                                            padding: EdgeInsets.all(12.0),
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                    KalinkaColors.background,
                                                  ),
                                            ),
                                          )
                                        : Icon(
                                            playerState ==
                                                    PlayerStateType.playing
                                                ? Icons.pause_rounded
                                                : Icons.play_arrow_rounded,
                                            size: 26,
                                            color: KalinkaColors.background,
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Single text block for the carousel: title + subtitle + optional source badge.
/// Uses [SizedBox.expand] so it fills the slot and clips correctly inside [ClipRect].
class _TrackLabel extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Color? subtitleColor;
  final CrossAxisAlignment crossAxisAlignment;

  /// When set, a [SourceBadge] is appended to the subtitle line.
  final String? entityId;

  const _TrackLabel({
    this.title,
    this.subtitle,
    this.subtitleColor,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.entityId,
  });

  @override
  Widget build(BuildContext context) {
    final subtitleStyle = subtitleColor != null
        ? KalinkaTextStyles.miniPlayerArtist.copyWith(color: subtitleColor)
        : KalinkaTextStyles.miniPlayerArtist;

    return SizedBox.expand(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: crossAxisAlignment,
        children: [
          Text(
            title ?? 'No track',
            style: KalinkaTextStyles.miniPlayerTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (entityId != null) ...[
                SourceBadge(
                  entityId: entityId!,
                  size: SourceBadgeSize.standard,
                ),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  subtitle ?? '\u2014',
                  style: subtitleStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Marching red dashes for the offline progress line.
class _MarchingDashesPainter extends CustomPainter {
  final double progress;

  _MarchingDashesPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = KalinkaColors.borderSubtle;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final dashPaint = Paint()..color = KalinkaColors.statusError;
    const dashWidth = 8.0;
    const gapWidth = 6.0;
    const period = dashWidth + gapWidth;
    final offset = progress * period;

    var x = -period + offset;
    while (x < size.width) {
      final left = math.max(0.0, x);
      final right = math.min(size.width, x + dashWidth);
      if (right > left) {
        canvas.drawRect(
          Rect.fromLTWH(left, 0, right - left, size.height),
          dashPaint,
        );
      }
      x += period;
    }
  }

  @override
  bool shouldRepaint(_MarchingDashesPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

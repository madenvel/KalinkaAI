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

/// Fixed bottom mini player — 72px tall plus safe area inset.
/// Fades out when keyboard is visible during search.
class MiniPlayer extends ConsumerStatefulWidget {
  final VoidCallback? onTap;

  const MiniPlayer({super.key, this.onTap});

  @override
  ConsumerState<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends ConsumerState<MiniPlayer>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  Timer? _keyboardDismissTimer;
  late AnimationController _marchController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _marchController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _keyboardDismissTimer?.cancel();
    _marchController.dispose();
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
      // Delay hiding to allow smooth transition (80ms per spec)
      _keyboardDismissTimer?.cancel();
      _keyboardDismissTimer = Timer(const Duration(milliseconds: 80), () {
        if (mounted) {
          ref.read(searchStateProvider.notifier).setKeyboardVisible(false);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final queueState = ref.watch(playQueueStateStoreProvider);
    final playbackState = queueState.playbackState;
    final currentTrack = playbackState.currentTrack;
    final playerState = playbackState.state;
    final playbackTimeMs = ref.watch(playbackTimeMsProvider);
    final urlResolver = ref.read(urlResolverProvider);
    final api = ref.read(kalinkaWsApiProvider);

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

    final durationMs = (currentTrack?.duration ?? 0) * 1000;
    final progress = durationMs > 0
        ? (playbackTimeMs / durationMs).clamp(0.0, 1.0)
        : 0.0;

    final imageUrl = currentTrack?.album?.image?.small;
    final resolvedImageUrl = imageUrl != null
        ? urlResolver.abs(imageUrl)
        : null;

    return AnimatedOpacity(
      opacity: shouldHide ? 0.0 : 1.0,
      duration: Duration(milliseconds: shouldHide ? 120 : 200),
      curve: Curves.easeOut,
      child: Container(
        decoration: const BoxDecoration(
          color: KalinkaColors.miniPlayerSurface,
          border: Border(
            top: BorderSide(color: KalinkaColors.borderElevated, width: 1),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 2px progress line — marching dashes when offline, gradient when online
              if (isOffline)
                AnimatedBuilder(
                  animation: _marchController,
                  builder: (context, _) {
                    return CustomPaint(
                      size: const Size(double.infinity, 2),
                      painter: _MarchingDashesPainter(
                        progress: _marchController.value,
                      ),
                    );
                  },
                )
              else
                GradientProgressLine(progress: progress),
              // Main content — 72px
              GestureDetector(
                onTap: widget.onTap,
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  height: 70, // 72 - 2px progress line
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        // Album art 46x46
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
                                        trackId: currentTrack?.id ?? '',
                                        size: 46,
                                      ),
                                )
                              : ProceduralAlbumArt(
                                  trackId: currentTrack?.id ?? '',
                                  size: 46,
                                ),
                        ),
                        const SizedBox(width: 10),
                        // Track title + artist (or reconnecting text)
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currentTrack?.title ?? 'No track',
                                style: KalinkaTextStyles.miniPlayerTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              if (isOffline)
                                Text(
                                  connectionState ==
                                          ConnectionStatus.reconnecting
                                      ? 'Reconnecting to ${settings.name.isNotEmpty ? settings.name : settings.host}\u2026'
                                      : '${settings.name.isNotEmpty ? settings.name : settings.host} unreachable',
                                  style: KalinkaTextStyles.miniPlayerArtist
                                      .copyWith(
                                        color:
                                            connectionState ==
                                                ConnectionStatus.reconnecting
                                            ? KalinkaColors.amber
                                            : KalinkaColors.statusRed,
                                      ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )
                              else
                                Text(
                                  currentTrack?.performer?.name ?? '\u2014',
                                  style: KalinkaTextStyles.miniPlayerArtist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Transport controls — disabled when offline
                        IgnorePointer(
                          ignoring: isOffline,
                          child: Opacity(
                            opacity: isOffline ? 0.3 : 1.0,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _TransportButton(
                                  icon: Icons.skip_previous_rounded,
                                  size: 24,
                                  onTapDown: KalinkaHaptics.mediumImpact,
                                  onTap: () => api.sendQueueCommand(
                                    const QueueCommand.prev(),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                // Play/pause — filled white circle 36px
                                GestureDetector(
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
                                    width: 36,
                                    height: 36,
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      playerState == PlayerStateType.playing
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                      size: 22,
                                      color: KalinkaColors.background,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                _TransportButton(
                                  icon: Icons.skip_next_rounded,
                                  size: 24,
                                  onTapDown: KalinkaHaptics.mediumImpact,
                                  onTap: () => api.sendQueueCommand(
                                    const QueueCommand.next(),
                                  ),
                                ),
                              ],
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
    );
  }
}

/// Marching red dashes for the offline progress line.
class _MarchingDashesPainter extends CustomPainter {
  final double progress;

  _MarchingDashesPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    // Background
    final bgPaint = Paint()..color = KalinkaColors.borderDefault;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Red marching dashes
    final dashPaint = Paint()..color = KalinkaColors.statusRed;
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
  bool shouldRepaint(_MarchingDashesPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _TransportButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback? onTap;
  final VoidCallback? onTapDown;

  const _TransportButton({
    required this.icon,
    required this.size,
    this.onTap,
    this.onTapDown,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: onTapDown != null ? (_) => onTapDown!() : null,
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: size, color: KalinkaColors.textPrimary),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../data_model/data_model.dart';
import '../theme/app_theme.dart';

/// Shared inner glyph for the white play/pause discs (mini player + now
/// playing). Keeps the two surfaces visually consistent:
///   - buffering -> circular spinner
///   - error     -> greyscale warning icon
///   - otherwise -> play/pause icon
///
/// Sizes are parameterised because the mini player disc (46dp) and the
/// now-playing disc (68dp) render the same glyph at different scales.
class PlayPauseGlyph extends StatelessWidget {
  final PlayerStateType? playerState;

  /// Size of the play/pause icon.
  final double iconSize;

  /// Diameter of the buffering spinner and the error warning icon.
  final double statusSize;

  /// Stroke width of the buffering spinner.
  final double spinnerStrokeWidth;

  const PlayPauseGlyph({
    super.key,
    required this.playerState,
    required this.iconSize,
    required this.statusSize,
    this.spinnerStrokeWidth = 2.5,
  });

  @override
  Widget build(BuildContext context) {
    if (playerState == PlayerStateType.buffering) {
      return SizedBox(
        width: statusSize,
        height: statusSize,
        child: CircularProgressIndicator(
          strokeWidth: spinnerStrokeWidth,
          valueColor: const AlwaysStoppedAnimation<Color>(
            KalinkaColors.background,
          ),
        ),
      );
    }
    if (playerState == PlayerStateType.error) {
      return Icon(
        Icons.warning_rounded,
        size: statusSize,
        // Greyscale, not accent — error is a passive state, not a CTA.
        color: KalinkaColors.textMuted,
      );
    }
    return Icon(
      playerState == PlayerStateType.playing
          ? Icons.pause_rounded
          : Icons.play_arrow_rounded,
      size: iconSize,
      color: KalinkaColors.background,
    );
  }
}

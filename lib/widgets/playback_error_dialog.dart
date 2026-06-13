import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data_model/kalinka_ws_api.dart';
import '../providers/kalinka_ws_api_provider.dart';
import '../theme/app_theme.dart';
import 'kalinka_button.dart';

/// Bottom-anchored card shown when the current track fails to play.
///
/// Styled to match the app's confirm dialogs. Offers two actions:
///   - "Skip" (primary/accent): advance to the next track and close.
///   - "Dismiss" (neutral): just close.
///
/// Render via [showKalinkaConfirmDialog] so it slides up over the scrim.
///
/// On tablet the dialog is confined to the right half of the screen (the
/// queue/search panel) so it doesn't dim or span the now-playing panel. In
/// that mode the widget paints its own scrim — pass `barrierColor:
/// Colors.transparent` to the show call so the global barrier stays clear.
class PlaybackErrorDialog extends ConsumerWidget {
  final String? message;

  /// When true, the scrim + card are constrained to the right half of the
  /// screen instead of spanning the full width.
  final bool isTablet;

  const PlaybackErrorDialog({super.key, this.message, this.isTablet = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isTablet) return _buildCard(context, ref);

    // Tablet: dismiss-on-tap left half left clear, right half scrimmed with the
    // card anchored to its bottom.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.pop(context),
            child: const SizedBox.expand(),
          ),
        ),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.pop(context),
            child: ColoredBox(
              color: Colors.black.withValues(alpha: 0.60),
              child: _buildCard(context, ref),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCard(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: KalinkaColors.surfaceRaised,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: KalinkaColors.borderDefault),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.7),
                blurRadius: 60,
                offset: const Offset(0, -20),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Warning icon tile (greyscale, matching the play-button glyph).
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: KalinkaColors.textMuted.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: KalinkaColors.textMuted.withValues(alpha: 0.2),
                  ),
                ),
                child: const Icon(
                  Icons.warning_rounded,
                  size: 24,
                  color: KalinkaColors.textMuted,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Playback error',
                style: KalinkaTextStyles.dialogTitle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                (message != null && message!.isNotEmpty)
                    ? message!
                    : 'This track couldn’t be played.',
                style: KalinkaTextStyles.dialogBody,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: KalinkaButton(
                      label: 'Dismiss',
                      variant: KalinkaButtonVariant.neutral,
                      size: KalinkaButtonSize.normal,
                      fullWidth: true,
                      onTap: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: KalinkaButton(
                      label: 'Skip',
                      variant: KalinkaButtonVariant.accent,
                      size: KalinkaButtonSize.normal,
                      fullWidth: true,
                      onTap: () {
                        ref
                            .read(kalinkaWsApiProvider)
                            .sendQueueCommand(const QueueCommand.next());
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: MediaQuery.of(context).padding.bottom + 28),
      ],
    );
  }
}

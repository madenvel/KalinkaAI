import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'kalinka_button.dart';

// Matches the split-layout switch in MusicPlayerScreen.
const _tabletBreakpoint = 900.0;

/// Confirmation dialog for restarting the server.
///
/// Returns `true` when the user confirms, `false`/`null` when cancelled —
/// the caller performs the restart. Show via [showKalinkaConfirmDialog].
/// Mirrors the bottom-anchored style of [ClearAllConfirmDialog].
class RestartConfirmDialog extends StatelessWidget {
  const RestartConfirmDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final content = Column(
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
              const Icon(
                Icons.restart_alt,
                size: 40,
                color: KalinkaColors.accent,
              ),
              const SizedBox(height: 14),
              Text(
                'Restart server?',
                style: KalinkaTextStyles.dialogTitle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Applies any pending changes and restarts the server. '
                'Playback will stop briefly.',
                style: KalinkaTextStyles.dialogBody,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: KalinkaButton(
                      label: 'Cancel',
                      variant: KalinkaButtonVariant.neutral,
                      fullWidth: true,
                      onTap: () => Navigator.pop(context, false),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: KalinkaButton(
                      label: 'Restart',
                      variant: KalinkaButtonVariant.accent,
                      fullWidth: true,
                      onTap: () => Navigator.pop(context, true),
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

    // On tablet, settings live in the left half, so anchor the dialog there
    // rather than spanning the whole window. Empty right half lets taps fall
    // through to the barrier to dismiss. Phone keeps the full-width sheet.
    final width = MediaQuery.of(context).size.width;
    if (width < _tabletBreakpoint) return content;
    return Row(
      children: [
        Expanded(child: content),
        const Expanded(child: SizedBox.expand()),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'kalinka_button.dart';

/// Confirmation dialog for upgrading the server to [version].
///
/// Returns `true` when the user confirms — the caller starts the upgrade.
/// Show via [showKalinkaConfirmDialog]. Mirrors [RestartConfirmDialog].
class UpgradeConfirmDialog extends StatelessWidget {
  final String version;

  const UpgradeConfirmDialog({super.key, required this.version});

  @override
  Widget build(BuildContext context) {
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
              const Icon(
                Icons.system_update_alt,
                size: 40,
                color: KalinkaColors.accent,
              ),
              const SizedBox(height: 14),
              Text(
                'Upgrade server to $version?',
                style: KalinkaTextStyles.dialogTitle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Downloading and installing can take several minutes, and '
                'the server restarts when done. Playback will stop.',
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
                      label: 'Upgrade',
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
  }
}

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'kalinka_button.dart';
import 'kalinka_dialog.dart';

/// Confirmation dialog for upgrading the server to [version].
///
/// Returns `true` when the user confirms — the caller starts the upgrade.
/// Launched from the update banner in Settings (left panel on tablet).
/// Show via [showKalinkaDialog].
class UpgradeConfirmDialog extends StatelessWidget {
  final String version;

  const UpgradeConfirmDialog({super.key, required this.version});

  @override
  Widget build(BuildContext context) {
    return KalinkaDialog(
      side: KalinkaDialogSide.left,
      icon: Icons.system_update_alt,
      iconGlyphColor: KalinkaColors.accentTint,
      title: 'Update Kalinka Server?',
      message:
          'A new version $version is available. Updating takes a few '
          'minutes — the server will be unavailable and playback '
          'will stop until it restarts.',
      actions: [
        KalinkaButton(
          label: 'Cancel',
          variant: KalinkaButtonVariant.neutral,
          fullWidth: true,
          onTap: () => Navigator.pop(context, false),
        ),
        KalinkaButton(
          label: 'Restart & Update',
          variant: KalinkaButtonVariant.accent,
          fullWidth: true,
          onTap: () => Navigator.pop(context, true),
        ),
      ],
    );
  }
}

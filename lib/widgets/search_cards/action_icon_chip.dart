import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Icon-only action chip (section title rows, the multi-select batch bar): a
/// rounded square in a 44dp hit target, echoing [ExpandChevronButton]'s chrome
/// so header actions and row chevrons read as one control family.
///
/// [accent] fills the chip solid crimson with a white icon — the same
/// treatment as [KalinkaButton]'s accent variant — marking the default,
/// queue-replacing action; neutral chips are additive.
class ActionIconChip extends StatelessWidget {
  final IconData icon;
  final bool accent;
  final bool enabled;
  final VoidCallback? onTap;

  /// Overrides for transient states (e.g. gold "Added ✓" confirmation).
  final Color? iconOverride;
  final Color? borderOverride;

  final String semanticsLabel;

  const ActionIconChip({
    super.key,
    required this.icon,
    required this.semanticsLabel,
    this.accent = false,
    this.enabled = true,
    this.onTap,
    this.iconOverride,
    this.borderOverride,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor =
        iconOverride ??
        (accent ? KalinkaColors.textPrimary : KalinkaColors.textSecondary);
    final border =
        borderOverride ??
        (accent ? KalinkaColors.accent : KalinkaColors.borderDefault);

    Widget chip = Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: accent ? KalinkaColors.accent : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: Icon(icon, size: 24, color: iconColor),
    );
    // Dim while busy/confirming so it reads as disabled.
    if (!enabled) {
      chip = Opacity(opacity: 0.6, child: chip);
    }

    return Semantics(
      label: semanticsLabel,
      button: true,
      enabled: enabled,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(width: 44, height: 44, child: Center(child: chip)),
      ),
    );
  }
}

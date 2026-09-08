import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../utils/click_cursor.dart';

/// Compact pill button for the search-results batch actions ("Play all",
/// "Enqueue", and the expanded album/playlist header's Play / Add to queue).
///
/// [accent] marks the default action with the subtle crimson idiom
/// (accentSubtle fill, accentBorder edge, berry-tint label) — never a solid
/// crimson fill; the neutral variant is a plain surface.
class ActionPillButton extends StatelessWidget {
  /// What the button says, or null for an icon-only one — the same chrome and
  /// height as the pills beside it, for an action its glyph already names.
  final String? label;
  final IconData? icon;
  final bool accent;
  final bool enabled;
  final VoidCallback? onTap;

  /// Overrides for transient states (e.g. gold "Added ✓" confirmation).
  final Color? foregroundOverride;
  final Color? borderOverride;

  final String? semanticsLabel;

  const ActionPillButton({
    super.key,
    this.label,
    this.icon,
    this.accent = false,
    this.enabled = true,
    this.onTap,
    this.foregroundOverride,
    this.borderOverride,
    this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    final fg =
        foregroundOverride ??
        (accent ? KalinkaColors.accentTint : KalinkaColors.textPrimary);
    final bg = accent
        ? KalinkaColors.accentSubtle
        : KalinkaColors.surfaceElevated;
    final border =
        borderOverride ??
        (accent ? KalinkaColors.accentBorder : KalinkaColors.borderDefault);

    Widget button = Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: border, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        mouseCursor: clickCursor(interactive: enabled && onTap != null),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) Icon(icon, size: 16, color: fg),
              if (icon != null && label != null) const SizedBox(width: 5),
              if (label != null)
                Text(
                  label!,
                  style: KalinkaFonts.sans(
                    fontSize: KalinkaTypography.baseSize + 1,
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (!enabled) {
      button = Opacity(opacity: 0.6, child: button);
    }

    return Semantics(
      label: semanticsLabel ?? label,
      button: true,
      enabled: enabled,
      child: button,
    );
  }
}

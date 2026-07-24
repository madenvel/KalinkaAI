import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Icon-only action chip (section title rows, the multi-select batch bar): a
/// rounded square in a 44dp hit target, echoing [ExpandChevronButton]'s chrome
/// so header actions and row chevrons read as one control family.
///
/// [accent] fills the chip solid crimson with a white icon — the same
/// treatment as [KalinkaButton]'s accent variant — marking the default,
/// queue-replacing action; neutral chips are additive.
///
/// Feedback is the standard Material stack: an [InkResponse] ripple + focus
/// ring on tap, plus a hover fill on the chip itself so a pointer lands
/// feedback on the visible control (not the padding around it).
class ActionIconChip extends StatefulWidget {
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
  State<ActionIconChip> createState() => _ActionIconChipState();
}

class _ActionIconChipState extends State<ActionIconChip> {
  bool _hovering = false;

  void _setHover(bool value) {
    if (value == _hovering) return;
    setState(() => _hovering = value);
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    final interactive = widget.enabled && widget.onTap != null;
    final hovered = _hovering && interactive;

    final iconColor =
        widget.iconOverride ??
        (accent ? KalinkaColors.textPrimary : KalinkaColors.textSecondary);
    final border =
        widget.borderOverride ??
        (accent ? KalinkaColors.accent : KalinkaColors.borderDefault);

    // Hover fills the chip a step brighter: a lighter crimson on the accent
    // action, a raised neutral surface on the additive one.
    final background = accent
        ? (hovered ? KalinkaColors.accentTint : KalinkaColors.accent)
        : (hovered ? KalinkaColors.surfaceElevated : Colors.transparent);

    Widget chip = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: Icon(widget.icon, size: 24, color: iconColor),
    );
    // Dim while busy/confirming so it reads as disabled.
    if (!widget.enabled) {
      chip = Opacity(opacity: 0.6, child: chip);
    }

    // The ripple/press splash from the standard ink stack; the hover fill above
    // handles hover, so suppress InkResponse's own hover circle.
    return Semantics(
      label: widget.semanticsLabel,
      button: true,
      enabled: widget.enabled,
      child: MouseRegion(
        onEnter: (_) => _setHover(true),
        onExit: (_) => _setHover(false),
        child: Material(
          type: MaterialType.transparency,
          child: InkResponse(
            onTap: interactive ? widget.onTap : null,
            radius: 24,
            hoverColor: Colors.transparent,
            splashColor: accent
                ? Colors.white.withValues(alpha: 0.18)
                : KalinkaColors.textPrimary.withValues(alpha: 0.10),
            highlightColor: KalinkaColors.textPrimary.withValues(alpha: 0.05),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(child: chip),
            ),
          ),
        ),
      ),
    );
  }
}

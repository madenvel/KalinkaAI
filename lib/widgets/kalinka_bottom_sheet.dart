import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'sheet_anchor.dart';

/// Shows a modal bottom sheet styled with the Kalinka visual identity.
///
/// Wraps [showModalBottomSheet] with the app's standard chrome: scrim,
/// surface container with rounded top corners, drag handle, and shadow.
/// The [contentBuilder] receives the sheet context and should return the
/// sheet body (rows, cards, etc.) — the chrome is added automatically.
/// When launched from inside a [SheetAnchor] (the tablet layout's panels),
/// the sheet slides up over that panel instead of the window centre.
Future<T?> showKalinkaBottomSheet<T>({
  required BuildContext context,
  required Widget Function(BuildContext) contentBuilder,
}) {
  final anchor = SheetAnchor.elementOf(context);
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.60),
    isScrollControlled: true,
    // Anchored sheets span the window and get padded down to the panel —
    // the M3 640px cap would re-centre them.
    constraints: anchor != null
        ? const BoxConstraints(maxWidth: double.infinity)
        : null,
    builder: (ctx) {
      final sheet = Container(
        decoration: BoxDecoration(
          color: KalinkaColors.surfaceRaised,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: const Border(
            top: BorderSide(color: KalinkaColors.borderDefault),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.7),
              blurRadius: 60,
              offset: const Offset(0, -20),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(top: 12),
                    decoration: BoxDecoration(
                      color: KalinkaColors.surfaceOverlay,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                contentBuilder(ctx),
              ],
            ),
          ),
        ),
      );
      if (anchor == null) return sheet;
      // LayoutBuilder re-runs at layout time, after the page below (and so
      // the anchor panel) has laid out for the current window size — the
      // inset tracks live resizes, and falls back to full width if the
      // anchor is gone after crossing the tablet breakpoint.
      return LayoutBuilder(
        builder: (_, constraints) {
          final padding = SheetAnchor.paddingFor(anchor, constraints.maxWidth);
          if (padding == EdgeInsets.zero) return sheet;
          // The window-wide sheet's Material claims taps in the strip
          // beside the panel, so the route's own barrier never sees them —
          // this one restores tap-outside-to-close there.
          return Stack(
            children: [
              const Positioned.fill(child: ModalBarrier(color: null)),
              Padding(padding: padding, child: sheet),
            ],
          );
        },
      );
    },
  );
}

/// Shows a centered confirmation dialog with slide-up + fade animation.
///
/// Wraps [showGeneralDialog] with the app's standard dialog styling.
/// The [builder] receives the dialog context and should return the dialog
/// card content (icon, title, body, buttons).
Future<T?> showKalinkaConfirmDialog<T>({
  required BuildContext context,
  required Widget Function(BuildContext) builder,
  Color? barrierColor,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierColor: barrierColor ?? Colors.black.withValues(alpha: 0.60),
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    transitionDuration: const Duration(milliseconds: 280),
    transitionBuilder: (ctx, anim, secondaryAnim, child) {
      final curved = CurvedAnimation(
        parent: anim,
        curve: const Cubic(0.4, 0, 0.2, 1),
      );
      return FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.15),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
    pageBuilder: (ctx, _, __) =>
        Material(type: MaterialType.transparency, child: builder(ctx)),
  );
}

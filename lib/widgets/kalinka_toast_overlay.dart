import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/toast_provider.dart';
import '../theme/app_theme.dart';

/// Height of the MiniPlayer (not including SafeArea bottom inset).
const double _kMiniPlayerHeight = 72.0;

/// Overlay that renders themed toast notifications above the bottom dock.
///
/// On phone: toasts stack upward from just above the bottom bar, cleared by
/// [bottomOffset] (the height of whatever docks at the bottom — the mini
/// player + search pill on the main screen, or the composer on the search
/// screen). On tablet (isTablet: true): toasts appear at bottom-right.
///
/// Wrap in [IgnorePointer] at the call site so toasts never capture taps.
class KalinkaToastOverlay extends ConsumerWidget {
  final bool isTablet;

  /// Space to leave below the toasts on phone so they clear the bottom dock.
  final double bottomOffset;

  const KalinkaToastOverlay({
    super.key,
    this.isTablet = false,
    this.bottomOffset = _kMiniPlayerHeight,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final toasts = ref.watch(toastProvider);
    if (toasts.isEmpty) return const SizedBox.shrink();

    final bottomInset = MediaQuery.of(context).padding.bottom;
    final bottomPadding = isTablet ? 0.0 : bottomOffset + bottomInset + 8.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: isTablet
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.stretch,
      children: [
        for (final toast in toasts.reversed)
          Padding(
            padding: EdgeInsets.fromLTRB(
              isTablet ? 0 : 16,
              0,
              isTablet ? 0 : 16,
              4,
            ),
            // Compact toasts sit as a right-aligned pill; others stretch.
            child: toast.compact && !isTablet
                ? Align(
                    alignment: Alignment.centerRight,
                    child: _ToastCard(entry: toast),
                  )
                : _ToastCard(entry: toast),
          ),
        SizedBox(height: bottomPadding),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ToastCard extends StatefulWidget {
  final ToastEntry entry;

  const _ToastCard({required this.entry});

  @override
  State<_ToastCard> createState() => _ToastCardState();
}

class _ToastCardState extends State<_ToastCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    // Enter animation
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(_ToastCard old) {
    super.didUpdateWidget(old);
    // Trigger exit animation when the provider marks this entry as dismissing
    if (widget.entry.dismissing && !old.entry.dismissing) {
      _ctrl.reverse();
      return;
    }
    // If dismissing gets canceled (e.g. aggregated toast updated), show again.
    if (!widget.entry.dismissing && old.entry.dismissing) {
      _ctrl.forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: Container(
          decoration: BoxDecoration(
            color: KalinkaColors.surfaceElevated,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: KalinkaColors.borderDefault, width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.entry.isLoading)
                const SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.8,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      KalinkaColors.accentTint,
                    ),
                  ),
                )
              else
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.entry.isError
                        ? KalinkaColors.statusOffline
                        : KalinkaColors.statusOnline,
                  ),
                ),
              const SizedBox(width: 10),
              // Message
              Flexible(
                child: Text(
                  widget.entry.message,
                  style: KalinkaTextStyles.toastText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

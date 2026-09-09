import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'hover_text_action.dart';

/// Which face a heading's title takes.
enum ShelfTitleFace {
  /// The mono section label every shelf and results block is marked with.
  label,

  /// The display face, for the block that answers in its own voice rather
  /// than listing what a source holds. It is the face the app gives a thing
  /// with an identity — a page title, the name of a list someone made.
  display,
}

/// A shelf's heading: its name, how many it holds, a rule, and the action
/// that opens it in full. One shape for a library shelf and a results block,
/// so the two read as the same thing.
class ShelfHeading extends StatelessWidget {
  /// Already in the case it should show in.
  final String title;
  final int? count;

  final ShelfTitleFace face;

  /// One line under the title, saying what the shelf is made of.
  final String? subtitle;

  /// A glyph before the title, where the shelf has a mark of its own.
  final IconData? icon;

  final VoidCallback? onViewAll;
  final String viewAllLabel;

  const ShelfHeading({
    super.key,
    required this.title,
    this.count,
    this.subtitle,
    this.icon,
    this.face = ShelfTitleFace.label,
    this.onViewAll,
    this.viewAllLabel = 'VIEW ALL',
  });

  bool get _leading => face == ShelfTitleFace.display;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: _leading ? 17 : 15,
                color: KalinkaColors.accentTint,
              ),
              const SizedBox(width: 8),
            ],
            Text(
              title,
              style: _leading
                  ? KalinkaFonts.display(
                      fontSize: KalinkaTypography.baseSize + 8,
                      fontWeight: FontWeight.w600,
                      color: KalinkaColors.textPrimary,
                    )
                  : KalinkaTextStyles.sectionLabel.copyWith(
                      color: KalinkaColors.textPrimary,
                    ),
            ),
            if (count != null) ...[
              const SizedBox(width: 8),
              Text(
                '· $count',
                style: KalinkaTextStyles.sectionLabel.copyWith(
                  color: KalinkaColors.textMuted,
                ),
              ),
            ],
            const SizedBox(width: 12),
            const Expanded(
              child: Divider(
                color: KalinkaColors.borderSubtle,
                thickness: 1,
                height: 1,
              ),
            ),
            if (onViewAll != null) ...[
              const SizedBox(width: 12),
              ViewAllAction(label: viewAllLabel, onTap: onViewAll!),
            ],
          ],
        ),
        if (subtitle != null) ...[
          SizedBox(height: _leading ? 5 : 4),
          Text(
            subtitle!,
            style: KalinkaTextStyles.trackRowSubtitle.copyWith(
              color: KalinkaColors.textMuted,
            ),
          ),
        ],
      ],
    );
  }
}

/// The action that opens a shelf or a group in full. Mono and unfilled like
/// RESET ALL, so it reads as the heading's action rather than a control of
/// its own.
class ViewAllAction extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const ViewAllAction({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return HoverTextAction(
      label: label,
      semanticsLabel: 'View all',
      onTap: onTap,
      color: KalinkaColors.accentTint,
      hoverColor: KalinkaColors.textPrimary,
    );
  }
}

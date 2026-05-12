import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'inline_markdown.dart';

/// Display-only card for read-only field values, including dynamic
/// plugin-resolved fields (e.g. sub-feature status views).
///
/// Renders as a slightly elevated panel — one surface step above the
/// parent `SettingsCard` — with the value as inline markdown so backend
/// messages like `**Not available** — missing \`numpy\`` render with
/// emphasis. There is no text input, no edit affordance: read-only
/// fields are never written from the client (the server's PUT
/// /server/config rejects writes to dynamic paths anyway).
///
/// The field label is provided by the surrounding `SettingsRow` in
/// vertical layout; this widget only renders the body card.
class SettingsReadonlyCard extends StatelessWidget {
  final String text;
  final IconData? leadingIcon;
  final Color? leadingIconColor;

  const SettingsReadonlyCard({
    super.key,
    required this.text,
    this.leadingIcon,
    this.leadingIconColor,
  });

  @override
  Widget build(BuildContext context) {
    final body = InlineMarkdown(
      text: text.isEmpty ? '(no value)' : text,
      style: KalinkaTextStyles.trayRowSublabel.copyWith(
        fontSize: KalinkaTypography.baseSize + 1,
        height: 1.45,
        color: text.isEmpty
            ? KalinkaColors.textMuted
            : KalinkaColors.textPrimary,
      ),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        // One surface step above the parent card so the read-only block
        // reads as inset content, not an editable input.
        color: KalinkaColors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: KalinkaColors.borderSubtle),
      ),
      child: leadingIcon == null
          ? body
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1, right: 8),
                  child: Icon(
                    leadingIcon,
                    size: 16,
                    color: leadingIconColor ?? KalinkaColors.textMuted,
                  ),
                ),
                Expanded(child: body),
              ],
            ),
    );
  }
}

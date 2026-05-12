import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'inline_markdown.dart';

/// Tinted note displayed above cards or inside module bodies to surface
/// errors and warnings.
///
/// Severity controls the tint (amber for warnings, red for errors).
/// Message accepts the same minimal markdown as `InlineMarkdown`
/// (`**bold**`, `` `code` ``) so backend status messages render with
/// emphasis intact.
enum WarningNoteSeverity { warning, error }

class WarningNote extends StatelessWidget {
  final String message;
  final WarningNoteSeverity severity;

  const WarningNote({
    super.key,
    required this.message,
    this.severity = WarningNoteSeverity.error,
  });

  @override
  Widget build(BuildContext context) {
    final tint = switch (severity) {
      WarningNoteSeverity.warning => KalinkaColors.statusPending,
      WarningNoteSeverity.error => KalinkaColors.statusOffline,
    };

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tint.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: KalinkaColors.goldSubtle.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.warning_amber_outlined,
              size: 24,
              color: tint,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: InlineMarkdown(
              text: message,
              style: KalinkaTextStyles.trayRowSublabel.copyWith(
                fontSize: KalinkaTypography.baseSize + 2,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Subtle indexing progress strip pinned below the chip panel. Shows a
/// small muted caption ("Indexing · 45%") and a 2px progress line in the
/// accent colour. The caller supplies a monotonic [progressPct] (0-100);
/// pass null for an indeterminate animation when coverage is unknown.
class IndexerStatusBanner extends StatelessWidget {
  final double? progressPct;

  const IndexerStatusBanner({super.key, required this.progressPct});

  @override
  Widget build(BuildContext context) {
    final pct = progressPct;
    final progress = pct != null ? (pct / 100).clamp(0.0, 1.0) : null;
    final caption = pct != null
        ? 'Indexing · ${pct.toStringAsFixed(0)}%'
        : 'Indexing…';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
          child: Text(
            caption,
            style: KalinkaTextStyles.trackRowSubtitle.copyWith(
              color: KalinkaColors.textMuted,
              fontSize: KalinkaTypography.baseSize - 2,
              letterSpacing: 0.4,
            ),
          ),
        ),
        SizedBox(
          height: 2,
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 2,
            backgroundColor: KalinkaColors.borderSubtle,
            valueColor: const AlwaysStoppedAnimation<Color>(
              KalinkaColors.accent,
            ),
          ),
        ),
      ],
    );
  }
}

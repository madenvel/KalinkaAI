import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Subtle pipeline progress strip pinned below the search header. Shows a
/// small muted caption ("Indexing · 45%", from [IndexerStatusState.caption])
/// and a 2px progress line in the accent colour. The caller supplies a
/// monotonic [progressPct] (0-100), or null for an indeterminate animation.
class IndexerStatusBanner extends StatelessWidget {
  final String caption;
  final double? progressPct;

  const IndexerStatusBanner({
    super.key,
    required this.caption,
    required this.progressPct,
  });

  @override
  Widget build(BuildContext context) {
    final pct = progressPct;
    final progress = pct != null ? (pct / 100).clamp(0.0, 1.0) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
          child: Text(
            caption,
            // Screen readers skip or literalize '·'.
            semanticsLabel: caption.replaceAll(' · ', ', '),
            style: KalinkaTextStyles.pipelineCaption,
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

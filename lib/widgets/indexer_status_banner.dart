import 'package:flutter/material.dart';
import '../data_model/data_model.dart';
import '../theme/app_theme.dart';

/// Thin banner shown atop AI search results while the embedding index is
/// still building. Hidden entirely when the index is complete or unknown.
class IndexerStatusBanner extends StatelessWidget {
  final IndexerStatus status;

  const IndexerStatusBanner({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final pct = status.minCoveragePct;
    final label = pct != null
        ? 'Indexing in progress · ${pct.toStringAsFixed(0)}%'
        : 'Indexing in progress — AI results may be incomplete';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: KalinkaColors.surfaceInput,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: KalinkaColors.borderSubtle, width: 1),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.hourglass_bottom,
            size: 14,
            color: KalinkaColors.gold,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: KalinkaTextStyles.trackRowSubtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

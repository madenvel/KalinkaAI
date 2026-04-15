import 'package:flutter/material.dart';

import '../../data_model/data_model.dart';
import '../../theme/app_theme.dart';

/// Monospace line showing result counts: "3 artists · 8 albums · 12 tracks".
class ResultsCountLine extends StatelessWidget {
  final Map<SearchType, int> counts;

  const ResultsCountLine({super.key, required this.counts});

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];
    final artistCount = counts[SearchType.artist] ?? 0;
    final albumCount = counts[SearchType.album] ?? 0;
    final trackCount = counts[SearchType.track] ?? 0;
    final playlistCount = counts[SearchType.playlist] ?? 0;

    if (artistCount > 0) parts.add('$artistCount artists');
    if (albumCount > 0) parts.add('$albumCount albums');
    if (trackCount > 0) parts.add('$trackCount tracks');
    if (playlistCount > 0) parts.add('$playlistCount playlists');

    if (parts.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Text(
        parts.join(' \u00B7 '),
        style: KalinkaTextStyles.resultCountHint,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data_model/data_model.dart';
import '../../providers/selection_state_provider.dart';
import '../../theme/app_theme.dart';
import '../search/track_group_actions.dart';
import 'track_row_support.dart';

/// Header shown at the top of an unrolled album, playlist or collection: an
/// info line (track count · duration · tap-to-play reminder) over the Play
/// all / Enqueue pair, acting on the container as a whole. The same two chips
/// a section of results carries, so one action reads the same everywhere.
///
/// Hidden while multi-select is active so it can't be confused with the
/// selection actions.
class ContainerActionHeader extends ConsumerWidget {
  /// The album, playlist or collection this header plays/enqueues. It goes to
  /// the server as one id, which the server expands into its tracks.
  final BrowseItem item;
  final int trackCount;
  final int? totalDurationSeconds;

  const ContainerActionHeader({
    super.key,
    required this.item,
    required this.trackCount,
    this.totalDurationSeconds,
  });

  String get _name =>
      item.album?.title ?? item.playlist?.name ?? item.name ?? 'Unknown';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectionMode = ref.watch(
      selectionStateProvider.select((s) => s.isActive),
    );
    if (selectionMode) return const SizedBox.shrink();

    final duration = totalDurationSeconds;
    final info = <String>[
      '$trackCount ${trackCount == 1 ? 'track' : 'tracks'}',
      if (duration != null && duration > 0) formatTotalDuration(duration),
      'tap a track to play from there',
    ];

    return SizedBox(
      // The header is content-sized, so without this it would be centred by
      // whatever column holds it rather than starting where the tracks do.
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              info.join(' · '),
              style: KalinkaTextStyles.trackRowSubtitle.copyWith(
                color: KalinkaColors.textMuted,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                PlayAllChip(trackIds: [item.id], trackCount: trackCount),
                AddAllChip(
                  trackIds: [item.id],
                  trackCount: trackCount,
                  name: _name,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

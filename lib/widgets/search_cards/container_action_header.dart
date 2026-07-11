import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data_model/data_model.dart';
import '../../providers/kalinka_player_api_provider.dart';
import '../../providers/selection_state_provider.dart';
import '../../providers/toast_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/haptics.dart';
import 'action_pill_button.dart';
import 'track_row_support.dart';

/// Header shown at the top of an unrolled album/playlist: an info line
/// (track count · duration · tap-to-play reminder) and a Play / Add to queue
/// action row that acts on the container as a whole. Hidden while multi-select
/// is active so it can't be confused with the selection actions.
class ContainerActionHeader extends ConsumerStatefulWidget {
  /// The album or playlist this header plays/enqueues.
  final BrowseItem item;
  final int trackCount;
  final int? totalDurationSeconds;

  const ContainerActionHeader({
    super.key,
    required this.item,
    required this.trackCount,
    this.totalDurationSeconds,
  });

  @override
  ConsumerState<ContainerActionHeader> createState() =>
      _ContainerActionHeaderState();
}

enum _AddStatus { idle, busy, added }

class _ContainerActionHeaderState extends ConsumerState<ContainerActionHeader> {
  bool _playBusy = false;
  _AddStatus _addStatus = _AddStatus.idle;

  String get _name =>
      widget.item.album?.title ??
      widget.item.playlist?.name ??
      widget.item.name ??
      'Unknown';

  Future<void> _play() async {
    if (_playBusy) return;
    setState(() => _playBusy = true);
    KalinkaHaptics.mediumImpact();
    final api = ref.read(kalinkaProxyProvider);
    await runQueueActivity(
      pending: 'Starting playback…',
      action: () async {
        await api.clear();
        final added = await api.add([widget.item.id]);
        await api.play(0);
        return added;
      },
      done: (r) {
        final n = r.count ?? widget.trackCount;
        return 'Playing $n ${n == 1 ? 'track' : 'tracks'}';
      },
      failed: (e) => 'Failed to play: $e',
    );
    if (mounted) setState(() => _playBusy = false);
  }

  Future<void> _addToQueue() async {
    if (_addStatus != _AddStatus.idle) return;
    setState(() => _addStatus = _AddStatus.busy);
    KalinkaHaptics.mediumImpact();
    final api = ref.read(kalinkaProxyProvider);
    final name = _name;
    await runQueueActivity(
      pending: 'Adding to queue…',
      action: () => api.add([widget.item.id]),
      done: (r) {
        final n = r.count ?? widget.trackCount;
        return '$name — $n ${n == 1 ? 'track' : 'tracks'} added to queue';
      },
      failed: (e) => 'Failed to add: $e',
    );
    if (!mounted) return;
    setState(() => _addStatus = _AddStatus.added);
    await Future<void>.delayed(const Duration(seconds: 3));
    if (mounted) setState(() => _addStatus = _AddStatus.idle);
  }

  @override
  Widget build(BuildContext context) {
    final selectionMode = ref.watch(
      selectionStateProvider.select((s) => s.isActive),
    );
    if (selectionMode) return const SizedBox.shrink();

    final n = widget.trackCount;
    final duration = widget.totalDurationSeconds;
    final infoParts = <String>[
      '$n ${n == 1 ? 'track' : 'tracks'}',
      if (duration != null && duration > 0) formatTotalDuration(duration),
      'tap a track to play from there',
    ];
    final added = _addStatus == _AddStatus.added;
    final addBusy = _addStatus == _AddStatus.busy;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            infoParts.join(' · '),
            style: KalinkaTextStyles.trackRowSubtitle.copyWith(
              color: KalinkaColors.textMuted,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ActionPillButton(
                label: _playBusy ? 'Starting…' : 'Play',
                icon: Icons.play_arrow_rounded,
                accent: true,
                enabled: !_playBusy,
                onTap: _play,
                semanticsLabel: 'Play $_name from the first track',
              ),
              const SizedBox(width: 8),
              ActionPillButton(
                label: added
                    ? 'Added'
                    : addBusy
                    ? 'Adding…'
                    : 'Add to queue',
                icon: added ? Icons.check_rounded : Icons.playlist_add_rounded,
                enabled: _addStatus == _AddStatus.idle,
                onTap: _addToQueue,
                foregroundOverride: added ? KalinkaColors.gold : null,
                borderOverride: added
                    ? KalinkaColors.gold.withValues(alpha: 0.4)
                    : null,
                semanticsLabel: added
                    ? 'Added to queue'
                    : 'Add $_name to queue',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

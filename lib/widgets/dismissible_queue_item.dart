import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data_model/data_model.dart';
import '../providers/kalinka_player_api_provider.dart';
import 'queue_list.dart';

/// Wraps a QueueListItem in a Dismissible for swipe-to-delete.
class DismissibleQueueItem extends ConsumerWidget {
  final Track track;
  final int index;
  final bool isCurrentTrack;

  const DismissibleQueueItem({
    super.key,
    required this.track,
    required this.index,
    required this.isCurrentTrack,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Dismissible(
      key: ValueKey('dismiss_${track.id}_$index'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: Colors.red.shade700,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) {
        final api = ref.read(kalinkaProxyProvider);
        api.remove(index);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Removed "${track.title}"',
              style: TextStyle(color: theme.colorScheme.onSurface),
            ),
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
        );
      },
      child: QueueListItem(
        track: track,
        index: index,
        isCurrentTrack: isCurrentTrack,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/selection_state_provider.dart';
import '../providers/kalinka_player_api_provider.dart';

/// Floating bottom bar shown during multi-select mode.
/// Displays count of selected items and an "Add to Queue" action.
class SelectionActionBar extends ConsumerWidget {
  const SelectionActionBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(selectionStateProvider);
    final theme = Theme.of(context);

    return AnimatedSlide(
      offset: selection.isActive ? Offset.zero : const Offset(0, 1),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      child: AnimatedOpacity(
        opacity: selection.isActive ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 250),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    ref
                        .read(selectionStateProvider.notifier)
                        .exitSelectionMode();
                  },
                  tooltip: 'Cancel selection',
                ),
                const SizedBox(width: 8),
                Text(
                  '${selection.count} selected',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: selection.count > 0
                      ? () => _addToQueue(context, ref, selection.selectedIds)
                      : null,
                  icon: const Icon(Icons.playlist_add),
                  label: Text('Add ${selection.count} to Queue'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _addToQueue(
    BuildContext context,
    WidgetRef ref,
    Set<String> ids,
  ) async {
    try {
      final api = ref.read(kalinkaProxyProvider);
      await api.add(ids.toList());

      ref.read(selectionStateProvider.notifier).exitSelectionMode();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added ${ids.length} item(s) to queue'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to add to queue: $e')));
      }
    }
  }
}

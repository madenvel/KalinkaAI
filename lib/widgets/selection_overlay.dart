import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/selection_state_provider.dart';
import '../providers/kalinka_player_api_provider.dart';
import '../theme/app_theme.dart';

/// Top bar shown during multi-select mode.
/// Cancel | "N selected" | Select all
class MultiSelectTopBar extends ConsumerWidget {
  final Iterable<String>? allItemIds;

  const MultiSelectTopBar({super.key, this.allItemIds});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(selectionStateProvider);

    return AnimatedSlide(
      offset: selection.isActive ? Offset.zero : const Offset(0, -1),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOutQuart,
      child: AnimatedOpacity(
        opacity: selection.isActive ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 280),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: KalinkaColors.headerSurface,
            border: const Border(
              bottom: BorderSide(color: KalinkaColors.borderElevated, width: 1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Cancel
              GestureDetector(
                onTap: () {
                  ref.read(selectionStateProvider.notifier).exitSelectionMode();
                },
                child: Text(
                  'Cancel',
                  style: GoogleFonts.ibmPlexMono(
                    fontSize: 13,
                    color: KalinkaColors.textSecondary,
                  ),
                ),
              ),
              const Spacer(),
              // N selected
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '${selection.count}',
                      style: GoogleFonts.ibmPlexMono(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: KalinkaColors.accent,
                      ),
                    ),
                    TextSpan(
                      text: ' selected',
                      style: GoogleFonts.ibmPlexMono(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: KalinkaColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // Select all
              GestureDetector(
                onTap: () {
                  if (allItemIds != null) {
                    ref
                        .read(selectionStateProvider.notifier)
                        .selectAll(allItemIds!);
                  }
                },
                child: Text(
                  'Select all',
                  style: GoogleFonts.ibmPlexMono(
                    fontSize: 13,
                    color: KalinkaColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom batch bar shown during multi-select mode.
/// "N TRACKS SELECTED" label, Append and Play next buttons.
class MultiSelectBottomBar extends ConsumerWidget {
  const MultiSelectBottomBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(selectionStateProvider);

    return AnimatedSlide(
      offset: selection.isActive ? Offset.zero : const Offset(0, 1),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutQuart,
      child: AnimatedOpacity(
        opacity: selection.isActive ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: BoxDecoration(
            color: KalinkaColors.inputSurface,
            border: const Border(
              top: BorderSide(color: KalinkaColors.borderElevated, width: 1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Label
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '${selection.count} TRACKS SELECTED',
                    style: KalinkaTextStyles.batchBarLabel,
                  ),
                ),
                // Two buttons
                Row(
                  children: [
                    // Append
                    Expanded(
                      child: GestureDetector(
                        onTap: selection.count > 0
                            ? () => _appendToQueue(context, ref, selection)
                            : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: selection.count > 0
                                  ? KalinkaColors.gold
                                  : KalinkaColors.gold.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.playlist_add,
                                size: 16,
                                color: KalinkaColors.gold,
                              ),
                              const SizedBox(width: 6),
                              Column(
                                children: [
                                  Text(
                                    'Append',
                                    style: GoogleFonts.ibmPlexMono(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: KalinkaColors.gold,
                                    ),
                                  ),
                                  Text(
                                    'add to end',
                                    style:
                                        KalinkaTextStyles.aiTrackChipDuration,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Play next
                    Expanded(
                      child: GestureDetector(
                        onTap: selection.count > 0
                            ? () => _playNext(context, ref, selection)
                            : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: selection.count > 0
                                  ? KalinkaColors.accent
                                  : KalinkaColors.accent.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.queue_music,
                                size: 16,
                                color: KalinkaColors.accent,
                              ),
                              const SizedBox(width: 6),
                              Column(
                                children: [
                                  Text(
                                    'Play next',
                                    style: GoogleFonts.ibmPlexMono(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: KalinkaColors.accent,
                                    ),
                                  ),
                                  Text(
                                    'after current',
                                    style:
                                        KalinkaTextStyles.aiTrackChipDuration,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _appendToQueue(
    BuildContext context,
    WidgetRef ref,
    SelectionState selection,
  ) async {
    try {
      final api = ref.read(kalinkaProxyProvider);
      final ids = ref.read(selectionStateProvider.notifier).resolveIdsForApi();
      await api.add(ids);

      ref.read(selectionStateProvider.notifier).exitSelectionMode();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${selection.count} tracks appended'),
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

  Future<void> _playNext(
    BuildContext context,
    WidgetRef ref,
    SelectionState selection,
  ) async {
    try {
      final api = ref.read(kalinkaProxyProvider);
      final ids = ref.read(selectionStateProvider.notifier).resolveIdsForApi();
      await api.add(ids);

      ref.read(selectionStateProvider.notifier).exitSelectionMode();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${selection.count} tracks playing next'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to add: $e')));
      }
    }
  }
}

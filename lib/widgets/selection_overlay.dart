import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/selection_state_provider.dart';
import '../providers/kalinka_player_api_provider.dart';
import '../providers/toast_provider.dart';
import '../theme/app_theme.dart';
import '../utils/haptics.dart';

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
                  KalinkaHaptics.lightImpact();
                  ref.read(selectionStateProvider.notifier).exitSelectionMode();
                },
                child: Text(
                  'Done',
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
                        color: KalinkaColors.accentTint,
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
                  KalinkaHaptics.lightImpact();
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
                // Three buttons: Play now | Play next | Add to queue
                Row(
                  children: [
                    // Play now
                    Expanded(
                      child: GestureDetector(
                        onTap: selection.count > 0
                            ? () {
                                KalinkaHaptics.mediumImpact();
                                _playNow(context, ref, selection);
                              }
                            : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: KalinkaColors.confirmGreen.withValues(
                              alpha: 0.1,
                            ),
                            border: Border.all(
                              color: selection.count > 0
                                  ? KalinkaColors.confirmGreen
                                  : KalinkaColors.confirmGreen.withValues(
                                      alpha: 0.3,
                                    ),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.play_arrow,
                                size: 16,
                                color: KalinkaColors.confirmGreen,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Play now',
                                style: GoogleFonts.ibmPlexMono(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: KalinkaColors.confirmGreen,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Play next
                    Expanded(
                      child: GestureDetector(
                        onTap: selection.count > 0
                            ? () {
                                KalinkaHaptics.mediumImpact();
                                _playNext(context, ref, selection);
                              }
                            : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: KalinkaColors.gold.withValues(alpha: 0.1),
                            border: Border.all(
                              color: selection.count > 0
                                  ? KalinkaColors.gold
                                  : KalinkaColors.gold.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.arrow_upward,
                                size: 16,
                                color: KalinkaColors.gold,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Play next',
                                style: GoogleFonts.ibmPlexMono(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: KalinkaColors.gold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Add to queue
                    Expanded(
                      child: GestureDetector(
                        onTap: selection.count > 0
                            ? () {
                                KalinkaHaptics.mediumImpact();
                                _appendToQueue(context, ref, selection);
                              }
                            : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: KalinkaColors.pillSurface,
                            border: Border.all(
                              color: KalinkaColors.borderElevated,
                              width: 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.playlist_add,
                                size: 16,
                                color: KalinkaColors.textSecondary,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Add to queue',
                                style: GoogleFonts.ibmPlexMono(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: KalinkaColors.textSecondary,
                                ),
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
      ref.read(toastProvider.notifier).show('${selection.count} tracks added to queue');
    } catch (e) {
      ref.read(toastProvider.notifier).show('Failed to add to queue: $e', isError: true);
    }
  }

  Future<void> _playNow(
    BuildContext context,
    WidgetRef ref,
    SelectionState selection,
  ) async {
    try {
      final api = ref.read(kalinkaProxyProvider);
      final ids = ref.read(selectionStateProvider.notifier).resolveIdsForApi();
      await api.clear();
      await api.add(ids);
      await api.play();
      ref.read(selectionStateProvider.notifier).exitSelectionMode();
      ref.read(toastProvider.notifier).show('Playing ${selection.count} tracks');
    } catch (e) {
      ref.read(toastProvider.notifier).show('Failed to play: $e', isError: true);
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
      ref.read(toastProvider.notifier).show('${selection.count} tracks playing next');
    } catch (e) {
      ref.read(toastProvider.notifier).show('Failed to add: $e', isError: true);
    }
  }
}

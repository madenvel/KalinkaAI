import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_state_provider.dart';
import '../providers/search_state_provider.dart';
import '../theme/app_theme.dart';
import 'kalinka_search_bar.dart';

/// Header zone with full-width search bar.
///
/// In search mode the bar grows to 54px and the back-chevron leading icon
/// appears. The connection dot, AI toggle, and mic live inside the search bar.
class HeaderZone extends ConsumerStatefulWidget {
  final VoidCallback? onServerChipTap;
  final GlobalKey<KalinkaSearchBarState>? searchBarKey;

  const HeaderZone({super.key, this.onServerChipTap, this.searchBarKey});

  @override
  ConsumerState<HeaderZone> createState() => _HeaderZoneState();
}

class _HeaderZoneState extends ConsumerState<HeaderZone>
    with TickerProviderStateMixin {
  static const _chevronRevealDelay = Duration(milliseconds: 120);
  static const _collapsedInset = 10.0;

  late GlobalKey<KalinkaSearchBarState> _searchBarKey;
  Timer? _chevronTimer;
  bool _showDelayedChevron = false;

  @override
  void initState() {
    super.initState();
    _searchBarKey = widget.searchBarKey ?? GlobalKey<KalinkaSearchBarState>();
  }

  @override
  void dispose() {
    _chevronTimer?.cancel();
    super.dispose();
  }

  void _onSearchActivated() {
    ref.read(searchStateProvider.notifier).activateSearch();
  }

  void _dismissSearch() {
    final barState = _searchBarKey.currentState;
    if (barState != null && barState.isEditingFromResults) {
      barState.cancelSearch();
      return;
    }

    barState?.cancelSearch();
    ref.read(searchStateProvider.notifier).deactivateSearch();
  }

  @override
  Widget build(BuildContext context) {
    final searchActive = ref.watch(searchStateProvider).searchActive;
    // Suppress unused-provider warning — queue emptiness no longer drives glow.
    ref.watch(playQueueStateStoreProvider.select((s) => s.trackList.isEmpty));

    ref.listen<SearchState>(searchStateProvider, (previous, next) {
      final wasActive = previous?.searchActive ?? false;
      final isActive = next.searchActive;

      if (!wasActive && isActive) {
        _chevronTimer?.cancel();
        setState(() => _showDelayedChevron = false);
        _chevronTimer = Timer(_chevronRevealDelay, () {
          if (!mounted) return;
          setState(() => _showDelayedChevron = true);
        });

        final searchBarState = _searchBarKey.currentState;
        if (searchBarState != null && !searchBarState.isActive) {
          searchBarState.activateFromExternal();
        }
      } else if (wasActive && !isActive) {
        _chevronTimer?.cancel();
        if (_showDelayedChevron) {
          setState(() => _showDelayedChevron = false);
        }
      }
    });

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: searchActive
            ? KalinkaColors.surfaceInput
            : KalinkaColors.surfaceBase,
        border: const Border(
          bottom: BorderSide(
            color: KalinkaColors.borderDefault,
            width: 1,
          ),
        ),
        boxShadow: const [
          BoxShadow(
            offset: Offset(0, 4),
            blurRadius: 24,
            color: Color(0x80000000),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: EdgeInsets.symmetric(
            vertical: searchActive ? 8 : 12,
            horizontal: searchActive ? 0 : 16,
          ),
          child: SizedBox(
            height: 44,
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 200),
                  curve: const Cubic(0.4, 0, 0.2, 1),
                  left: searchActive ? 0 : _collapsedInset,
                  right: searchActive ? 0 : _collapsedInset,
                  top: 0,
                  bottom: 0,
                  child: KalinkaSearchBar(
                    key: _searchBarKey,
                    alwaysExpanded: false,
                    onActivate: _onSearchActivated,
                    onLeadingAction: _dismissSearch,
                    onServerChipTap: widget.onServerChipTap,
                    showBackChevron: searchActive && _showDelayedChevron,
                    fullBleedMode: searchActive,
                    height: searchActive ? 54 : 44,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

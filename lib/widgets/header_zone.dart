import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_state_provider.dart';
import '../providers/connection_state_provider.dart';
import '../providers/search_state_provider.dart';
import '../theme/app_theme.dart';
import 'kalinka_search_bar.dart';
import 'kalinka_wordmark.dart';

/// Header zone with K lettermark, search bar, and connection dot.
///
/// In search mode, the search bar expands to full-width header treatment,
/// the wordmark swaps to a back button, and the connection dot hides.
class HeaderZone extends ConsumerStatefulWidget {
  final VoidCallback? onServerChipTap;
  final GlobalKey<KalinkaSearchBarState>? searchBarKey;

  const HeaderZone({super.key, this.onServerChipTap, this.searchBarKey});

  @override
  ConsumerState<HeaderZone> createState() => _HeaderZoneState();
}

class _HeaderZoneState extends ConsumerState<HeaderZone>
    with TickerProviderStateMixin {
  static const _collapsedLeftInset = 30.0;
  static const _collapsedRightInset = 26.0;
  static const _chevronRevealDelay = Duration(milliseconds: 120);

  late GlobalKey<KalinkaSearchBarState> _searchBarKey;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _searchGlowController;
  late Animation<double> _searchGlowAnimation;
  Timer? _chevronTimer;
  bool _showDelayedChevron = false;

  @override
  void initState() {
    super.initState();
    _searchBarKey = widget.searchBarKey ?? GlobalKey<KalinkaSearchBarState>();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 0.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _searchGlowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _searchGlowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _searchGlowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _chevronTimer?.cancel();
    _pulseController.dispose();
    _searchGlowController.dispose();
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
    final isQueueEmpty = ref.watch(
      playQueueStateStoreProvider.select((s) => s.trackList.isEmpty),
    );
    final connectionState = ref.watch(connectionStateProvider);
    final shouldGlow =
        isQueueEmpty &&
        !searchActive &&
        connectionState == ConnectionStatus.connected;
    if (shouldGlow) {
      if (!_searchGlowController.isAnimating) {
        _searchGlowController.repeat(reverse: true);
      }
    } else {
      if (_searchGlowController.isAnimating) {
        _searchGlowController.stop();
        _searchGlowController.value = 0.0;
      }
    }

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
        border: Border(
          bottom: BorderSide(
            color: searchActive
                ? KalinkaColors.accentBorder
                : KalinkaColors.borderDefault,
            width: searchActive ? 2 : 1,
          ),
        ),
        boxShadow: [
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
            horizontal: searchActive ? 8 : 16,
          ),
          child: SizedBox(
            height: 44,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Row(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: AnimatedOpacity(
                          opacity: searchActive ? 0 : 1,
                          duration: const Duration(milliseconds: 120),
                          curve: Curves.easeIn,
                          child: const IgnorePointer(
                            ignoring: true,
                            child: KalinkaWordmark(),
                          ),
                        ),
                      ),
                      const Spacer(),
                      AnimatedSlide(
                        offset: searchActive
                            ? const Offset(0.25, 0)
                            : Offset.zero,
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOut,
                        child: AnimatedOpacity(
                          opacity: searchActive ? 0 : 1,
                          duration: const Duration(milliseconds: 140),
                          curve: Curves.easeIn,
                          child: IgnorePointer(
                            ignoring: searchActive,
                            child: _buildConnectionDot(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 200),
                  curve: const Cubic(0.4, 0, 0.2, 1),
                  left: searchActive ? 0 : _collapsedLeftInset,
                  right: searchActive ? 0 : _collapsedRightInset,
                  top: 0,
                  bottom: 0,
                  child: Align(
                    alignment: Alignment.center,
                    child: AnimatedBuilder(
                      animation: _searchGlowAnimation,
                      builder: (context, child) {
                        final t = _searchGlowAnimation.value;
                        return DecoratedBox(
                          position: DecorationPosition.foreground,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: KalinkaColors.accent.withValues(
                                alpha: t * 0.50,
                              ),
                              width: 1.5,
                            ),
                          ),
                          child: child!,
                        );
                      },
                      child: KalinkaSearchBar(
                        key: _searchBarKey,
                        alwaysExpanded: false,
                        onActivate: _onSearchActivated,
                        onLeadingAction: _dismissSearch,
                        showBackChevron: searchActive && _showDelayedChevron,
                        fullBleedMode: searchActive,
                        height: searchActive ? 44 : 36,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: searchActive ? 8 : 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionDot() {
    final connectionState = ref.watch(connectionStateProvider);

    // Start/stop pulse based on reconnecting state
    if (connectionState == ConnectionStatus.reconnecting) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      if (_pulseController.isAnimating) {
        _pulseController.stop();
        _pulseController.value = 1.0;
      }
    }

    final color = switch (connectionState) {
      ConnectionStatus.connected => KalinkaColors.statusOnline,
      ConnectionStatus.reconnecting ||
      ConnectionStatus.connecting => KalinkaColors.statusPending,
      ConnectionStatus.offline ||
      ConnectionStatus.none => KalinkaColors.textMuted,
    };

    final semanticsLabel = switch (connectionState) {
      ConnectionStatus.connected =>
        'Server connected. Tap for server settings.',
      ConnectionStatus.reconnecting || ConnectionStatus.connecting =>
        'Reconnecting to server. Tap for server settings.',
      ConnectionStatus.offline => 'Server offline. Tap for server settings.',
      ConnectionStatus.none => 'No server configured. Tap for server settings.',
    };

    Widget dot = Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: connectionState == ConnectionStatus.connected
            ? [BoxShadow(color: color.withValues(alpha: 0.55), blurRadius: 6)]
            : null,
      ),
    );

    if (connectionState == ConnectionStatus.reconnecting ||
        connectionState == ConnectionStatus.connecting) {
      dot = FadeTransition(opacity: _pulseAnimation, child: dot);
    }

    return Semantics(
      label: semanticsLabel,
      button: true,
      child: GestureDetector(
        onTap: widget.onServerChipTap != null
            ? () => widget.onServerChipTap!()
            : null,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Align(alignment: Alignment.centerRight, child: dot),
        ),
      ),
    );
  }
}

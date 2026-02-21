import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/connection_state_provider.dart';
import '../providers/search_state_provider.dart';
import '../theme/app_theme.dart';
import 'kalinka_search_bar.dart';
import 'kalinka_wordmark.dart';
import 'server_chip.dart';

/// Header zone with K lettermark, search bar, and server chip / cancel toggle.
class HeaderZone extends ConsumerStatefulWidget {
  final VoidCallback? onServerChipTap;

  const HeaderZone({super.key, this.onServerChipTap});

  @override
  ConsumerState<HeaderZone> createState() => _HeaderZoneState();
}

class _HeaderZoneState extends ConsumerState<HeaderZone>
    with SingleTickerProviderStateMixin {
  final _searchBarKey = GlobalKey<KalinkaSearchBarState>();
  late AnimationController _crossfadeController;

  @override
  void initState() {
    super.initState();
    _crossfadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
  }

  @override
  void dispose() {
    _crossfadeController.dispose();
    super.dispose();
  }

  void _onSearchActivated() {
    ref.read(searchStateProvider.notifier).activateSearch();
    _crossfadeController.forward();
  }

  void _onCancelTapped() {
    _crossfadeController.reverse();
    _searchBarKey.currentState?.cancelSearch();
    ref.read(searchStateProvider.notifier).deactivateSearch();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: KalinkaColors.headerSurface,
        border: Border(
          bottom: BorderSide(color: KalinkaColors.borderElevated, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            offset: Offset(0, 2),
            blurRadius: 6,
            color: Color(0x40000000),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          child: Row(
            children: [
              const KalinkaWordmark(),
              const SizedBox(width: 10),
              Expanded(
                child: KalinkaSearchBar(
                  key: _searchBarKey,
                  alwaysExpanded: false,
                  onCancel: _onCancelTapped,
                  onActivate: _onSearchActivated,
                ),
              ),
              const SizedBox(width: 10),
              _buildRightSlot(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRightSlot() {
    return AnimatedBuilder(
      animation: _crossfadeController,
      builder: (context, _) {
        final searchActive = _crossfadeController.value > 0;
        final connectionState = ref.watch(connectionStateProvider);
        return AnimatedSize(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          alignment: Alignment.centerRight,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeOut,
            transitionBuilder: (child, animation) =>
                FadeTransition(opacity: animation, child: child),
            child: searchActive
                ? GestureDetector(
                    key: const ValueKey('cancel_slot'),
                    onTap: _onCancelTapped,
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildStateDot(connectionState),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 8,
                          ),
                          child: Text(
                            'Cancel',
                            style: KalinkaTextStyles.cancelButton.copyWith(
                              letterSpacing: -0.13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : ServerChip(
                    key: const ValueKey('server_chip_slot'),
                    onTap: widget.onServerChipTap,
                  ),
          ),
        );
      },
    );
  }

  Widget _buildStateDot(ConnectionStatus state) {
    final color = switch (state) {
      ConnectionStatus.connected => KalinkaColors.statusGreen,
      ConnectionStatus.reconnecting ||
      ConnectionStatus.connecting => KalinkaColors.amber,
      ConnectionStatus.offline => KalinkaColors.statusRed,
      ConnectionStatus.none => KalinkaColors.textMuted,
    };

    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: state == ConnectionStatus.connected
            ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 6)]
            : null,
      ),
    );
  }
}

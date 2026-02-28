import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/connection_state_provider.dart';
import '../providers/search_state_provider.dart';
import '../theme/app_theme.dart';
import 'kalinka_search_bar.dart';
import 'kalinka_wordmark.dart';

/// Header zone with K lettermark, search bar, and connection dot.
///
/// The right slot is always the connection dot — it never changes between
/// search states. Tap the dot to open the server management sheet.
class HeaderZone extends ConsumerStatefulWidget {
  final VoidCallback? onServerChipTap;
  final GlobalKey<KalinkaSearchBarState>? searchBarKey;

  const HeaderZone({super.key, this.onServerChipTap, this.searchBarKey});

  @override
  ConsumerState<HeaderZone> createState() => _HeaderZoneState();
}

class _HeaderZoneState extends ConsumerState<HeaderZone>
    with SingleTickerProviderStateMixin {
  late GlobalKey<KalinkaSearchBarState> _searchBarKey;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

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
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _onSearchActivated() {
    ref.read(searchStateProvider.notifier).activateSearch();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<SearchState>(searchStateProvider, (previous, next) {
      final wasActive = previous?.searchActive ?? false;
      final isActive = next.searchActive;

      if (!wasActive && isActive) {
        final searchBarState = _searchBarKey.currentState;
        if (searchBarState != null && !searchBarState.isActive) {
          searchBarState.activateFromExternal();
        }
      }
    });

    return Container(
      decoration: const BoxDecoration(
        color: KalinkaColors.surfaceBase,
        border: Border(
          bottom: BorderSide(color: KalinkaColors.borderDefault, width: 1),
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
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            children: [
              const KalinkaWordmark(),
              const SizedBox(width: 10),
              Expanded(
                child: KalinkaSearchBar(
                  key: _searchBarKey,
                  alwaysExpanded: false,
                  onActivate: _onSearchActivated,
                ),
              ),
              const SizedBox(width: 10),
              _buildConnectionDot(),
            ],
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
      ConnectionStatus.offline => KalinkaColors.statusError,
      ConnectionStatus.none => KalinkaColors.textMuted,
    };

    final semanticsLabel = switch (connectionState) {
      ConnectionStatus.connected =>
        'Server connected. Tap for server settings.',
      ConnectionStatus.reconnecting ||
      ConnectionStatus.connecting => 'Reconnecting to server. Tap for server settings.',
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
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 17, horizontal: 6),
          child: dot,
        ),
      ),
    );
  }
}

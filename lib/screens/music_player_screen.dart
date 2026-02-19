import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/search_state_provider.dart';
import '../providers/tablet_panel_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/ai_search_sheet.dart';
import '../widgets/expanded_player_overlay.dart';
import '../widgets/header_zone.dart';
import '../widgets/mini_player.dart';
import '../widgets/queue_zone.dart';
import '../widgets/side_panel.dart';

class MusicPlayerScreen extends ConsumerStatefulWidget {
  const MusicPlayerScreen({super.key});

  @override
  ConsumerState<MusicPlayerScreen> createState() => _MusicPlayerScreenState();
}

class _MusicPlayerScreenState extends ConsumerState<MusicPlayerScreen>
    with TickerProviderStateMixin {
  static const _tabletBreakpoint = 900.0;

  late AnimationController _playerController;
  late AnimationController _searchController;

  bool _playerOpen = false;
  bool _searchOpen = false;

  @override
  void initState() {
    super.initState();
    _playerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _searchController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    _playerController.addStatusListener((status) {
      if (status == AnimationStatus.dismissed) {
        setState(() => _playerOpen = false);
      }
    });
    _searchController.addStatusListener((status) {
      if (status == AnimationStatus.dismissed) {
        setState(() => _searchOpen = false);
      }
    });
  }

  @override
  void dispose() {
    _playerController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _openPlayer() {
    setState(() => _playerOpen = true);
    _playerController.forward();
  }

  void _closePlayer() {
    _playerController.reverse();
  }

  void _openSearch() {
    setState(() => _searchOpen = true);
    _searchController.forward();
  }

  void _closeSearch() {
    _searchController.reverse();
    ref.read(searchStateProvider.notifier).resetExpansions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KalinkaColors.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isTablet = constraints.maxWidth >= _tabletBreakpoint;
          return isTablet
              ? _buildTabletLayout(context)
              : _buildPhoneLayout(context);
        },
      ),
    );
  }

  Widget _buildPhoneLayout(BuildContext context) {
    return PopScope(
      canPop: !_searchOpen && !_playerOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_searchOpen) {
          _closeSearch();
        } else if (_playerOpen) {
          _closePlayer();
        }
      },
      child: Stack(
        children: [
          // Main content: Header + Queue + MiniPlayer
          Column(
            children: [
              HeaderZone(onSearchTap: _openSearch),
              const Expanded(child: QueueZone()),
              MiniPlayer(onTap: _openPlayer),
            ],
          ),
          // Expanded player overlay
          if (_playerOpen)
            Positioned.fill(
              child: ExpandedPlayerOverlay(
                animationController: _playerController,
                onClose: _closePlayer,
              ),
            ),
          // AI search sheet overlay
          if (_searchOpen)
            Positioned.fill(
              child: AiSearchSheet(
                animationController: _searchController,
                onClose: _closeSearch,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTabletLayout(BuildContext context) {
    return Stack(
      children: [
        Row(
          children: [
            // Left panel: Header + Queue + MiniPlayer
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  HeaderZone(
                    onSearchTap: () {
                      ref.read(tabletPanelProvider.notifier).showSearch();
                    },
                  ),
                  const Expanded(child: QueueZone()),
                  MiniPlayer(onTap: _openPlayer),
                ],
              ),
            ),
            // Divider
            Container(
              width: 1,
              color: KalinkaColors.borderDefault,
            ),
            // Right panel: SidePanel (tabbed search/queue)
            const Expanded(
              flex: 2,
              child: SafeArea(child: SidePanel()),
            ),
          ],
        ),
        // Expanded player overlay (full screen on tablet too)
        if (_playerOpen)
          Positioned.fill(
            child: ExpandedPlayerOverlay(
              animationController: _playerController,
              onClose: _closePlayer,
            ),
          ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/search_state_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/completion_strip.dart';
import '../widgets/expanded_player_overlay.dart';
import '../widgets/first_encounter_prompt.dart';
import '../widgets/header_zone.dart';
import '../widgets/mini_player.dart';
import '../widgets/now_playing_content.dart';
import '../widgets/queue_zone.dart';
import '../widgets/search_results_feed.dart';
import '../widgets/side_panel.dart';

class MusicPlayerScreen extends ConsumerStatefulWidget {
  const MusicPlayerScreen({super.key});

  @override
  ConsumerState<MusicPlayerScreen> createState() => _MusicPlayerScreenState();
}

class _MusicPlayerScreenState extends ConsumerState<MusicPlayerScreen>
    with SingleTickerProviderStateMixin {
  static const _tabletBreakpoint = 900.0;

  late AnimationController _playerController;

  bool _playerOpen = false;

  @override
  void initState() {
    super.initState();
    _playerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );

    _playerController.addStatusListener((status) {
      if (status == AnimationStatus.dismissed) {
        setState(() => _playerOpen = false);
      }
    });
  }

  @override
  void dispose() {
    _playerController.dispose();
    super.dispose();
  }

  void _openPlayer() {
    setState(() => _playerOpen = true);
    _playerController.forward();
  }

  void _closePlayer() {
    _playerController.reverse();
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
    final searchState = ref.watch(searchStateProvider);
    final searchActive = searchState.searchActive;

    return PopScope(
      canPop: !searchActive && !_playerOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final notifier = ref.read(searchStateProvider.notifier);
        final state = ref.read(searchStateProvider);
        if (state.query.isNotEmpty) {
          // Level 1: Clear query (same as ×), stay in search
          notifier.clearQueryMidSession();
        } else if (state.searchActive) {
          // Level 2: Exit search (same as Cancel)
          notifier.deactivateSearch();
        } else if (_playerOpen) {
          _closePlayer();
        }
      },
      child: Stack(
        children: [
          // Main content: Header + CompletionStrip + Content Zone + MiniPlayer
          Column(
            children: [
              const HeaderZone(),
              // Pinned completion strip — only visible during typing
              const CompletionStrip(),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                  child: searchActive
                      ? const SearchResultsFeed(key: ValueKey('search'))
                      : const QueueZone(key: ValueKey('queue')),
                ),
              ),
              const FirstEncounterPrompt(),
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
        ],
      ),
    );
  }

  Widget _buildTabletLayout(BuildContext context) {
    return Row(
      children: [
        // Left panel: Now Playing (always visible)
        const Expanded(child: SafeArea(child: NowPlayingContent())),
        // Divider
        Container(width: 1, color: KalinkaColors.borderDefault),
        // Right panel: SidePanel (tabbed search/queue)
        const Expanded(child: SafeArea(child: SidePanel())),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/connection_settings_provider.dart';
import '../providers/search_state_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/completion_strip.dart';
import '../widgets/connection_banner.dart';
import '../widgets/discovery_screen.dart';
import '../widgets/escalation_card.dart';
import '../widgets/expanded_player_overlay.dart';
import '../widgets/header_zone.dart';
import '../widgets/mini_player.dart';
import '../widgets/now_playing_content.dart';
import '../widgets/queue_zone.dart';
import '../widgets/search_results_feed.dart';
import '../widgets/server_sheet.dart';
import '../widgets/settings_screen.dart';
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

  bool _playerOpen = false;
  bool _serverSheetOpen = false;
  bool _discoveryOpen = false;
  bool _settingsOpen = false;

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

    // Check for first launch — no stored server
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = ref.read(connectionSettingsProvider);
      if (!settings.isSet) {
        setState(() => _discoveryOpen = true);
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
    final settings = ref.watch(connectionSettingsProvider);

    return PopScope(
      canPop:
          !searchActive && !_playerOpen && !_serverSheetOpen && !_settingsOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_settingsOpen) {
          setState(() => _settingsOpen = false);
          return;
        }
        if (_serverSheetOpen) {
          setState(() => _serverSheetOpen = false);
          return;
        }
        final notifier = ref.read(searchStateProvider.notifier);
        final state = ref.read(searchStateProvider);
        if (state.query.isNotEmpty) {
          notifier.clearQueryMidSession();
        } else if (state.searchActive) {
          notifier.deactivateSearch();
        } else if (_playerOpen) {
          _closePlayer();
        }
      },
      child: Stack(
        children: [
          // Main content: Header + Banner + CompletionStrip + Content Zone + Escalation + MiniPlayer
          Column(
            children: [
              HeaderZone(
                onServerChipTap: () {
                  setState(() => _serverSheetOpen = true);
                },
              ),
              const ConnectionBanner(),
              // Pinned completion strip — only visible during typing
              const CompletionStrip(),
              Expanded(
                child: Stack(
                  children: [
                    // Queue (always rendered, dims when search active)
                    AnimatedOpacity(
                      opacity: searchActive ? 0.4 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      child: const QueueZone(),
                    ),
                    // Scrim overlay
                    if (searchActive)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: AnimatedOpacity(
                            opacity: searchActive ? 1.0 : 0.0,
                            duration: Duration(
                              milliseconds: searchActive ? 200 : 180,
                            ),
                            curve: Curves.easeOut,
                            child: const ColoredBox(color: Color(0x66000000)),
                          ),
                        ),
                      ),
                    // Search results (slide up + fade)
                    if (searchActive)
                      AnimatedSlide(
                        offset: searchActive
                            ? Offset.zero
                            : const Offset(0, 0.03),
                        duration: Duration(
                          milliseconds: searchActive ? 240 : 180,
                        ),
                        curve: searchActive
                            ? const Cubic(0.4, 0, 0.2, 1)
                            : Curves.easeIn,
                        child: AnimatedOpacity(
                          opacity: searchActive ? 1.0 : 0.0,
                          duration: Duration(
                            milliseconds: searchActive ? 240 : 180,
                          ),
                          curve: searchActive ? Curves.easeOut : Curves.easeIn,
                          child: const ColoredBox(
                            color: KalinkaColors.background,
                            child: SearchResultsFeed(),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              EscalationCard(
                onScanForServers: () {
                  setState(() => _discoveryOpen = true);
                },
              ),
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
          // Server sheet overlay
          if (_serverSheetOpen)
            Positioned.fill(
              child: ServerSheet(
                onClose: () => setState(() => _serverSheetOpen = false),
                onOpenDiscovery: () {
                  setState(() => _discoveryOpen = true);
                },
                onOpenSettings: () {
                  setState(() => _settingsOpen = true);
                },
              ),
            ),
          // Discovery screen overlay
          if (_discoveryOpen)
            Positioned.fill(
              child: DiscoveryScreen(
                allowCancel: settings.isSet,
                currentServerHost: settings.isSet ? settings.host : null,
                onClose: () => setState(() => _discoveryOpen = false),
              ),
            ),
          // Settings screen overlay
          if (_settingsOpen)
            Positioned.fill(
              child: SettingsScreen(
                onClose: () => setState(() => _settingsOpen = false),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTabletLayout(BuildContext context) {
    final settings = ref.watch(connectionSettingsProvider);

    return Stack(
      children: [
        Row(
          children: [
            // Left panel: Now Playing with local overlays
            Expanded(
              child: Stack(
                children: [
                  SafeArea(
                    child: NowPlayingContent(
                      isTablet: true,
                      onServerChipTap: () {
                        setState(() => _serverSheetOpen = true);
                      },
                    ),
                  ),
                  // Server sheet overlay (left panel only)
                  if (_serverSheetOpen)
                    Positioned.fill(
                      child: ServerSheet(
                        onClose: () => setState(() => _serverSheetOpen = false),
                        onOpenDiscovery: () {
                          setState(() => _discoveryOpen = true);
                        },
                        onOpenSettings: () {
                          setState(() => _settingsOpen = true);
                        },
                      ),
                    ),
                  // Settings screen overlay (left panel only)
                  if (_settingsOpen)
                    Positioned.fill(
                      child: SettingsScreen(
                        onClose: () => setState(() => _settingsOpen = false),
                      ),
                    ),
                ],
              ),
            ),
            // Divider
            Container(width: 1, color: KalinkaColors.borderDefault),
            // Right panel: SidePanel (tabbed search/queue)
            const Expanded(child: SafeArea(child: SidePanel())),
          ],
        ),
        // Discovery screen overlay (full screen)
        if (_discoveryOpen)
          Positioned.fill(
            child: DiscoveryScreen(
              allowCancel: settings.isSet,
              currentServerHost: settings.isSet ? settings.host : null,
              onClose: () => setState(() => _discoveryOpen = false),
            ),
          ),
      ],
    );
  }
}

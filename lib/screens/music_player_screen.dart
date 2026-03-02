import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/connection_settings_provider.dart';
import '../providers/connection_state_provider.dart';
import '../providers/search_state_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/completion_strip.dart';
import '../widgets/connection_banner.dart';
import '../widgets/discovery_screen.dart';
import '../widgets/escalation_card.dart';
import '../widgets/expanded_player_overlay.dart';
import '../widgets/header_zone.dart';
import '../widgets/kalinka_search_bar.dart';
import '../widgets/mini_player.dart';
import '../widgets/now_playing_content.dart';
import '../widgets/queue_zone.dart';
import '../widgets/search_results_feed.dart';
import '../widgets/server_sheet.dart';
import '../widgets/settings_screen.dart';
import '../widgets/kalinka_toast_overlay.dart';
import '../widgets/side_panel.dart';
import '../providers/media_notification_provider.dart';

class MusicPlayerScreen extends ConsumerStatefulWidget {
  const MusicPlayerScreen({super.key});

  @override
  ConsumerState<MusicPlayerScreen> createState() => _MusicPlayerScreenState();
}

class _MusicPlayerScreenState extends ConsumerState<MusicPlayerScreen>
    with TickerProviderStateMixin {
  static const _tabletBreakpoint = 900.0;

  late AnimationController _playerController;
  final _searchBarKey = GlobalKey<KalinkaSearchBarState>();

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
    _playerController.animateTo(
      1.0,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeInOutQuart,
    );
  }

  void _closePlayer() {
    _playerController.animateTo(
      0.0,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeInOutQuart,
    );
  }

  Widget _buildDisconnectedState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: KalinkaColors.textMuted,
            ),
            const SizedBox(height: 20),
            Text(
              'No server connected',
              style: KalinkaTextStyles.emptyQueueTitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Scan your network to find a Kalinka server and start listening.',
              style: KalinkaTextStyles.emptyQueueSubtitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: () => setState(() => _discoveryOpen = true),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: KalinkaColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: KalinkaColors.accent.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.wifi_tethering_rounded,
                      size: 16,
                      color: KalinkaColors.accentTint,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Scan for servers',
                      style: KalinkaTextStyles.trayRowLabel.copyWith(
                        color: KalinkaColors.accentTint,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(mediaNotificationProvider);
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
    final connectionState = ref.watch(connectionStateProvider);

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
        final barState = _searchBarKey.currentState;
        if (barState != null && barState.isEditingFromResults) {
          // State 3→2 editing: cancel edit, restore committed query → State 3
          barState.cancelSearch();
        } else if (state.searchActive) {
          // State 2 or State 3: always return to State 1 (Ambient)
          barState?.cancelSearch();
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
                searchBarKey: _searchBarKey,
                onServerChipTap: () {
                  setState(() => _serverSheetOpen = true);
                },
              ),
              const ConnectionBanner(),
              // Pinned completion strip — only visible during typing
              const CompletionStrip(),
              Expanded(
                child: connectionState == ConnectionStatus.none
                    ? _buildDisconnectedState()
                    : Stack(
                        children: [
                          // Queue (always rendered, dims when search active)
                          AnimatedOpacity(
                            opacity: searchActive ? 0.4 : 1.0,
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOut,
                            child: const QueueZone(),
                          ),
                          // Scrim overlay — tappable to dismiss search
                          if (searchActive)
                            Positioned.fill(
                              child: GestureDetector(
                                onTap: () {
                                  _searchBarKey.currentState?.cancelSearch();
                                  ref
                                      .read(searchStateProvider.notifier)
                                      .deactivateSearch();
                                },
                                child: AnimatedOpacity(
                                  opacity: searchActive ? 1.0 : 0.0,
                                  duration: Duration(
                                    milliseconds: searchActive ? 200 : 180,
                                  ),
                                  curve: Curves.easeOut,
                                  child: const ColoredBox(
                                    color: Color(0x66000000),
                                  ),
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
                                curve: searchActive
                                    ? Curves.easeOut
                                    : Curves.easeIn,
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
          // Toast overlay — floats above MiniPlayer, ignores pointer input
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(child: KalinkaToastOverlay()),
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
            Container(width: 1, color: KalinkaColors.borderSubtle),
            // Right panel: SidePanel (tabbed search/queue)
            const Expanded(child: SafeArea(child: SidePanel())),
          ],
        ),
        // Toast overlay — bottom-right corner on tablet
        const Positioned(
          right: 20,
          bottom: 20,
          child: IgnorePointer(
            child: SizedBox(
              width: 300,
              child: KalinkaToastOverlay(isTablet: true),
            ),
          ),
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_state_provider.dart';
import '../providers/connection_settings_provider.dart';
import '../providers/connection_state_provider.dart';
import '../providers/kalinka_player_api_provider.dart';
import '../providers/search_state_provider.dart';
import '../providers/toast_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/clear_all_confirm_dialog.dart';
import '../widgets/completion_strip.dart';
import '../widgets/connection_banner.dart';
import '../widgets/discovery_screen.dart';
import '../widgets/escalation_card.dart';
import '../widgets/expanded_player_overlay.dart';
import '../widgets/header_zone.dart';
import '../widgets/kalinka_search_bar.dart';
import '../widgets/mini_player.dart';
import '../widgets/now_playing_content.dart';
import '../widgets/queue_management_tray.dart';
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
  bool _playerFullyOpen = false;
  bool _serverSheetOpen = false;
  bool _discoveryOpen = false;
  bool _settingsOpen = false;
  bool _queueTrayOpen = false;
  bool _clearAllConfirmOpen = false;

  @override
  void initState() {
    super.initState();
    _playerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    // Hide the base content when the player covers ≥98% of the screen.
    // Using a value listener + threshold (not status) avoids a brief queue
    // flash when the user starts dragging the player handle and snaps back:
    // status changes immediately on any value change, but the threshold
    // requires a meaningful drag before exposing the base.
    _playerController.addListener(() {
      final shouldHide = _playerController.value >= 0.98;
      if (shouldHide != _playerFullyOpen) {
        setState(() => _playerFullyOpen = shouldHide);
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
    if (_playerController.value == 0.0) {
      setState(() => _playerOpen = false);
      return;
    }
    _playerController
        .animateTo(
          0.0,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeInOutQuart,
        )
        .then((_) {
          if (mounted) setState(() => _playerOpen = false);
        });
  }

  Future<void> _clearPlayed() async {
    final queueState = ref.read(playQueueStateStoreProvider);
    final currentIndex = queueState.playbackState.index ?? 0;
    final api = ref.read(kalinkaProxyProvider);
    final toast = ref.read(toastProvider.notifier);
    for (int i = currentIndex - 1; i >= 0; i--) {
      try {
        await api.remove(i);
      } catch (e) {
        toast.show('Failed to clear played: $e', isError: true);
        return;
      }
    }
    toast.show('Played tracks cleared');
  }

  Future<void> _clearAll() async {
    final api = ref.read(kalinkaProxyProvider);
    final toast = ref.read(toastProvider.notifier);
    await api.clear();
    toast.show('Queue cleared');
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
    ref.read(mediaNotificationProvider);
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
    final hideBase = _playerFullyOpen || _discoveryOpen || _settingsOpen;

    return PopScope(
      canPop:
          !searchActive &&
          !_playerOpen &&
          !_serverSheetOpen &&
          !_settingsOpen &&
          !_queueTrayOpen &&
          !_clearAllConfirmOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_clearAllConfirmOpen) {
          setState(() => _clearAllConfirmOpen = false);
          return;
        }
        if (_queueTrayOpen) {
          setState(() => _queueTrayOpen = false);
          return;
        }
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
          // Tickers stopped and painting skipped when a fully-opaque overlay covers it.
          // Opacity(0) is used (not Offstage/Visibility) so the Column keeps its natural size
          // and the Stack doesn't collapse, which would hide the overlays above it.
          TickerMode(
            enabled: !hideBase,
            child: Opacity(
              opacity: hideBase ? 0.0 : 1.0,
              child: Column(
                children: [
                  RepaintBoundary(
                    child: HeaderZone(
                      searchBarKey: _searchBarKey,
                      onServerChipTap: () {
                        setState(() => _serverSheetOpen = true);
                      },
                    ),
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
                                child: RepaintBoundary(
                                  child: QueueZone(
                                    onOpenManagementTray: () =>
                                        setState(() => _queueTrayOpen = true),
                                  ),
                                ),
                              ),
                              // Scrim overlay — tappable to dismiss search
                              if (searchActive)
                                Positioned.fill(
                                  child: GestureDetector(
                                    onTap: () {
                                      _searchBarKey.currentState
                                          ?.cancelSearch();
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
            ),
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
              child: RepaintBoundary(
                child: ExpandedPlayerOverlay(
                  animationController: _playerController,
                  onClose: _closePlayer,
                ),
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
          // Queue management tray overlay
          if (_queueTrayOpen)
            Positioned.fill(
              child: QueueManagementTray(
                onClose: () => setState(() => _queueTrayOpen = false),
                onClearPlayed: _clearPlayed,
                onClearAllRequested: () {
                  Future.delayed(const Duration(milliseconds: 160), () {
                    if (mounted) setState(() => _clearAllConfirmOpen = true);
                  });
                },
              ),
            ),
          // Clear-all confirm dialog
          if (_clearAllConfirmOpen)
            Positioned.fill(
              child: ClearAllConfirmDialog(
                onCancel: () => setState(() => _clearAllConfirmOpen = false),
                onConfirmed: () => setState(() => _clearAllConfirmOpen = false),
                onConfirmClearAll: _clearAll,
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
            // Left panel: Now Playing with local overlays.
            // SizedBox.expand() clamps infinity to the available size on both
            // axes, giving RepaintBoundary tight constraints so it becomes a
            // Flutter relayout boundary. Without this, layout invalidations
            // (e.g. progress slider ticks) propagate up to the Row and cause
            // the right panel to relayout and repaint unnecessarily.
            Expanded(
              child: SizedBox.expand(
                child: RepaintBoundary(
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
                            onClose: () =>
                                setState(() => _serverSheetOpen = false),
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
                            onClose: () =>
                                setState(() => _settingsOpen = false),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            // Divider
            Container(width: 1, color: KalinkaColors.borderSubtle),
            // Right panel: SidePanel (tabbed search/queue).
            // SizedBox.expand() here for the same reason: tight constraints
            // make RepaintBoundary a relayout boundary so layout invalidations
            // within SidePanel don't cross into the left panel.
            Expanded(
              child: SizedBox.expand(
                child: RepaintBoundary(child: SafeArea(child: SidePanel())),
              ),
            ),
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

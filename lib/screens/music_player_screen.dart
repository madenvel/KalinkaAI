import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data_model/data_model.dart';
import '../providers/app_state_provider.dart';
import '../providers/connection_settings_provider.dart';
import '../providers/connection_state_provider.dart';
import '../providers/kalinka_player_api_provider.dart';
import '../providers/onboarding_provider.dart';
import '../providers/search_state_provider.dart';
import '../providers/toast_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/clear_all_confirm_dialog.dart';
import '../widgets/coach_marks_overlay.dart';
import '../widgets/completion_strip.dart';
import '../widgets/connection_banner.dart';
import '../widgets/discovery_screen.dart';
import '../widgets/escalation_card.dart';
import '../widgets/kalinka_button.dart';
import '../widgets/header_zone.dart';
import '../widgets/kalinka_bottom_sheet.dart';
import '../widgets/kalinka_search_bar.dart';
import '../widgets/mini_player.dart';
import '../widgets/now_playing_content.dart';
import '../widgets/playback_error_dialog.dart';
import '../widgets/queue_management_tray.dart';
import '../widgets/queue_zone.dart';
import '../widgets/search_results_feed.dart';
import '../widgets/server_sheet.dart';
import 'onboarding_screen.dart';
import 'settings_screen.dart';
import '../widgets/kalinka_toast_overlay.dart';
import '../widgets/side_panel.dart';
import '../providers/media_notification_provider.dart';
import '../providers/tablet_panel_provider.dart';

class MusicPlayerScreen extends ConsumerStatefulWidget {
  const MusicPlayerScreen({super.key});

  @override
  ConsumerState<MusicPlayerScreen> createState() => _MusicPlayerScreenState();
}

class _MusicPlayerScreenState extends ConsumerState<MusicPlayerScreen> {
  static const _tabletBreakpoint = 900.0;

  final _searchBarKey = GlobalKey<KalinkaSearchBarState>();
  final _connectionDotKey = GlobalKey();

  // Tablet-only overlay state (phone uses Navigator/modals instead).
  bool _serverSheetOpen = false;
  bool _settingsOpen = false;
  bool _discoveryOpen = false;

  // Tracks the last layout decision so we can sync search/queue state when
  // the user rotates between portrait (phone) and landscape (album/tablet).
  bool? _wasTabletLayout;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // First launch: run the setup wizard. The provider marks pre-wizard
      // installs (server already stored) as complete on its own, so they
      // fall through to the regular flow below.
      if (!ref.read(onboardingStatusProvider).oobeComplete) {
        Navigator.of(context).push(_onboardingRoute());
        return;
      }
      // Set up but no stored server (e.g. after Disconnect): plain discovery.
      final settings = ref.read(connectionSettingsProvider);
      if (!settings.isSet) {
        final isTablet = MediaQuery.of(context).size.width >= _tabletBreakpoint;
        if (isTablet) {
          setState(() => _discoveryOpen = true);
        } else {
          Navigator.of(context).push(_discoveryRoute(allowCancel: false));
        }
      }
    });
  }

  Route<void> _onboardingRoute() {
    return PageRouteBuilder(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, __, ___) => const Material(
        type: MaterialType.transparency,
        child: OnboardingScreen(),
      ),
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
    );
  }

  // ---------------------------------------------------------------------------
  // Route & modal helpers
  // ---------------------------------------------------------------------------

  Route<void> _discoveryRoute({
    required bool allowCancel,
    String? currentServerHost,
  }) {
    return PageRouteBuilder(
      // Non-opaque so the player below stays onstage: an opaque route takes it
      // offstage, which makes Riverpod 3 pause its subscriptions; connect-time
      // provider churn then resumes them mid-transition (setState during build).
      // The discovery screen paints its own opaque background, so it still
      // fully covers the player.
      opaque: false,
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, __, ___) => Material(
        type: MaterialType.transparency,
        child: DiscoveryScreen(
          allowCancel: allowCancel,
          currentServerHost: currentServerHost,
        ),
      ),
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
    );
  }

  Route<void> _settingsRoute() {
    return PageRouteBuilder(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (_, __, ___) => const Material(
        type: MaterialType.transparency,
        child: SettingsScreen(),
      ),
      transitionsBuilder: (_, anim, __, child) {
        final slide = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
            .animate(
              CurvedAnimation(parent: anim, curve: const Cubic(0.4, 0, 0.2, 1)),
            );
        return SlideTransition(position: slide, child: child);
      },
    );
  }

  Future<void> _showServerSheet() async {
    final result = await showKalinkaBottomSheet<ServerSheetAction>(
      context: context,
      contentBuilder: (_) => const ServerSheetContent(),
    );
    if (!mounted) return;
    switch (result) {
      case ServerSheetAction.openSettings:
        Navigator.of(context).push(_settingsRoute());
      case ServerSheetAction.openDiscovery:
        final settings = ref.read(connectionSettingsProvider);
        Navigator.of(context).push(
          _discoveryRoute(
            allowCancel: settings.isSet,
            currentServerHost: settings.isSet ? settings.host : null,
          ),
        );
      case null:
        break;
    }
  }

  Future<void> _showQueueManagementTray() async {
    final result = await showKalinkaBottomSheet<TrayAction>(
      context: context,
      contentBuilder: (_) => const QueueManagementTrayContent(),
    );
    if (!mounted) return;
    switch (result) {
      case TrayAction.clearPlayed:
        await _clearPlayed();
      case TrayAction.clearAll:
        await Future.delayed(const Duration(milliseconds: 160));
        if (!mounted) return;
        await showKalinkaConfirmDialog<bool>(
          context: context,
          builder: (_) => ClearAllConfirmDialog(onConfirmClearAll: _clearAll),
        );
      case null:
        break;
    }
  }

  void _showExpandedPlayer() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      backgroundColor: KalinkaColors.background,
      barrierColor: Colors.transparent,
      useSafeArea: true,
      // Override the M3 default 640px cap so the sheet fills the window and
      // resizes smoothly instead of centering with the layout poking out.
      constraints: const BoxConstraints(maxWidth: double.infinity),
      builder: (_) =>
          const _ExpandedPlayerSheet(breakpoint: _tabletBreakpoint),
    );
  }

  // ---------------------------------------------------------------------------
  // Queue actions
  // ---------------------------------------------------------------------------

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
            KalinkaButton(
              label: 'Scan for servers',
              variant: KalinkaButtonVariant.accent,
              size: KalinkaButtonSize.normal,
              leading: const Icon(
                Icons.wifi_tethering_rounded,
                size: 16,
                color: KalinkaColors.accentTint,
              ),
              onTap: () {
                final settings = ref.read(connectionSettingsProvider);
                Navigator.of(context).push(
                  _discoveryRoute(
                    allowCancel: settings.isSet,
                    currentServerHost: settings.isSet ? settings.host : null,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showPlaybackErrorDialog(String? message) {
    if (!mounted) return;
    // Defer to the next frame: the error listener fires mid-connect while the
    // provider graph is still settling, and inserting the dialog in that frame
    // rebuilds the overlay against dirty providers (setState during build).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showKalinkaConfirmDialog<void>(
        context: context,
        // The dialog paints its own scrim and re-lays-out on resize, so keep
        // the global barrier clear.
        barrierColor: Colors.transparent,
        builder: (_) => PlaybackErrorDialog(message: message),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.read(mediaNotificationProvider);

    // Surface playback errors as a dialog in both phone and tablet layouts.
    // Lives here (not in MiniPlayer) because the mini player is only mounted
    // in the phone layout.
    ref.listen(
      playQueueStateStoreProvider.select(
        (s) => (state: s.playbackState.state, message: s.playbackState.message),
      ),
      (prev, next) {
        if (next.state == PlayerStateType.error &&
            (prev?.state != PlayerStateType.error ||
                prev?.message != next.message)) {
          _showPlaybackErrorDialog(next.message);
        }
      },
    );

    return Scaffold(
      backgroundColor: KalinkaColors.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isTablet = constraints.maxWidth >= _tabletBreakpoint;
          _maybeSyncOnLayoutChange(isTablet);
          _wasTabletLayout = isTablet;
          return isTablet
              ? _buildTabletLayout(context)
              : _buildPhoneLayout(context);
        },
      ),
    );
  }

  /// On portrait↔album rotations, mirror the active surface across layouts:
  ///  - phone → tablet: route to the Search tab if the phone overlay was open,
  ///    otherwise to the Queue tab.
  ///  - tablet → phone: if the tablet was on the Queue tab, dismiss the search
  ///    surface so the queue is the visible main view (the search bar's
  ///    `alwaysExpanded` auto-activation would otherwise leave search active).
  /// Snapshots are taken synchronously here — before the new tree mounts and
  /// any auto-activation runs — and applied in a postFrameCallback.
  void _maybeSyncOnLayoutChange(bool isTablet) {
    final previous = _wasTabletLayout;
    if (previous == null || previous == isTablet) return;
    final wasSearchActive = ref.read(searchStateProvider).searchActive;
    final wasTabletPanel = ref.read(tabletPanelProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (isTablet) {
        if (wasSearchActive) {
          ref.read(tabletPanelProvider.notifier).showSearch();
        } else {
          ref.read(tabletPanelProvider.notifier).showQueue();
        }
      } else {
        if (wasTabletPanel == TabletPanel.queue) {
          _searchBarKey.currentState?.cancelSearch();
          ref.read(searchStateProvider.notifier).deactivateSearch();
        }
      }
    });
  }

  Widget _buildPhoneLayout(BuildContext context) {
    final searchState = ref.watch(searchStateProvider);
    final searchActive = searchState.searchActive;
    final connectionState = ref.watch(connectionStateProvider);

    // One-time UI tour: first time the queue is visible with a live
    // connection (right after the setup wizard, or after upgrading).
    final onboarding = ref.watch(onboardingStatusProvider);
    final showCoachMarks = onboarding.oobeComplete &&
        !onboarding.coachMarksShown &&
        connectionState == ConnectionStatus.connected &&
        !searchActive;

    return PopScope(
      canPop: !searchActive,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
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
        }
      },
      child: Stack(
        children: [
          // Main content: Header + Banner + CompletionStrip + Content Zone + Escalation + MiniPlayer
          Column(
            children: [
              RepaintBoundary(
                child: HeaderZone(
                  searchBarKey: _searchBarKey,
                  onServerChipTap: _showServerSheet,
                  connectionDotKey: _connectionDotKey,
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
                          // Queue is not rendered while search is active on phone.
                          if (!searchActive)
                            RepaintBoundary(
                              child: QueueZone(
                                onOpenManagementTray: _showQueueManagementTray,
                              ),
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
                  final settings = ref.read(connectionSettingsProvider);
                  Navigator.of(context).push(
                    _discoveryRoute(
                      allowCancel: settings.isSet,
                      currentServerHost: settings.isSet ? settings.host : null,
                    ),
                  );
                },
              ),
              MiniPlayer(onTap: _showExpandedPlayer),
            ],
          ),
          // Toast overlay — floats above MiniPlayer, ignores pointer input
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(child: KalinkaToastOverlay()),
          ),
          // One-time first-run tour
          if (showCoachMarks)
            Positioned.fill(
              child: CoachMarksOverlay(
                stops: [
                  CoachMarkStop(
                    targetKey: _searchBarKey,
                    title: 'Search your library',
                    body: 'Type to find tracks, albums and artists — or '
                        'flip on the AI pill to search by mood, like '
                        '“mellow late-night jazz”.',
                  ),
                  CoachMarkStop(
                    targetKey: _connectionDotKey,
                    title: 'Your server lives here',
                    body: 'The green dot shows you’re connected. Tap it '
                        'for server status, settings, and switching '
                        'servers.',
                  ),
                ],
                onDismiss: () => ref
                    .read(onboardingStatusProvider.notifier)
                    .markCoachMarksShown(),
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
            // Right panel: connection banner + SidePanel (tabbed search/queue)
            // + escalation card. The connection UI lives here on tablet so it
            // appears alongside the queue/search, mirroring the phone layout
            // (where the banner sits below the header and the card above the
            // mini player).
            // SizedBox.expand() here for the same reason as the left panel:
            // tight constraints make RepaintBoundary a relayout boundary so
            // layout invalidations within SidePanel don't cross into it.
            Expanded(
              child: SizedBox.expand(
                child: RepaintBoundary(
                  child: SafeArea(
                    child: Column(
                      children: [
                        const ConnectionBanner(),
                        Expanded(child: SidePanel()),
                        EscalationCard(
                          onScanForServers: () =>
                              setState(() => _discoveryOpen = true),
                        ),
                      ],
                    ),
                  ),
                ),
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
              isTablet: true,
            ),
          ),
      ],
    );
  }
}

/// Full-screen Now Playing shown as a modal sheet in the phone layout. It
/// self-dismisses once the window grows past the tablet breakpoint, where the
/// player instead lives permanently in the left panel — otherwise the sheet
/// would float on top of the tablet layout.
class _ExpandedPlayerSheet extends StatelessWidget {
  final double breakpoint;

  const _ExpandedPlayerSheet({required this.breakpoint});

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).size.width >= breakpoint) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.of(context).pop();
      });
    }
    return SizedBox.expand(
      child: NowPlayingContent(
        showOverlayHeader: true,
        onClose: () => Navigator.of(context).pop(),
      ),
    );
  }
}

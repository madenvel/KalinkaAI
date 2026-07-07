import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data_model/data_model.dart';
import '../providers/app_state_provider.dart';
import '../providers/connection_settings_provider.dart';
import '../providers/connection_state_provider.dart';
import '../providers/kalinka_player_api_provider.dart';
import '../providers/onboarding_provider.dart';
import '../providers/search_session_provider.dart';
import '../providers/toast_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/clear_all_confirm_dialog.dart';
import '../widgets/coach_marks_overlay.dart';
import '../widgets/connection_banner.dart';
import '../widgets/discovery_screen.dart';
import '../widgets/escalation_card.dart';
import '../widgets/kalinka_button.dart';
import '../widgets/kalinka_top_bar.dart';
import '../widgets/kalinka_bottom_sheet.dart';
import '../widgets/measure_size.dart';
import '../widgets/mini_player.dart';
import '../widgets/now_playing_content.dart';
import '../widgets/playback_error_dialog.dart';
import '../widgets/queue_management_tray.dart';
import '../widgets/queue_zone.dart';
import '../widgets/search/search_dock.dart';
import '../widgets/search/search_session_view.dart';
import '../widgets/server_sheet.dart';
import 'onboarding_screen.dart';
import 'settings_screen.dart';
import '../widgets/kalinka_toast_overlay.dart';
import '../widgets/sheet_anchor.dart';
import '../providers/media_notification_provider.dart';

class MusicPlayerScreen extends ConsumerStatefulWidget {
  const MusicPlayerScreen({super.key});

  @override
  ConsumerState<MusicPlayerScreen> createState() => _MusicPlayerScreenState();
}

class _MusicPlayerScreenState extends ConsumerState<MusicPlayerScreen> {
  static const _tabletBreakpoint = 900.0;

  final _searchDockKey = GlobalKey();
  final _connectionDotKey = GlobalKey();

  // In-screen overlays. Settings and discovery render in both layouts;
  // the server sheet overlay is tablet-only (phone uses a modal sheet).
  bool _serverSheetOpen = false;
  bool _settingsOpen = false;
  // True once the settings panel fully covers the content behind it (after its
  // slide-in). Used to Offstage the occluded content so it isn't painted while
  // hidden — but only after the animation, so the slide-in still shows it.
  bool _settingsCovering = false;
  bool _discoveryOpen = false;
  // Tablet-only: the queue management tray, hosted here (not inside QueueZone)
  // so its overlay covers the search dock like the connection sheet.
  bool _queueTrayOpen = false;

  // Live height of the floating dock (plus escalation card, when shown) so the
  // queue behind it can reserve matching bottom space and clear the bar.
  double _dockClusterHeight = 0;

  void _onDockClusterMeasured(double height) {
    if (!mounted || _dockClusterHeight == height) return;
    setState(() => _dockClusterHeight = height);
  }

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
      if (!ref.read(connectionSettingsProvider).isSet) {
        setState(() => _discoveryOpen = true);
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

  Future<void> _showServerSheet() async {
    final result = await showKalinkaBottomSheet<ServerSheetAction>(
      context: context,
      contentBuilder: (_) => const ServerSheetContent(),
    );
    if (!mounted) return;
    switch (result) {
      case ServerSheetAction.openSettings:
        setState(() => _settingsOpen = true);
      case ServerSheetAction.openDiscovery:
        setState(() => _discoveryOpen = true);
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

  /// Tablet: act on the panel-level queue management tray's selection.
  Future<void> _onTabletTrayAction(TrayAction action) async {
    switch (action) {
      case TrayAction.clearPlayed:
        await _clearPlayed();
      case TrayAction.clearAll:
        await Future.delayed(const Duration(milliseconds: 160));
        if (!mounted) return;
        await showKalinkaConfirmDialog<bool>(
          context: context,
          builder: (_) => ClearAllConfirmDialog(onConfirmClearAll: _clearAll),
        );
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
      builder: (_) => const _ExpandedPlayerSheet(breakpoint: _tabletBreakpoint),
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
              onTap: () => setState(() => _discoveryOpen = true),
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
          return Stack(
            // Tight constraints keep the layout root a relayout boundary.
            fit: StackFit.expand,
            children: [
              isTablet
                  ? _buildTabletLayout(context)
                  : _buildPhoneLayout(context),
              // Hosted above the phone/tablet switch so an in-progress scan
              // (and its state) survives resizing across the breakpoint.
              if (_discoveryOpen) _buildDiscoveryOverlay(isTablet),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPhoneLayout(BuildContext context) {
    final searchOpen = ref.watch(searchSessionProvider.select((s) => s.isOpen));
    final connectionState = ref.watch(connectionStateProvider);

    // One-time UI tour: first time the queue is visible with a live
    // connection (right after the setup wizard, or after upgrading).
    final onboarding = ref.watch(onboardingStatusProvider);
    final showCoachMarks =
        onboarding.oobeComplete &&
        !onboarding.coachMarksShown &&
        connectionState == ConnectionStatus.connected &&
        !searchOpen;

    return PopScope(
      canPop: !searchOpen && !_settingsOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // Settings is a full-screen overlay here; it owns its own back via an
        // internal PopScope (animated close), so leave it alone.
        if (_settingsOpen) return;
        if (searchOpen) {
          ref.read(searchSessionProvider.notifier).close();
        }
      },
      child: Stack(
        children: [
          // Main content: TopBar + Banner + Content + Escalation + Dock +
          // MiniPlayer. When search is open the dock/escalation give way and the
          // content becomes the chat session (whose composer is the sole bottom
          // element); the miniplayer slides itself away.
          Visibility(
            visible: !_settingsCovering,
            maintainState: true,
            maintainAnimation: true,
            maintainSize: true,
            child: Column(
              children: [
                // The search session carries its own header (roundel + search
                // bar + connection dot), so the shared top bar leaves with it.
                if (!searchOpen)
                  RepaintBoundary(
                    child: KalinkaTopBar(
                      onServerChipTap: _showServerSheet,
                      connectionKey: _connectionDotKey,
                    ),
                  ),
                const ConnectionBanner(),
                Expanded(
                  // The dock (and escalation card) float over the content, which
                  // scrolls behind them and fades into the page; the mini-player
                  // below stays solid.
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: searchOpen
                              ? SearchSessionView(
                                  key: const ValueKey('search'),
                                  onServerTap: _showServerSheet,
                                )
                              : KeyedSubtree(
                                  key: const ValueKey('queue'),
                                  child:
                                      connectionState == ConnectionStatus.none
                                      ? _buildDisconnectedState()
                                      : RepaintBoundary(
                                          child: QueueZone(
                                            bottomPadding: _dockClusterHeight,
                                            onOpenManagementTray:
                                                _showQueueManagementTray,
                                          ),
                                        ),
                                ),
                        ),
                      ),
                      if (!searchOpen)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: MeasureSize(
                            onChange: (size) =>
                                _onDockClusterMeasured(size.height),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                EscalationCard(
                                  onScanForServers: () =>
                                      setState(() => _discoveryOpen = true),
                                ),
                                SearchDock(
                                  buttonKey: _searchDockKey,
                                  onTap: () => ref
                                      .read(searchSessionProvider.notifier)
                                      .open(),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                MiniPlayer(onTap: _showExpandedPlayer),
              ],
            ),
          ),
          // Toast overlay — floats above the bottom dock, ignoring pointer
          // input. The search screen has nothing docked at the bottom (its bar
          // lives in the header), so toasts sit near the bottom edge there.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: KalinkaToastOverlay(bottomOffset: searchOpen ? 24 : 135),
            ),
          ),
          // Settings — full-screen overlay on phone (slides in from the right).
          // The same flag renders it in the left panel on tablet, so resizing
          // across the breakpoint just re-homes it.
          if (_settingsOpen)
            Positioned.fill(
              child: SettingsScreen(
                onClose: () => setState(() {
                  _settingsOpen = false;
                  _settingsCovering = false;
                }),
                onCoverageChanged: (covering) =>
                    setState(() => _settingsCovering = covering),
              ),
            ),
          // One-time first-run tour
          if (showCoachMarks)
            Positioned.fill(
              child: CoachMarksOverlay(
                stops: [
                  CoachMarkStop(
                    targetKey: _searchDockKey,
                    title: 'Ask for music',
                    body:
                        'Tap here to open search and ask in plain language — '
                        'like “mellow late-night jazz”. Results stage below; '
                        'nothing plays until you add it.',
                  ),
                  CoachMarkStop(
                    targetKey: _connectionDotKey,
                    title: 'Your server lives here',
                    body:
                        'The green dot shows you’re connected. Tap it '
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

  Widget _buildDiscoveryOverlay(bool isTablet) {
    return Positioned.fill(
      // Consumer keeps settings churn from the overlay's own connect flow
      // from rebuilding the occluded layout below.
      child: Consumer(
        builder: (context, ref, _) {
          final settings = ref.watch(connectionSettingsProvider);
          return DiscoveryScreen(
            allowCancel: settings.isSet,
            currentServerHost: settings.isSet ? settings.host : null,
            onClose: () => setState(() => _discoveryOpen = false),
            isTablet: isTablet,
          );
        },
      ),
    );
  }

  Widget _buildTabletLayout(BuildContext context) {
    final searchOpen = ref.watch(searchSessionProvider.select((s) => s.isOpen));
    return PopScope(
      canPop: !searchOpen && !_settingsOpen && !_serverSheetOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // Settings owns its own back via an internal PopScope.
        if (_settingsOpen) return;
        if (_serverSheetOpen) {
          setState(() => _serverSheetOpen = false);
          return;
        }
        if (searchOpen) {
          ref.read(searchSessionProvider.notifier).close();
        }
      },
      child: Stack(
        children: [
          Row(
            children: [
              // Left panel: Now Playing with local overlays.
              // SizedBox.expand() clamps infinity to the available size on both
              // axes, giving RepaintBoundary tight constraints so it becomes a
              // Flutter relayout boundary. Without this, layout invalidations
              // (e.g. progress slider ticks) propagate up to the Row and cause
              // the right panel to relayout and repaint unnecessarily.
              // SheetAnchor aligns modal bottom sheets launched from this
              // panel (e.g. settings pickers) with its bounds.
              Expanded(
                child: SizedBox.expand(
                  child: RepaintBoundary(
                    child: SheetAnchor(
                      child: Stack(
                        children: [
                          // Not painted once settings fully covers the left panel.
                          Visibility(
                            visible: !_settingsCovering,
                            maintainState: true,
                            maintainAnimation: true,
                            maintainSize: true,
                            child: const SafeArea(
                              child: NowPlayingContent(isTablet: true),
                            ),
                          ),
                          // Settings screen overlay (left panel only). ClipRect
                          // keeps the slide-in within the left half — the Stack
                          // doesn't clip a paint-time transform, so without it the
                          // animation bleeds over the queue on the right.
                          if (_settingsOpen)
                            Positioned.fill(
                              child: ClipRect(
                                child: SettingsScreen(
                                  onClose: () => setState(() {
                                    _settingsOpen = false;
                                    _settingsCovering = false;
                                  }),
                                  onCoverageChanged: (covering) => setState(
                                    () => _settingsCovering = covering,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Divider
              Container(width: 1, color: KalinkaColors.borderSubtle),
              // Right panel — mirrors the phone main screen: a top bar carrying
              // the connection dot, the queue (or the chat search session), and
              // the bottom search dock. There is no miniplayer here — Now Playing
              // lives in the left panel — so the dock/composer is the sole bottom
              // element. SizedBox.expand() gives RepaintBoundary tight constraints
              // so its layout invalidations don't cross into the left panel.
              Expanded(
                child: SizedBox.expand(
                  child: RepaintBoundary(
                    child: Column(
                      children: [
                        // The whole right panel — including the search dock — sits
                        // in a Stack so the connection sheet overlays it as a
                        // bottom card, covering the dock rather than stopping above
                        // it.
                        Expanded(
                          child: Stack(
                            children: [
                              Column(
                                children: [
                                  // Search brings its own header row; the
                                  // shared top bar yields to it.
                                  if (!searchOpen)
                                    KalinkaTopBar(
                                      onServerChipTap: () => setState(
                                        () => _serverSheetOpen = true,
                                      ),
                                    ),
                                  const ConnectionBanner(),
                                  Expanded(
                                    // Dock floats over the queue, which fades
                                    // behind it (same as phone, minus the
                                    // mini-player).
                                    child: Stack(
                                      children: [
                                        Positioned.fill(
                                          child: AnimatedSwitcher(
                                            duration: const Duration(
                                              milliseconds: 200,
                                            ),
                                            child: searchOpen
                                                ? SearchSessionView(
                                                    key: const ValueKey(
                                                      'search',
                                                    ),
                                                    onServerTap: () => setState(
                                                      () => _serverSheetOpen =
                                                          true,
                                                    ),
                                                  )
                                                : KeyedSubtree(
                                                    key: const ValueKey(
                                                      'queue',
                                                    ),
                                                    child: RepaintBoundary(
                                                      child: QueueZone(
                                                        bottomPadding:
                                                            _dockClusterHeight,
                                                        isTablet: true,
                                                        onOpenManagementTray:
                                                            () => setState(
                                                              () =>
                                                                  _queueTrayOpen =
                                                                      true,
                                                            ),
                                                      ),
                                                    ),
                                                  ),
                                          ),
                                        ),
                                        if (!searchOpen)
                                          Positioned(
                                            left: 0,
                                            right: 0,
                                            bottom: 0,
                                            child: MeasureSize(
                                              onChange: (size) =>
                                                  _onDockClusterMeasured(
                                                    size.height,
                                                  ),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  EscalationCard(
                                                    onScanForServers: () =>
                                                        setState(
                                                          () => _discoveryOpen =
                                                              true,
                                                        ),
                                                  ),
                                                  SearchDock(
                                                    bottomSafeArea: true,
                                                    onTap: () => ref
                                                        .read(
                                                          searchSessionProvider
                                                              .notifier,
                                                        )
                                                        .open(),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (_serverSheetOpen)
                                Positioned.fill(
                                  child: ServerSheet(
                                    onClose: () => setState(
                                      () => _serverSheetOpen = false,
                                    ),
                                    onOpenDiscovery: () =>
                                        setState(() => _discoveryOpen = true),
                                    onOpenSettings: () =>
                                        setState(() => _settingsOpen = true),
                                  ),
                                ),
                              // Queue management tray — same panel-level overlay
                              // so it covers the search dock too.
                              if (_queueTrayOpen)
                                Positioned.fill(
                                  child: TabletQueueManagementTray(
                                    onClose: () =>
                                        setState(() => _queueTrayOpen = false),
                                    onAction: _onTabletTrayAction,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Toast overlay — bottom-right of the right panel, lifted clear of the
          // search dock (or composer, when search is open).
          Positioned(
            right: 20,
            bottom: searchOpen ? 116 : 80,
            child: const IgnorePointer(
              child: SizedBox(
                width: 300,
                child: KalinkaToastOverlay(isTablet: true),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-screen Now Playing shown as a modal sheet in the phone layout. It
/// self-dismisses once the window grows past the tablet breakpoint, where the
/// player instead lives permanently in the left panel — otherwise the sheet
/// would float on top of the tablet layout.
class _ExpandedPlayerSheet extends StatefulWidget {
  final double breakpoint;

  const _ExpandedPlayerSheet({required this.breakpoint});

  @override
  State<_ExpandedPlayerSheet> createState() => _ExpandedPlayerSheetState();
}

class _ExpandedPlayerSheetState extends State<_ExpandedPlayerSheet> {
  bool _dismissing = false;

  @override
  Widget build(BuildContext context) {
    // Dismiss exactly once when crossing into the tablet layout. Scheduling a
    // pop on every resize frame re-ran after the route was gone and threw
    // "No element" (Navigator.pop on empty history) mid-resize.
    if (!_dismissing &&
        MediaQuery.of(context).size.width >= widget.breakpoint) {
      _dismissing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) {
          Navigator.of(context).pop();
        }
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

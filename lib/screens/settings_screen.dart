import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../providers/connection_state_provider.dart';
import '../providers/restart_provider.dart';
import '../providers/settings_provider.dart';
import '../data_model/presentation_schema.dart' show PageSpec;
import '../theme/app_theme.dart';
import '../widgets/connection_banner.dart';
import '../widgets/kalinka_bottom_sheet.dart' show showKalinkaConfirmDialog;
import '../widgets/kalinka_button.dart';
import '../widgets/pending_changes_banner.dart';
import '../widgets/restart_confirm_dialog.dart';
import '../widgets/restart_overlay.dart';
import '../widgets/expert_settings_screen.dart';
import '../widgets/settings_controls/settings_toggle.dart';
import '../widgets/settings_renderer.dart';

/// Full-screen settings overlay with tabbed content (General / Modules / Devices).
///
/// Slides in from the right, loads server config on init.
class SettingsScreen extends ConsumerStatefulWidget {
  /// Optional close callback for overlay mode (phone full-screen / tablet left
  /// panel). When null, [Navigator.pop] is used instead.
  final VoidCallback? onClose;

  /// Fires `true` once the slide-in finishes (the panel now fully covers what's
  /// behind it) and `false` the moment the slide-out begins. Lets the host stop
  /// painting the occluded content without flashing during the animation.
  final ValueChanged<bool>? onCoverageChanged;

  const SettingsScreen({super.key, this.onClose, this.onCoverageChanged});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  int _tabIndex = 0;
  bool _restartOverlayOpen = false;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _slideController,
            curve: const Cubic(0.4, 0, 0.2, 1),
          ),
        );
    _slideController.forward().whenComplete(() {
      if (mounted) widget.onCoverageChanged?.call(true);
    });

    // Load config
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(settingsProvider.notifier).loadConfig();
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _animateClose() async {
    if (widget.onClose != null) {
      // Overlay mode — reveal what's behind us before sliding out, then remove.
      widget.onCoverageChanged?.call(false);
      await _slideController.reverse();
      widget.onClose!();
    } else {
      // Phone Navigator route mode — route transition handles animation.
      Navigator.pop(context);
    }
  }

  void _onApply() {
    setState(() => _restartOverlayOpen = true);
    ref.read(restartProvider.notifier).executeRestart();
  }

  @override
  Widget build(BuildContext context) {
    final settingsState = ref.watch(settingsProvider);
    final expertMode = ref.watch(expertModeProvider);
    final connectionState = ref.watch(connectionStateProvider);
    final disconnected =
        connectionState == ConnectionStatus.reconnecting ||
        connectionState == ConnectionStatus.offline;

    // Reload the settings once the connection comes back, so stale or
    // half-loaded config from before the drop is replaced.
    ref.listen<ConnectionStatus>(connectionStateProvider, (prev, next) {
      if (next == ConnectionStatus.connected &&
          (prev == ConnectionStatus.reconnecting ||
              prev == ConnectionStatus.offline)) {
        ref.read(settingsProvider.notifier).loadConfig();
      }
    });

    final content = Stack(
      children: [
        SlideTransition(
          position: _slideAnimation,
          child: Container(
            color: KalinkaColors.background,
            child: SafeArea(
              child: Column(
                children: [
                  // Header (carries the Expert mode toggle on the right)
                  _buildHeader(),
                  // Reconnecting / offline indicator — the same banner the
                  // queue screen shows. Self-hides when connected.
                  const ConnectionBanner(),
                  if (disconnected)
                    // Server unreachable: replace the apply bar, tab bar and
                    // settings body with a placeholder. Settings reload
                    // automatically once the connection returns (the
                    // ref.listen above), swapping this back for the apply bar.
                    _buildDisconnectedPlaceholder()
                  else ...[
                    // Pending changes banner — only actionable while
                    // connected, since applying restarts the server.
                    PendingChangesBanner(onApply: _onApply),
                    // Tab bar — only meaningful in simple mode; expert is
                    // a single flat about:config-style screen.
                    if (!expertMode) _buildTabBar(settingsState.schema?.pages),
                    // Loading / error state
                    if (settingsState.isLoading)
                      const Expanded(
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(
                              KalinkaColors.accent,
                            ),
                          ),
                        ),
                      )
                    else if (settingsState.error != null &&
                        settingsState.schema == null)
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: KalinkaColors.statusOffline,
                                size: 32,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Could not load settings',
                                style: KalinkaTextStyles.cardTitle,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                settingsState.error!,
                                textAlign: TextAlign.center,
                                style: KalinkaTextStyles.trayRowSublabel,
                              ),
                              const SizedBox(height: 16),
                              KalinkaButton(
                                label: 'Retry',
                                variant: KalinkaButtonVariant.accent,
                                size: KalinkaButtonSize.compact,
                                onTap: () => ref
                                    .read(settingsProvider.notifier)
                                    .loadConfig(),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (settingsState.schema != null)
                      Expanded(
                        child: expertMode
                            ? const ExpertSettingsScreen()
                            : IndexedStack(
                                index: _tabIndex.clamp(
                                  0,
                                  settingsState.schema!.pages.length - 1,
                                ),
                                children: [
                                  for (final page
                                      in settingsState.schema!.pages)
                                    SchemaPageRenderer(
                                      key: ValueKey('page_${page.id}'),
                                      page: page,
                                    ),
                                ],
                              ),
                      )
                    else
                      const Expanded(child: SizedBox.shrink()),
                  ],
                ],
              ),
            ),
          ),
        ),
        // Restart overlay
        if (_restartOverlayOpen)
          Positioned.fill(
            child: RestartOverlay(
              onDismiss: () {
                setState(() => _restartOverlayOpen = false);
                // Reload config after restart
                ref.read(settingsProvider.notifier).loadConfig();
              },
            ),
          ),
      ],
    );

    // As an overlay (onClose set) intercept the system back to animate out,
    // matching the header back button. As a route the transition handles it.
    if (widget.onClose == null) return content;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _animateClose();
      },
      child: content,
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: kKalinkaTopBarDecoration,
      // Shared top-bar height so this lines up with the queue and search bars.
      child: SizedBox(
        height: kKalinkaTopBarHeight,
        child: Padding(
          padding: const EdgeInsets.only(left: 12, right: 20),
          child: Row(
            children: [
              // Back button
              Material(
                color: KalinkaColors.surfaceInput,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                  side: const BorderSide(color: KalinkaColors.borderDefault),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: _animateClose,
                  overlayColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.pressed)) {
                      return Colors.white.withValues(alpha: 0.08);
                    }
                    return null;
                  }),
                  child: const SizedBox(
                    width: 36,
                    height: 36,
                    child: Icon(
                      Icons.arrow_back,
                      size: 14,
                      color: KalinkaColors.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Kalinka logo
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SvgPicture.asset(
                    'assets/images/kalinka_logo.svg',
                    height: kKalinkaWordmarkHeight,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              // Restart the server. Available even with no pending changes
              // (the pending-changes banner only restarts when applying), so
              // there's always a way to reboot — e.g. to fire an armed
              // "Rebuild library on next restart" toggle.
              Material(
                color: KalinkaColors.surfaceInput,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                  side: const BorderSide(color: KalinkaColors.borderDefault),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: _onRestart,
                  overlayColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.pressed)) {
                      return Colors.white.withValues(alpha: 0.08);
                    }
                    return null;
                  }),
                  child: const SizedBox(
                    width: 36,
                    height: 36,
                    child: Icon(
                      Icons.restart_alt,
                      size: 16,
                      color: KalinkaColors.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // View-mode switch: simple ↔ expert (about:config-style).
              // Sits where the connection status pill used to live —
              // connection state surfaces clearly enough through the
              // loading/error UI below, so the prime header slot is better
              // spent on a control the user actually interacts with.
              const _ExpertModeHeaderToggle(),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onRestart() async {
    final confirmed = await showKalinkaConfirmDialog<bool>(
      context: context,
      builder: (_) => const RestartConfirmDialog(),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _restartOverlayOpen = true);
    ref.read(restartProvider.notifier).executeRestart();
  }

  /// Shown in place of the settings body while the server is unreachable.
  /// The [ConnectionBanner] above already explains the reconnecting/offline
  /// state, so this stays a calm, minimal placeholder.
  Widget _buildDisconnectedPlaceholder() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              color: KalinkaColors.textSecondary,
              size: 32,
            ),
            const SizedBox(height: 12),
            Text('Server not connected', style: KalinkaTextStyles.cardTitle),
            const SizedBox(height: 8),
            Text(
              'Settings will reload once the connection is restored.',
              textAlign: TextAlign.center,
              style: KalinkaTextStyles.trayRowSublabel,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar(List<PageSpec>? pages) {
    final tabs = (pages == null || pages.isEmpty)
        ? const ['General', 'Modules', 'Devices']
        : pages.map((p) => p.title).toList();
    return Container(
      decoration: const BoxDecoration(
        color: KalinkaColors.surfaceBase,
        border: Border(bottom: BorderSide(color: KalinkaColors.borderSubtle)),
      ),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final isActive = i == _tabIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _tabIndex = i),
              behavior: HitTestBehavior.opaque,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      tabs[i].toUpperCase(),
                      textAlign: TextAlign.center,
                      style: KalinkaTextStyles.sectionHeaderMuted.copyWith(
                        letterSpacing: 1.0,
                        color: isActive
                            ? KalinkaColors.accent
                            : KalinkaColors.textSecondary,
                      ),
                    ),
                  ),
                  Container(
                    height: 2,
                    color: isActive ? KalinkaColors.accent : Colors.transparent,
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Compact "EXPERT" label + toggle that sits in the header where the
/// connection status pill used to live. Off = simple tabbed view,
/// On = flat about:config-style screen.
///
/// The label is muted-uppercase to match other meta chrome in the
/// header; the toggle is scaled slightly down so it sits proportional
/// to the back button and logo rather than dominating the row.
class _ExpertModeHeaderToggle extends ConsumerWidget {
  const _ExpertModeHeaderToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expert = ref.watch(expertModeProvider);
    final notifier = ref.read(expertModeProvider.notifier);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: notifier.toggle,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'EXPERT',
            style: KalinkaTextStyles.sectionHeaderMuted.copyWith(
              letterSpacing: 1.0,
              color: expert
                  ? KalinkaColors.accent
                  : KalinkaColors.textSecondary,
            ),
          ),
          const SizedBox(width: 10),
          Transform.scale(
            scale: 0.82,
            alignment: Alignment.centerRight,
            child: SettingsToggle(
              value: expert,
              onChanged: (_) => notifier.toggle(),
            ),
          ),
        ],
      ),
    );
  }
}

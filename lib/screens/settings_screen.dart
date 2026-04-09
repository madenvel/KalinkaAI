import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/connection_settings_provider.dart';
import '../providers/connection_state_provider.dart';
import '../providers/restart_provider.dart';
import '../providers/server_info_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/kalinka_button.dart';
import '../widgets/pending_changes_banner.dart';
import '../widgets/restart_overlay.dart';
import '../widgets/settings_tabs/devices_tab.dart';
import '../widgets/settings_tabs/general_tab.dart';
import '../widgets/settings_tabs/modules_tab.dart';

/// Full-screen settings overlay with tabbed content (General / Modules / Devices).
///
/// Slides in from the right, loads server config on init.
class SettingsScreen extends ConsumerStatefulWidget {
  /// Optional close callback for tablet Stack overlay mode.
  /// When null (phone Navigator route), [Navigator.pop] is used instead.
  final VoidCallback? onClose;
  final VoidCallback? onDismissing;

  const SettingsScreen({super.key, this.onClose, this.onDismissing});

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
    _slideController.forward();

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
      // Tablet Stack overlay mode — animate out, then remove via callback.
      widget.onDismissing?.call();
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
    final settings = ref.watch(connectionSettingsProvider);
    final connectionState = ref.watch(connectionStateProvider);
    final serverInfo = ref.watch(serverInfoProvider);
    final settingsState = ref.watch(settingsProvider);

    return Stack(
      children: [
        SlideTransition(
          position: _slideAnimation,
          child: Container(
            color: KalinkaColors.background,
            child: SafeArea(
              child: Column(
                children: [
                  // Header
                  _buildHeader(settings, connectionState, serverInfo),
                  // Pending changes banner
                  PendingChangesBanner(onApply: _onApply),
                  // Tab bar
                  _buildTabBar(),
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
                      settingsState.serverConfig.isEmpty)
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
                  else
                    // Tab content
                    Expanded(
                      child: IndexedStack(
                        index: _tabIndex,
                        children: [
                          const GeneralTab(),
                          ModulesTab(),
                          DevicesTab(),
                        ],
                      ),
                    ),
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
  }

  Widget _buildHeader(
    ConnectionSettings settings,
    ConnectionStatus connectionState,
    AsyncValue<ServerInfo> serverInfo,
  ) {
    Color dotColor;
    switch (connectionState) {
      case ConnectionStatus.connected:
        dotColor = KalinkaColors.statusOnline;
      case ConnectionStatus.reconnecting:
      case ConnectionStatus.connecting:
        dotColor = KalinkaColors.statusPending;
      case ConnectionStatus.offline:
        dotColor = KalinkaColors.statusOffline;
      case ConnectionStatus.none:
        dotColor = KalinkaColors.textMuted;
    }

    final versionText = serverInfo.whenOrNull(data: (info) => info.version);
    final detailParts = <String>[
      if (settings.host.isNotEmpty) '${settings.host}:${settings.port}',
      if (versionText != null) 'v$versionText',
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 20, 14),
      decoration: BoxDecoration(
        color: KalinkaColors.surfaceBase,
        border: const Border(
          bottom: BorderSide(color: KalinkaColors.borderDefault),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            offset: const Offset(0, 4),
            blurRadius: 24,
          ),
        ],
      ),
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
          const SizedBox(width: 10),
          // Server name + details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  settings.name.isNotEmpty ? settings.name : 'Server settings',
                  style: KalinkaTextStyles.trayRowLabel.copyWith(
                    fontSize: KalinkaTypography.baseSize + 5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (detailParts.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    detailParts.join(' \u00b7 '),
                    style: KalinkaTextStyles.trayRowSublabel.copyWith(
                      fontSize: KalinkaTypography.baseSize + 2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          // Online dot
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
              boxShadow: connectionState == ConnectionStatus.connected
                  ? [
                      BoxShadow(
                        color: dotColor.withValues(alpha: 0.5),
                        blurRadius: 8,
                      ),
                    ]
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    const tabs = ['General', 'Modules', 'Devices'];
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

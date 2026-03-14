import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/connection_settings_provider.dart';
import '../providers/connection_state_provider.dart';
import '../providers/server_info_provider.dart';
import '../theme/app_theme.dart';
import '../utils/haptics.dart';

/// Server management bottom sheet — opened by tapping the server chip.
///
/// Shows server status, and provides actions for settings, switching servers,
/// and disconnecting.
class ServerSheet extends ConsumerStatefulWidget {
  final VoidCallback onClose;
  final VoidCallback onOpenDiscovery;
  final VoidCallback onOpenSettings;

  const ServerSheet({
    super.key,
    required this.onClose,
    required this.onOpenDiscovery,
    required this.onOpenSettings,
  });

  @override
  ConsumerState<ServerSheet> createState() => _ServerSheetState();
}

class _ServerSheetState extends ConsumerState<ServerSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _slideController,
            curve: const Cubic(0.4, 0, 0.2, 1),
          ),
        );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _slideController,
        curve: const Interval(0.0, 0.75, curve: Curves.easeOut),
      ),
    );
    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _animateClose() async {
    await _slideController.reverse();
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final connectionState = ref.watch(connectionStateProvider);
    final settings = ref.watch(connectionSettingsProvider);
    final serverInfo = ref.watch(serverInfoProvider);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: GestureDetector(
        onTap: _animateClose,
        child: Container(
          color: Colors.black.withValues(alpha: 0.60),
          child: Column(
            children: [
              const Spacer(),
              SlideTransition(
                position: _slideAnimation,
                child: GestureDetector(
                  onTap: () {}, // Prevent backdrop tap from passing through
                  child: Container(
                    decoration: BoxDecoration(
                      color: KalinkaColors.surfaceRaised,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                      border: const Border(
                        top: BorderSide(color: KalinkaColors.borderDefault),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.7),
                          blurRadius: 60,
                          offset: const Offset(0, -20),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Drag handle
                            Center(
                              child: Container(
                                width: 36,
                                height: 4,
                                margin: const EdgeInsets.only(top: 12),
                                decoration: BoxDecoration(
                                  color: KalinkaColors.surfaceOverlay,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                            // Section label
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                              child: Text(
                                'SERVER',
                                style: KalinkaTextStyles.sectionHeaderMuted,
                              ),
                            ),
                            // Status card
                            _buildStatusCard(
                              connectionState,
                              settings,
                              serverInfo,
                            ),
                            const SizedBox(height: 4),
                            // Separator
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              child: Divider(
                                color: Colors.white.withValues(alpha: 0.07),
                                height: 1,
                              ),
                            ),
                            // Server settings row
                            _SheetRow(
                              icon: Icons.settings_outlined,
                              iconBgColor: KalinkaColors.accent.withValues(
                                alpha: 0.14,
                              ),
                              iconColor: KalinkaColors.accent,
                              label: 'Server settings',
                              sublabel: 'Modules, audio, enrichment',
                              onTap: () async {
                                await _animateClose();
                                widget.onOpenSettings();
                              },
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              child: Divider(
                                color: Colors.white.withValues(alpha: 0.07),
                                height: 1,
                              ),
                            ),
                            // Connect to different server
                            _SheetRow(
                              icon: Icons.language,
                              iconBgColor: KalinkaColors.surfaceOverlay,
                              iconColor: KalinkaColors.textSecondary,
                              label: 'Connect to different server',
                              sublabel: 'Scan network for other instances',
                              onTap: () async {
                                await _animateClose();
                                widget.onOpenDiscovery();
                              },
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              child: Divider(
                                color: Colors.white.withValues(alpha: 0.07),
                                height: 1,
                              ),
                            ),
                            // Disconnect
                            _SheetRow(
                              icon: Icons.logout,
                              iconBgColor: KalinkaColors.statusError.withValues(
                                alpha: 0.12,
                              ),
                              iconColor: KalinkaColors.statusError,
                              label: 'Disconnect',
                              sublabel: '',
                              isDanger: true,
                              onTap: () async {
                                await ref
                                    .read(connectionSettingsProvider.notifier)
                                    .clearDevice();
                                ref
                                    .read(connectionStateProvider.notifier)
                                    .disconnected();
                                await _animateClose();
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard(
    ConnectionStatus connectionState,
    ConnectionSettings settings,
    AsyncValue<ServerInfo> serverInfo,
  ) {
    Color dotColor;
    String stateLabel;
    switch (connectionState) {
      case ConnectionStatus.connected:
        dotColor = KalinkaColors.statusOnline;
        stateLabel = 'Online';
      case ConnectionStatus.reconnecting:
        dotColor = KalinkaColors.statusPending;
        stateLabel = 'Reconnecting';
      case ConnectionStatus.offline:
        dotColor = KalinkaColors.statusError;
        stateLabel = 'Offline';
      case ConnectionStatus.connecting:
        dotColor = KalinkaColors.statusPending;
        stateLabel = 'Connecting';
      case ConnectionStatus.none:
        dotColor = KalinkaColors.textMuted;
        stateLabel = 'Not connected';
    }

    final latencyText = serverInfo.whenOrNull(
      data: (info) => '${info.latencyMs}ms',
    );
    final versionText = serverInfo.whenOrNull(data: (info) => info.version);

    final detailParts = <String>[
      if (settings.host.isNotEmpty) '${settings.host}:${settings.port}',
      if (versionText != null) 'v$versionText',
      if (latencyText != null && connectionState == ConnectionStatus.connected)
        latencyText,
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: KalinkaColors.surfaceInput,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: KalinkaColors.borderDefault),
        ),
        child: Row(
          children: [
            // State dot
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
                boxShadow: connectionState == ConnectionStatus.connected
                    ? [
                        BoxShadow(
                          color: dotColor.withValues(alpha: 0.6),
                          blurRadius: 6,
                        ),
                      ]
                    : null,
              ),
            ),
            const SizedBox(width: 10),
            // Server name + details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    settings.name.isNotEmpty
                        ? settings.name
                        : 'No server configured',
                    style: KalinkaTextStyles.trayRowLabel.copyWith(
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (detailParts.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      detailParts.join(' \u00b7 '),
                      style: KalinkaTextStyles.trayRowSublabel.copyWith(
                        color: KalinkaColors.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            // State label
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: dotColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: dotColor.withValues(alpha: 0.25)),
              ),
              child: Text(
                stateLabel,
                style: KalinkaTextStyles.tagPill.copyWith(
                  color: dotColor,
                  fontSize: 8,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetRow extends StatelessWidget {
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final String label;
  final String sublabel;
  final VoidCallback? onTap;
  final bool isDanger;

  const _SheetRow({
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.label,
    required this.sublabel,
    this.onTap,
    this.isDanger = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap != null
          ? () {
              isDanger
                  ? KalinkaHaptics.heavyImpact()
                  : KalinkaHaptics.lightImpact();
              onTap!();
            }
          : null,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        child: Row(
          children: [
            // Icon tile
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 16, color: iconColor),
            ),
            const SizedBox(width: 14),
            // Label + sublabel
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: isDanger
                        ? KalinkaTextStyles.trayRowLabel.copyWith(
                            color: KalinkaColors.statusError,
                          )
                        : KalinkaTextStyles.trayRowLabel,
                  ),
                  if (sublabel.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(sublabel, style: KalinkaTextStyles.trayRowSublabel),
                  ],
                ],
              ),
            ),
            if (!isDanger)
              Icon(
                Icons.chevron_right,
                size: 18,
                color: KalinkaColors.textMuted,
              ),
          ],
        ),
      ),
    );
  }
}

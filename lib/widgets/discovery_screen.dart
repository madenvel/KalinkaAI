import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/connection_settings_provider.dart';
import '../providers/connection_state_provider.dart';
import '../providers/discovery_provider.dart';
import '../providers/kalinka_player_api_provider.dart';
import '../theme/app_theme.dart';
import 'sonar_animation.dart';

/// Full-screen discovery overlay for finding and connecting to Kalinka servers.
///
/// Used on first launch (no cancel) and when switching servers (with cancel).
class DiscoveryScreen extends ConsumerStatefulWidget {
  /// Optional close callback for tablet Stack overlay mode.
  /// When null (phone Navigator route), [Navigator.pop] is used instead.
  final VoidCallback? onClose;
  final bool allowCancel;
  final String? currentServerHost;

  const DiscoveryScreen({
    super.key,
    this.onClose,
    this.allowCancel = true,
    this.currentServerHost,
  });

  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;

  int? _selectedIndex;
  bool _showManualEntry = false;
  bool _isConnecting = false;
  String? _connectError;

  final _hostController = TextEditingController();
  final _portController = TextEditingController(text: '8000');

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    )..forward();

    // Start scanning
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(discoveryProvider.notifier).startScan();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _connectToServer(String name, String host, int port) async {
    final settings = ref.read(connectionSettingsProvider.notifier);
    final connection = ref.read(connectionStateProvider.notifier);

    setState(() {
      _isConnecting = true;
      _connectError = null;
    });

    try {
      // Save connection settings
      await settings.setDevice(name, host, port);

      // Recreate API client against the newly selected server.
      ref.invalidate(httpClientProvider);
      ref.invalidate(kalinkaProxyProvider);
      final api = ref.read(kalinkaProxyProvider);

      // Attempt connection
      connection.connecting();

      // Try fetching modules as a health check
      await api.listModules();

      connection.connected();

      // Success — close discovery
      if (mounted) {
        await _animateClose();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _connectError = 'Could not connect. Check the address and try again.';
        });
      }
    }
  }

  Future<void> _animateClose() async {
    if (widget.onClose != null) {
      // Tablet Stack overlay mode — animate out, then remove via callback.
      await _fadeController.reverse();
      widget.onClose!();
    } else {
      // Phone Navigator route mode — route transition handles animation.
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final discoveryState = ref.watch(discoveryProvider);
    final showGradient = _isConnecting || discoveryState.isScanning;

    return FadeTransition(
      opacity: _fadeController,
      child: Container(
        decoration: BoxDecoration(
          gradient: showGradient
              ? const RadialGradient(
                  center: Alignment(0, -0.16),
                  radius: 0.42,
                  colors: [Color(0xFF0F0F12), Color(0xFF000000)],
                )
              : null,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top bar with optional cancel
              _buildTopBar(),
              Expanded(
                child: _isConnecting
                    ? _buildConnectingOverlay()
                    : discoveryState.isScanning
                    ? _buildScanningState()
                    : discoveryState.servers.isEmpty
                    ? _buildEmptyState()
                    : _buildServerList(discoveryState),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (widget.allowCancel)
            GestureDetector(
              onTap: _animateClose,
              child: Text(
                'Cancel',
                style: KalinkaTextStyles.cancelButton.copyWith(
                  fontSize: KalinkaTypography.baseSize + 2,
                  color: KalinkaColors.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScanningState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(flex: 2),
        _buildScanningArt(),
        const SizedBox(height: 32),
        Text(
          'Looking for Kalinka',
          style: KalinkaTextStyles.expandedTitle.copyWith(
            fontSize: KalinkaTypography.baseSize + 12,
            color: KalinkaColors.frost,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Scanning your local network\u2026',
          style: KalinkaTextStyles.trayRowSublabel.copyWith(
            fontSize: KalinkaTypography.baseSize + 2,
          ),
        ),
        const Spacer(flex: 3),
      ],
    );
  }

  Widget _buildScanningArt() {
    return SizedBox(
      width: 180,
      height: 180,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SonarAnimation(
            minRadius: 28,
            maxRadius: 88,
            interval: const Duration(milliseconds: 600),
            fadingFactor: 1.4,
            color: KalinkaColors.accentTint.withValues(alpha: 0.85),
            ringCount: 3,
            strokeWidth: 2.4,
          ),
          // Centre icon
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: KalinkaColors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.dns_outlined,
              size: 24,
              color: KalinkaColors.accentTint,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 80),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: KalinkaColors.surfaceElevated,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.dns_outlined,
              size: 26,
              color: KalinkaColors.textMuted,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Nothing found',
            style: KalinkaTextStyles.cardTitle.copyWith(
              color: KalinkaColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No Kalinka servers found on this network.\n'
            'Make sure the server is running and\nyou\'re on the same Wi-Fi.',
            textAlign: TextAlign.center,
            style: KalinkaTextStyles.trayRowSublabel.copyWith(
              fontSize: KalinkaTypography.baseSize + 2,
              color: KalinkaColors.textSecondary,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 24),
          // Scan again button
          _buildFullWidthButton(
            label: 'Scan again',
            color: KalinkaColors.textSecondary,
            bgColor: KalinkaColors.surfaceElevated,
            borderColor: KalinkaColors.borderDefault,
            onTap: () {
              ref.read(discoveryProvider.notifier).rescan();
            },
          ),
          const SizedBox(height: 20),
          // Separator
          Divider(color: Colors.white.withValues(alpha: 0.07), height: 1),
          const SizedBox(height: 16),
          // Manual entry section
          Text(
            'OR ENTER ADDRESS MANUALLY',
            style: KalinkaTextStyles.sectionHeaderMuted,
          ),
          const SizedBox(height: 12),
          _buildManualEntryFields(),
        ],
      ),
    );
  }

  Widget _buildServerList(DiscoveryState discoveryState) {
    final servers = discoveryState.servers;
    final serverCount = servers.length;

    return Column(
      children: [
        const SizedBox(height: 32),
        Text(
          'Looking for Kalinka',
          style: KalinkaTextStyles.expandedTitle.copyWith(
            fontSize: KalinkaTypography.baseSize + 12,
            color: KalinkaColors.frost,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$serverCount server${serverCount == 1 ? '' : 's'} '
          'found on your network',
          style: KalinkaTextStyles.trayRowSublabel.copyWith(
            fontSize: KalinkaTypography.baseSize + 2,
          ),
        ),
        const SizedBox(height: 24),
        // Server list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: servers.length,
            itemBuilder: (context, index) {
              final server = servers[index];
              final isCurrent =
                  widget.currentServerHost != null &&
                  server.host == widget.currentServerHost;
              final isSelected = _selectedIndex == index && !isCurrent;

              // Auto-select best server if nothing selected yet
              if (_selectedIndex == null && !isCurrent) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _selectedIndex = index);
                });
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildServerCard(server, index, isSelected, isCurrent),
              );
            },
          ),
        ),
        // Connect button
        if (!_showManualEntry) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _buildConnectButton(servers),
          ),
          // Manual entry link
          GestureDetector(
            onTap: () => setState(() => _showManualEntry = true),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Text(
                'Enter Address Manually',
                style: KalinkaTextStyles.trayRowSublabel.copyWith(
                  fontSize: KalinkaTypography.baseSize + 2,
                  color: KalinkaColors.textSecondary,
                  decoration: TextDecoration.underline,
                  decorationColor: KalinkaColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
        if (_showManualEntry) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: _buildManualEntryFields(),
          ),
        ],
      ],
    );
  }

  Widget _buildServerCard(
    DiscoveredServer server,
    int index,
    bool isSelected,
    bool isCurrent,
  ) {
    final latencyLabel = server.latencyMs > 0
        ? '${server.latencyMs}ms'
        : 'Latency Unknown';
    final version = server.version;
    final versionLabel = (version != null && version.isNotEmpty)
        ? 'v$version'
        : 'Version unknown';

    Color borderColor;
    Color bgColor;
    if (isCurrent) {
      borderColor = KalinkaColors.statusOnline.withValues(alpha: 0.3);
      bgColor = KalinkaColors.statusOnline.withValues(alpha: 0.05);
    } else if (isSelected) {
      borderColor = KalinkaColors.accent.withValues(alpha: 0.5);
      bgColor = KalinkaColors.accent.withValues(alpha: 0.07);
    } else {
      borderColor = KalinkaColors.borderDefault;
      bgColor = KalinkaColors.surfaceRaised;
    }

    return GestureDetector(
      onTap: isCurrent
          ? null
          : () => setState(() {
              _selectedIndex = index;
              _showManualEntry = false;
            }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            // Icon tile
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isCurrent
                    ? KalinkaColors.statusOnline.withValues(alpha: 0.1)
                    : KalinkaColors.surfaceRaised,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.dns_outlined,
                size: 18,
                color: isCurrent
                    ? KalinkaColors.statusOnline
                    : KalinkaColors.accent,
              ),
            ),
            const SizedBox(width: 12),
            // Name + details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    server.name,
                    style: KalinkaTextStyles.trayRowLabel.copyWith(
                      fontSize: KalinkaTypography.baseSize + 3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${server.host} \u00b7 $latencyLabel',
                    style: KalinkaTextStyles.trayRowSublabel.copyWith(
                      fontSize: KalinkaTypography.baseSize + 2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    versionLabel,
                    style: KalinkaTextStyles.trayRowSublabel.copyWith(
                      fontSize: KalinkaTypography.baseSize + 2,
                      color: KalinkaColors.textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Current pill or signal bars
            if (isCurrent)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: KalinkaColors.statusOnline.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: KalinkaColors.statusOnline.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  'CURRENT',
                  style: KalinkaTextStyles.tagPill.copyWith(
                    color: KalinkaColors.statusOnline,
                    fontSize: KalinkaTypography.baseSize + 0,
                    letterSpacing: 0.8,
                  ),
                ),
              )
            else
              _buildSignalBars(server.signalStrength),
          ],
        ),
      ),
    );
  }

  Widget _buildSignalBars(int strength) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(4, (i) {
        final heights = [5.0, 8.0, 11.0, 14.0];
        final isActive = i < strength;
        return Container(
          width: 3,
          height: heights[i],
          margin: const EdgeInsets.only(left: 2),
          decoration: BoxDecoration(
            color: isActive
                ? KalinkaColors.statusOnline
                : KalinkaColors.textMuted,
            borderRadius: BorderRadius.circular(1.5),
          ),
        );
      }),
    );
  }

  Widget _buildConnectButton(List<DiscoveredServer> servers) {
    final hasSelection =
        _selectedIndex != null && _selectedIndex! < servers.length;
    final selected = hasSelection ? servers[_selectedIndex!] : null;

    return AnimatedOpacity(
      opacity: hasSelection ? 1.0 : 0.35,
      duration: const Duration(milliseconds: 150),
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(13),
          side: const BorderSide(color: KalinkaColors.accent),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: hasSelection
              ? () => _connectToServer(
                  selected!.name,
                  selected.host,
                  selected.port,
                )
              : null,
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return KalinkaColors.accent.withValues(alpha: 0.10);
            }
            return null;
          }),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Center(
              child: Text(
                hasSelection
                    ? 'Connect to ${selected!.name}'
                    : 'Select a server',
                style: KalinkaTextStyles.trayRowLabel.copyWith(
                  color: KalinkaColors.accentTint,
                  fontSize: KalinkaTypography.baseSize + 3,
                  letterSpacing: 0.04,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildManualEntryFields() {
    return Row(
      children: [
        // Host field
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: KalinkaColors.surfaceInput,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: KalinkaColors.borderDefault),
            ),
            child: TextField(
              controller: _hostController,
              style: KalinkaTextStyles.searchBarInput.copyWith(
                fontSize: KalinkaTypography.baseSize + 2,
              ),
              decoration: InputDecoration(
                hintText: '192.168.50.85:8000',
                hintStyle: KalinkaTextStyles.searchPlaceholder.copyWith(
                  fontSize: KalinkaTypography.baseSize + 2,
                  color: KalinkaColors.textSecondary,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 11,
                ),
                isDense: true,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Connect button
        GestureDetector(
          onTap: () {
            final input = _hostController.text.trim();
            if (input.isEmpty) return;

            String host;
            int port;
            if (input.contains(':')) {
              final parts = input.split(':');
              host = parts[0];
              port = int.tryParse(parts[1]) ?? 8000;
            } else {
              host = input;
              port = 8000;
            }
            _connectToServer('Kalinka Server', host, port);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: KalinkaColors.accent),
            ),
            child: Text(
              'Connect',
              style: KalinkaTextStyles.trayRowLabel.copyWith(
                color: KalinkaColors.accentTint,
                fontSize: KalinkaTypography.baseSize + 2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConnectingOverlay() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Spinner
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: const AlwaysStoppedAnimation(KalinkaColors.accent),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Connecting\u2026',
            style: KalinkaTextStyles.expandedTitle.copyWith(
              fontSize: KalinkaTypography.baseSize + 8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Reaching ${ref.read(connectionSettingsProvider).host}',
            style: KalinkaTextStyles.trayRowSublabel.copyWith(
              fontSize: KalinkaTypography.baseSize + 2,
            ),
          ),
          if (_connectError != null) ...[
            const SizedBox(height: 24),
            Text(
              _connectError!,
              textAlign: TextAlign.center,
              style: KalinkaTextStyles.trayRowSublabel.copyWith(
                color: KalinkaColors.statusOffline,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () {
                    final settings = ref.read(connectionSettingsProvider);
                    _connectToServer(
                      settings.name,
                      settings.host,
                      settings.port,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: KalinkaColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: KalinkaColors.borderDefault),
                    ),
                    child: Text(
                      'Try again',
                      style: KalinkaTextStyles.trayRowLabel.copyWith(
                        color: KalinkaColors.textSecondary,
                        fontSize: KalinkaTypography.baseSize + 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isConnecting = false;
                      _connectError = null;
                    });
                  },
                  child: Text(
                    'Cancel',
                    style: KalinkaTextStyles.cancelButton.copyWith(
                      color: KalinkaColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFullWidthButton({
    required String label,
    required Color color,
    required Color bgColor,
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: borderColor),
        ),
        child: Center(
          child: Text(
            label,
            style: KalinkaTextStyles.trayRowLabel.copyWith(
              color: color,
              fontSize: KalinkaTypography.baseSize + 3,
            ),
          ),
        ),
      ),
    );
  }
}

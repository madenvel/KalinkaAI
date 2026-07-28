import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart' show Logger;

import 'kalinka_player_api_provider.dart';

final _logger = Logger();

/// What the server reports about an available release update.
class ServerUpdateInfo {
  final String currentVersion;
  final String? latestVersion;
  final bool updateAvailable;
  final bool upgradeSupported;

  const ServerUpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.updateAvailable,
    required this.upgradeSupported,
  });

  /// True when the app should offer the upgrade.
  bool get canUpgrade => updateAvailable && upgradeSupported;
}

/// Fetched lazily once per app session (Riverpod caches the future for the
/// container's lifetime). Resolves to null when the server predates the
/// endpoint or the request fails — both mean "show nothing".
final serverUpdateProvider = FutureProvider<ServerUpdateInfo?>((ref) async {
  try {
    final info = await ref.read(kalinkaProxyProvider).getServerUpdateInfo();
    if (info == null) return null;
    return ServerUpdateInfo(
      currentVersion: (info['current_version'] ?? '') as String,
      latestVersion: info['latest_version'] as String?,
      updateAvailable: (info['update_available'] ?? false) as bool,
      upgradeSupported: (info['upgrade_supported'] ?? false) as bool,
    );
  } catch (e) {
    _logger.w('Server update check failed', error: e);
    return null;
  }
});

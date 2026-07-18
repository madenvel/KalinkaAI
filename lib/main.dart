import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/music_player_screen.dart';
import 'theme/app_theme.dart';
import 'providers/connection_settings_provider.dart';
import 'providers/onboarding_provider.dart';
import 'providers/web_origin.dart';

/// Dev-only (web): `host:port` of a CORS-enabled proxy to use instead of the
/// serving origin. See scripts/run_web_dev.sh.
const _webBackendOverride = String.fromEnvironment('KALINKA_WEB_BACKEND');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'IBM Plex Sans',
      'IBM Plex Mono',
    ], await rootBundle.loadString('assets/fonts/OFL-IBMPlex.txt'));
    yield LicenseEntryWithLineBreaks([
      'Playfair Display',
    ], await rootBundle.loadString('assets/fonts/OFL-PlayfairDisplay.txt'));
  });

  final prefs = await SharedPreferences.getInstance();

  // Web is served by the server itself (same origin as its API): seed the
  // connection from the origin and skip the wizard/discovery entirely.
  if (kIsWeb) {
    var origin = webServingOrigin();
    final sep = _webBackendOverride.lastIndexOf(':');
    final overridePort = sep > 0
        ? int.tryParse(_webBackendOverride.substring(sep + 1))
        : null;
    if (overridePort != null) {
      origin = (
        host: _webBackendOverride.substring(0, sep),
        port: overridePort,
      );
    }
    if (origin != null) {
      await prefs.setString(ConnectionSettingsNotifier.sharedPrefName, 'Kalinka');
      await prefs.setString(
        ConnectionSettingsNotifier.sharedPrefHost,
        origin.host,
      );
      await prefs.setInt(
        ConnectionSettingsNotifier.sharedPrefPort,
        origin.port,
      );
      await prefs.setBool(
        OnboardingStatusNotifier.sharedPrefOobeComplete,
        true,
      );
    }
  }

  runApp(
    ProviderScope(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      child: const KalinkaApp(),
    ),
  );
}

class KalinkaApp extends StatelessWidget {
  const KalinkaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kalinka',
      theme: AppTheme.dark(),
      debugShowCheckedModeBanner: false,
      home: const MusicPlayerScreen(),
    );
  }
}

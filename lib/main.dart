import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/music_player_screen.dart';
import 'theme/app_theme.dart';
import 'providers/connection_settings_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(
      ['IBM Plex Sans', 'IBM Plex Mono'],
      await rootBundle.loadString('assets/fonts/OFL-IBMPlex.txt'),
    );
    yield LicenseEntryWithLineBreaks(
      ['Playfair Display'],
      await rootBundle.loadString('assets/fonts/OFL-PlayfairDisplay.txt'),
    );
  });

  final prefs = await SharedPreferences.getInstance();

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
      title: 'Kalinka Player',
      theme: AppTheme.dark(),
      debugShowCheckedModeBanner: false,
      home: const MusicPlayerScreen(),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/music_player_screen.dart';
import 'theme/app_theme.dart';
import 'providers/connection_settings_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Hard-coded override for shared prefs
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('Kalinka.host', '192.168.50.85');
  await prefs.setInt('Kalinka.port', 8000);

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

import 'package:flutter/material.dart' show Color;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data_model/data_model.dart';
import 'kalinka_player_api_provider.dart';

/// Display metadata for a single source.
class SourceDisplayInfo {
  final String name;
  final String title;
  final String abbreviation;
  final Color color;

  const SourceDisplayInfo({
    required this.name,
    required this.title,
    required this.abbreviation,
    required this.color,
  });
}

/// Curated palette of muted colors for source badges on dark backgrounds.
const _sourceColors = [
  Color(0xFF5B8DEF), // soft blue
  Color(0xFFE8C87A), // gold
  Color(0xFF4ADE80), // green
  Color(0xFFAB7BF5), // purple
  Color(0xFFEF8B5B), // coral
  Color(0xFF5BE8C8), // teal
  Color(0xFFE85B8D), // pink
  Color(0xFFBBBBC0), // neutral gray
];

/// Fetches enabled input modules from the backend.
final sourceModulesProvider = FutureProvider<List<ModuleInfo>>((ref) async {
  final api = ref.read(kalinkaProxyProvider);
  final modulesAndDevices = await api.listModules();
  return modulesAndDevices.inputModules.where((m) => m.enabled).toList();
});

/// Number of enabled input sources. Returns 0 while loading.
final sourceCountProvider = Provider<int>((ref) {
  return ref.watch(sourceModulesProvider).value?.length ?? 0;
});

/// Maps source name -> display info (title, abbreviation, color).
/// Returns empty map while loading.
final sourceDisplayInfoProvider = Provider<Map<String, SourceDisplayInfo>>((
  ref,
) {
  final modules = ref.watch(sourceModulesProvider).value;
  if (modules == null) return {};
  final map = <String, SourceDisplayInfo>{};
  for (var i = 0; i < modules.length; i++) {
    final m = modules[i];
    map[m.name] = SourceDisplayInfo(
      name: m.name,
      title: m.title,
      abbreviation: m.title.isNotEmpty ? m.title[0].toUpperCase() : '?',
      color: _sourceColors[i % _sourceColors.length],
    );
  }
  return map;
});

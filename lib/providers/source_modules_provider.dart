import 'package:flutter/material.dart' show Color;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data_model/data_model.dart';
import 'connection_settings_provider.dart';
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

/// Backend identifier for the local-files source.
const kLocalSourceName = 'localfiles';

/// Whether [name] is the on-device/local-files source. It's treated as the
/// unmarked default and never shows a source badge.
bool isLocalSource(String name) => name.toLowerCase() == kLocalSourceName;

/// Curated palette of muted colors for source badges on dark backgrounds.
///
/// Slots are ordered so the alphabet-position mapping in [colorForSourceName]
/// lands well-known sources on their established colours:
///   Q (Qobuz) -> slot 0 gold, J (Jamendo) -> slot 1 blue,
///   L (Localfiles) -> slot 3 neutral gray.
const _sourceColors = [
  Color(0xFFE8C87A), // gold
  Color(0xFF5B8DEF), // soft blue
  Color(0xFF4ADE80), // green
  Color(0xFFBBBBC0), // neutral gray
  Color(0xFFAB7BF5), // purple
  Color(0xFFEF8B5B), // coral
  Color(0xFF5BE8C8), // teal
  Color(0xFFE85B8D), // pink
];

/// Returns a stable badge colour for a source based on the first letter of its
/// name. Each letter maps into the palette by its position in the alphabet, so
/// a source's colour never depends on the order the backend returns modules in.
Color colorForSourceName(String name) {
  final letter = name.isNotEmpty ? name[0].toLowerCase() : '?';
  final code = letter.codeUnitAt(0) - 'a'.codeUnitAt(0);
  final index = code >= 0 && code < 26 ? code : _sourceColors.length - 1;
  return _sourceColors[index % _sourceColors.length];
}

/// Fetches enabled input modules from the backend.
final sourceModulesProvider = FutureProvider<List<ModuleInfo>>((ref) async {
  final settings = ref.watch(connectionSettingsProvider);
  if (!settings.isSet) return <ModuleInfo>[];
  final api = ref.read(kalinkaProxyProvider);
  final modulesAndDevices = await api.listModules();
  return modulesAndDevices.inputModules.where((m) => m.enabled).toList();
});

/// Number of enabled input sources. Returns 0 while loading.
///
/// Selects the count off [sourceModulesProvider] rather than watching the whole
/// AsyncValue: on (re)connect the future reloads (data → loading → data), and a
/// plain watch would re-notify this provider mid-build whenever a widget pulled
/// it in during that reload — `setState() called during build`. Loading states
/// carry the previous value forward, so the selected count is stable across the
/// transition and only changes when the module list actually does.
final sourceCountProvider = Provider<int>((ref) {
  return ref.watch(
    sourceModulesProvider.select((m) => m.value?.length ?? 0),
  );
});

/// Maps source name -> display info (title, abbreviation, color).
/// Returns empty map while loading.
///
/// Selects the module list (see [sourceCountProvider] for why) so reload
/// transitions don't trigger a rebuild-during-build.
final sourceDisplayInfoProvider = Provider<Map<String, SourceDisplayInfo>>((
  ref,
) {
  final modules = ref.watch(sourceModulesProvider.select((m) => m.value));
  if (modules == null) return {};
  final map = <String, SourceDisplayInfo>{};
  for (final m in modules) {
    map[m.name] = SourceDisplayInfo(
      name: m.name,
      title: m.title,
      abbreviation: m.title.isNotEmpty ? m.title[0].toUpperCase() : '?',
      color: colorForSourceName(m.name),
    );
  }
  return map;
});

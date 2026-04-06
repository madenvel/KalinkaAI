import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'kalinka_player_api_provider.dart';

class SettingsState {
  final Map<String, dynamic> serverConfig;
  final Map<String, dynamic> stagedChanges;
  final bool isLoading;
  final String? error;

  const SettingsState({
    this.serverConfig = const {},
    this.stagedChanges = const {},
    this.isLoading = false,
    this.error,
  });

  int get pendingCount => stagedChanges.length;
  bool get hasPendingChanges => stagedChanges.isNotEmpty;

  /// Returns the effective value for a key: staged value if present, else server value.
  dynamic getEffective(String key) {
    if (stagedChanges.containsKey(key)) return stagedChanges[key];
    return _getNestedValue(serverConfig, key);
  }

  bool isStaged(String key) => stagedChanges.containsKey(key);

  SettingsState copyWith({
    Map<String, dynamic>? serverConfig,
    Map<String, dynamic>? stagedChanges,
    bool? isLoading,
    String? error,
  }) {
    return SettingsState(
      serverConfig: serverConfig ?? this.serverConfig,
      stagedChanges: stagedChanges ?? this.stagedChanges,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  /// Get a nested value from a map using dot-separated key path.
  static dynamic _getNestedValue(Map<String, dynamic> map, String key) {
    final parts = key.split('.');
    dynamic current = map;
    for (final part in parts) {
      if (current is Map<String, dynamic> && current.containsKey(part)) {
        current = current[part];
      } else {
        return null;
      }
    }
    return current;
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(
  SettingsNotifier.new,
);

class SettingsNotifier extends Notifier<SettingsState> {
  @override
  SettingsState build() {
    return const SettingsState();
  }

  /// Load the full server configuration from the API.
  Future<void> loadConfig() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final api = ref.read(kalinkaProxyProvider);
      final config = await api.getSettings();
      state = state.copyWith(serverConfig: config, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Stage a change for a given key path (dot-separated).
  void stageChange(String key, dynamic value) {
    final newStaged = Map<String, dynamic>.from(state.stagedChanges);
    newStaged[key] = value;
    state = state.copyWith(stagedChanges: newStaged);
  }

  /// Remove a staged change.
  void unstageChange(String key) {
    final newStaged = Map<String, dynamic>.from(state.stagedChanges);
    newStaged.remove(key);
    state = state.copyWith(stagedChanges: newStaged);
  }

  /// Discard all staged changes.
  void discardAll() {
    state = state.copyWith(stagedChanges: {});
  }

  /// Merge staged changes into a deep copy of the server config.
  Future<Map<String, dynamic>> buildMergedConfig() async {
    final merged = _deepCopy(state.serverConfig);
    for (final entry in state.stagedChanges.entries) {
      _setNestedValue(merged, entry.key, entry.value);
    }
    return merged;
  }

  /// Recursively deep-copy a Map so mutations don't bleed into the original state.
  static Map<String, dynamic> _deepCopy(Map<String, dynamic> map) {
    return map.map((key, value) {
      if (value is Map<String, dynamic>) {
        return MapEntry(key, _deepCopy(value));
      }
      if (value is List) {
        return MapEntry(key, List<dynamic>.from(value));
      }
      return MapEntry(key, value);
    });
  }

  /// Apply staged changes: save to server, then let restart provider handle restart.
  Future<void> applyChanges() async {
    try {
      final api = ref.read(kalinkaProxyProvider);
      final serverChanges = {
        for (final entry in state.stagedChanges.entries)
          _toServerKey(entry.key): entry.value,
      };
      await api.saveSettings(serverChanges);
      // Clear staged changes and update local config
      final merged = await buildMergedConfig();
      state = state.copyWith(serverConfig: merged, stagedChanges: {});
    } catch (e) {
      state = state.copyWith(error: 'Failed to save: $e');
      rethrow;
    }
  }

  /// Convert a UI key path (root.fields.base_config.fields.server.fields.port.value)
  /// to the server's expected key format (root.base_config.server.port).
  static String _toServerKey(String key) {
    var result = key;
    if (result.endsWith('.value')) {
      result = result.substring(0, result.length - '.value'.length);
    }
    return result.replaceAll('.fields.', '.');
  }

  /// Set a nested value in a map using dot-separated key path.
  static void _setNestedValue(
    Map<String, dynamic> map,
    String key,
    dynamic value,
  ) {
    final parts = key.split('.');
    Map<String, dynamic> current = map;
    for (int i = 0; i < parts.length - 1; i++) {
      if (current[parts[i]] is! Map<String, dynamic>) {
        current[parts[i]] = <String, dynamic>{};
      }
      current = current[parts[i]] as Map<String, dynamic>;
    }
    current[parts.last] = value;
  }
}

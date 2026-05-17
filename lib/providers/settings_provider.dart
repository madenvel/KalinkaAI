import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data_model/presentation_schema.dart';
import 'kalinka_player_api_provider.dart';

/// Settings state keyed entirely by flat dotted paths (`base_config.server.port`,
/// `input_modules.qobuz.email`, …). The backend owns the presentation schema —
/// we never regroup, relabel, or re-derive anything on the client.
class SettingsState {
  final PresentationSchema? schema;
  final String? schemaVersion;
  final Map<String, dynamic> values; // Path → server value
  final Map<String, dynamic> stagedChanges;
  final bool isLoading;
  final String? error;

  const SettingsState({
    this.schema,
    this.schemaVersion,
    this.values = const {},
    this.stagedChanges = const {},
    this.isLoading = false,
    this.error,
  });

  int get pendingCount => stagedChanges.length;
  bool get hasPendingChanges => stagedChanges.isNotEmpty;

  /// Staged value if present, else the last-known server value.
  dynamic getEffective(String path) {
    if (stagedChanges.containsKey(path)) return stagedChanges[path];
    return values[path];
  }

  bool isStaged(String path) => stagedChanges.containsKey(path);

  SettingsState copyWith({
    PresentationSchema? schema,
    String? schemaVersion,
    Map<String, dynamic>? values,
    Map<String, dynamic>? stagedChanges,
    bool? isLoading,
    String? error,
  }) {
    return SettingsState(
      schema: schema ?? this.schema,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      values: values ?? this.values,
      stagedChanges: stagedChanges ?? this.stagedChanges,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(
  SettingsNotifier.new,
);

/// Global toggle for "expert" importance fields.
class ExpertModeNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void toggle() => state = !state;
  void set(bool value) => state = value;
}

final expertModeProvider = NotifierProvider<ExpertModeNotifier, bool>(
  ExpertModeNotifier.new,
);

class SettingsNotifier extends Notifier<SettingsState> {
  @override
  SettingsState build() => const SettingsState();

  Future<void> loadConfig() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final api = ref.read(kalinkaProxyProvider);
      // Fetch schema + values in parallel.
      final results = await Future.wait([
        api.getSettingsSchema(),
        api.getSettings(),
      ]);
      final schema = results[0] as PresentationSchema;
      final envelope = (results[1] as Map).cast<String, dynamic>();
      final values = (envelope['values'] as Map? ?? {}).cast<String, dynamic>();
      final valuesVersion = envelope['schema_version'] as String?;

      state = state.copyWith(
        schema: schema,
        // If the two endpoints disagree (plugin reloaded between the two
        // fetches), prefer the schema version — UI rendering is driven by it.
        schemaVersion:
            valuesVersion == schema.schemaVersion
                ? schema.schemaVersion
                : schema.schemaVersion,
        values: values,
        stagedChanges: {},
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Stage a change for ``path``. If the new value matches the current
  /// server-side value (i.e. the user just typed their way back to the
  /// original), the entry is *unstaged* instead — the row no longer
  /// shows the "Staged" pill and the pending-changes counter goes back
  /// down. Without this, manually reverting an edit would leave a
  /// no-op change in the staging area and dirty the apply button.
  void stageChange(String path, dynamic value) {
    if (_valuesEqual(value, state.values[path])) {
      if (state.stagedChanges.containsKey(path)) unstageChange(path);
      return;
    }
    final existing = state.stagedChanges[path];
    if (_valuesEqual(value, existing)) return; // No-op write
    final newStaged = Map<String, dynamic>.from(state.stagedChanges);
    newStaged[path] = value;
    state = state.copyWith(stagedChanges: newStaged);
  }

  void unstageChange(String path) {
    final newStaged = Map<String, dynamic>.from(state.stagedChanges);
    newStaged.remove(path);
    state = state.copyWith(stagedChanges: newStaged);
  }

  void discardAll() {
    state = state.copyWith(stagedChanges: {});
  }

  /// Deep equality for the JSON-ish values we receive over the wire
  /// (primitives, lists, maps). Used by [stageChange] so reverting a
  /// folder list or any other collection back to the server value
  /// reliably unstages, even though `List<dynamic>` identities differ.
  static bool _valuesEqual(dynamic a, dynamic b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return a == b;
    if (a is num && b is num) return a == b;
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (!_valuesEqual(a[i], b[i])) return false;
      }
      return true;
    }
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final key in a.keys) {
        if (!b.containsKey(key)) return false;
        if (!_valuesEqual(a[key], b[key])) return false;
      }
      return true;
    }
    return a == b;
  }

  Future<void> applyChanges() async {
    final version = state.schemaVersion;
    if (version == null || state.stagedChanges.isEmpty) return;
    try {
      final api = ref.read(kalinkaProxyProvider);
      await api.saveSettings(
        schemaVersion: version,
        changes: Map<String, dynamic>.from(state.stagedChanges),
      );
      // Fold staged → values on success.
      final newValues = Map<String, dynamic>.from(state.values);
      newValues.addAll(state.stagedChanges);
      state = state.copyWith(values: newValues, stagedChanges: {});
    } catch (e) {
      state = state.copyWith(error: 'Failed to save: $e');
      rethrow;
    }
  }
}

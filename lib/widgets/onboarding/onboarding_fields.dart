import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data_model/presentation_schema.dart';
import '../../providers/settings_provider.dart';
import '../settings_controls/settings_row.dart';
import '../settings_renderer.dart' show buildFieldControl;

/// Look up a [FieldSpec] by exact dotted path. The expert list carries every
/// settable field across the whole config tree (both tiers), so it's the
/// simplest complete index.
FieldSpec? findSchemaField(PresentationSchema? schema, String path) {
  if (schema == null) return null;
  for (final f in schema.expertFields) {
    if (f.path == path) return f;
  }
  return null;
}

/// All modules of [kind] (`input_module` / `device`) across every page.
List<ModuleSpec> schemaModulesOfKind(PresentationSchema? schema, String kind) {
  if (schema == null) return const [];
  return [
    for (final page in schema.pages)
      for (final m in page.modules)
        if (m.kind == kind) m,
  ];
}

/// The server's built-in renderer volume module. Never offered as a choice
/// and never toggled by the wizard: disabling it drops volume control for
/// every output.
const kRendererVolumeModuleId = 'kalinka-renderer';

/// Device plugins the wizard may offer: real controllable devices only —
/// the developer stub and the built-in renderer volume module stay out.
List<ModuleSpec> setupDeviceModules(PresentationSchema? schema) => [
  for (final m in schemaModulesOfKind(schema, 'device'))
    if (m.id != 'dummydevice' && m.id != kRendererVolumeModuleId) m,
];

/// Boolean field paths that mark a module as Smart Search capable. The
/// schema doesn't tag capabilities yet, so this suffix set is the one piece
/// of app-side convention: Jamendo's mood search and localfiles' embedder.
const kSmartSearchFieldSuffixes = ['.ai_search_enabled', '.embedder.enabled'];

/// The module's `enabled` field, if it has one.
FieldSpec? moduleEnabledField(ModuleSpec m) {
  for (final f in m.fields) {
    if (f.path.endsWith('.enabled')) return f;
  }
  return null;
}

/// Whether the module is on. Local files has no meaningful off state — the
/// server's library backend is built in — so it always reads enabled.
bool inputModuleEnabled(SettingsState state, ModuleSpec m) {
  if (m.id == 'localfiles') return true;
  final f = moduleEnabledField(m);
  if (f == null) return false;
  return (state.getEffective(f.path) ?? f.defaultValue ?? false) == true;
}

/// The module's Smart Search toggle, wherever the schema keeps it — a
/// top-level field (Jamendo) or inside a section (localfiles' embedder).
FieldSpec? smartSearchFieldOf(ModuleSpec m) {
  bool matches(FieldSpec f) =>
      kSmartSearchFieldSuffixes.any((s) => f.path.endsWith(s));
  for (final f in m.fields) {
    if (matches(f)) return f;
  }
  FieldSpec? walk(List<SectionSpec> sections) {
    for (final s in sections) {
      for (final f in s.fields) {
        if (matches(f)) return f;
      }
      final nested = walk(s.sections);
      if (nested != null) return nested;
    }
    return null;
  }

  return walk(m.sections);
}

/// The card fields for a module during setup: its top-level simple fields
/// (the schema serves only the simple tier here) minus the enable flag and
/// the Smart Search toggle, which get their own controls.
List<FieldSpec> setupModuleFields(ModuleSpec m) => [
  for (final f in m.fields)
    if (!f.readonly &&
        !f.path.endsWith('.enabled') &&
        !kSmartSearchFieldSuffixes.any((s) => f.path.endsWith(s)))
      f,
];

/// A field the module cannot work without: credentials (password widgets)
/// and folder lists must be non-empty. Everything else has a usable default.
bool _fieldSatisfied(SettingsState state, FieldSpec f) {
  final value = state.getEffective(f.path) ?? f.defaultValue;
  if (f.widget == WidgetKind.password) {
    return value != null && value.toString().trim().isNotEmpty;
  }
  if (f.widget == WidgetKind.folderList || f.widget == WidgetKind.listEditor) {
    return value is List && value.any((e) => e.toString().trim().isNotEmpty);
  }
  return true;
}

/// The fields keeping an enabled module from being ready, by label.
List<String> moduleMissingFields(SettingsState state, ModuleSpec m) => [
  for (final f in setupModuleFields(m))
    if (!_fieldSatisfied(state, f)) f.label,
];

/// A source counts once it is on and nothing required is missing.
bool moduleConfigured(SettingsState state, ModuleSpec m) =>
    inputModuleEnabled(state, m) && moduleMissingFields(state, m).isEmpty;

/// The Add-music gate: at least one source ready to feed the library.
bool anySourceConfigured(SettingsState state) => schemaModulesOfKind(
  state.schema,
  'input_module',
).any((m) => moduleConfigured(state, m));

/// Modules whose Smart Search toggle should be offered: enabled sources
/// that declare one.
List<(ModuleSpec, FieldSpec)> smartSearchCandidates(SettingsState state) => [
  for (final m in schemaModulesOfKind(state.schema, 'input_module'))
    if (inputModuleEnabled(state, m))
      if (smartSearchFieldOf(m) case final f?) (m, f),
];

/// Whether any offered Smart Search toggle is currently on.
bool anySmartSearchEnabled(SettingsState state) => smartSearchCandidates(
  state,
).any((c) => (state.getEffective(c.$2.path) ?? c.$2.defaultValue) == true);

/// Renders a single backend config field inside the setup wizard, bound to
/// the shared settings staging flow ([SettingsNotifier.stageChange]).
///
/// Unlike [SchemaFieldRenderer] this allows overriding the backend's label
/// and help text with wizard-specific copy, and silently renders nothing
/// when the connected server's schema doesn't carry the field (older
/// server or plugin not installed).
class OnboardingFieldRow extends ConsumerWidget {
  final String path;
  final String? label;
  final String? help;

  const OnboardingFieldRow({
    super.key,
    required this.path,
    this.label,
    this.help,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final field = findSchemaField(state.schema, path);
    if (field == null || field.readonly) return const SizedBox.shrink();

    final value = state.getEffective(path) ?? field.defaultValue;

    // Same full-width rules as the settings screen's field renderer.
    final vertical =
        field.widget == WidgetKind.listEditor ||
        field.widget == WidgetKind.folderList ||
        field.widget == WidgetKind.enumPills ||
        field.widget == WidgetKind.enumDropdown ||
        field.widget == WidgetKind.text ||
        field.widget == WidgetKind.password ||
        field.widget == WidgetKind.path ||
        field.widget == WidgetKind.url;

    return SettingsRow(
      label: label ?? field.label,
      sublabel: help ?? field.help,
      isStaged: state.isStaged(path),
      isVertical: vertical,
      control: buildFieldControl(
        field: field,
        value: value,
        options: state,
        onChanged: (v) => notifier.stageChange(path, v),
      ),
    );
  }
}

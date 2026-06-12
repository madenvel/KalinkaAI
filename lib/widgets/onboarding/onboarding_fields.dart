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
        state: state,
        onChanged: (v) => notifier.stageChange(path, v),
      ),
    );
  }
}

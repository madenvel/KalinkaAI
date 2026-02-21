import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_theme.dart';
import '../settings_controls/module_header_row.dart';
import '../settings_controls/settings_enum_pills.dart';
import '../settings_controls/settings_list_editor.dart';
import '../settings_controls/settings_numeric_input.dart';
import '../settings_controls/settings_password_input.dart';
import '../settings_controls/settings_row.dart';
import '../settings_controls/settings_section.dart';
import '../settings_controls/settings_text_input.dart';
import '../settings_controls/settings_toggle.dart';

/// Modules settings tab: shows module cards (Local Files, Qobuz, etc.)
/// with their sub-settings in collapsible sections using ModuleHeaderRow.
class ModulesTab extends ConsumerStatefulWidget {
  const ModulesTab({super.key});

  @override
  ConsumerState<ModulesTab> createState() => _ModulesTabState();
}

class _ModulesTabState extends ConsumerState<ModulesTab> {
  final Set<String> _expanded = {};
  bool _didAutoExpand = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(settingsProvider);
    final config = state.serverConfig;
    final notifier = ref.read(settingsProvider.notifier);

    // Navigate the API schema: root → fields → input_modules → fields
    final rootFields =
        (config['root'] as Map<String, dynamic>?)?['fields']
            as Map<String, dynamic>? ??
        {};
    final inputModulesSection =
        rootFields['input_modules'] as Map<String, dynamic>? ?? {};
    final inputModules =
        inputModulesSection['fields'] as Map<String, dynamic>? ?? {};

    // Auto-expand first module on initial build
    if (!_didAutoExpand && inputModules.isNotEmpty) {
      _expanded.add(inputModules.keys.first);
      _didAutoExpand = true;
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        _sectionLabel('Input modules'),
        ...inputModules.entries.map((entry) {
          final moduleName = entry.key;
          final moduleConfig = entry.value is Map<String, dynamic>
              ? entry.value as Map<String, dynamic>
              : <String, dynamic>{};
          return _buildModuleCard(moduleName, moduleConfig, state, notifier);
        }),
      ],
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Text(
        label.toUpperCase(),
        style: KalinkaTextStyles.sectionHeaderMuted,
      ),
    );
  }

  Widget _buildModuleCard(
    String moduleName,
    Map<String, dynamic> moduleConfig,
    SettingsState state,
    SettingsNotifier notifier,
  ) {
    final isExpanded = _expanded.contains(moduleName);
    final (icon, color) = ModuleHeaderRow.iconForModule(moduleName);
    final displayName =
        moduleConfig['title'] as String? ?? _formatModuleName(moduleName);
    final subtitle = _deriveSubtitle(moduleName, moduleConfig, state);
    final statusStr = moduleConfig['status'] as String?;
    final moduleStatus = switch (statusStr) {
      'ready' => ModuleStatus.ready,
      'error' => ModuleStatus.error,
      _ => null,
    };
    final baseKeyPath = 'root.fields.input_modules.fields.$moduleName';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: KalinkaColors.miniPlayerSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KalinkaColors.borderDefault),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ModuleHeaderRow(
            title: displayName,
            subtitle: subtitle,
            icon: icon,
            iconColor: color,
            status: moduleStatus,
            expanded: isExpanded,
            onToggle: () {
              setState(() {
                if (isExpanded) {
                  _expanded.remove(moduleName);
                } else {
                  _expanded.add(moduleName);
                }
              });
            },
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 340),
            curve: const Cubic(0.4, 0, 0.2, 1),
            alignment: Alignment.topCenter,
            child: isExpanded
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _buildFieldWidgets(
                      baseKeyPath,
                      moduleConfig,
                      state,
                      notifier,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  /// Build a divider-separated list of field widgets for a section schema object.
  /// [baseKeyPath] is the path to the section in the config (without trailing .fields).
  List<Widget> _buildFieldWidgets(
    String baseKeyPath,
    Map<String, dynamic> sectionConfig,
    SettingsState state,
    SettingsNotifier notifier,
  ) {
    final widgets = <Widget>[];
    final fields = sectionConfig['fields'] as Map<String, dynamic>? ?? {};
    for (final field in fields.entries) {
      final fieldSchema = field.value is Map<String, dynamic>
          ? field.value as Map<String, dynamic>
          : <String, dynamic>{};
      final fieldKeyPath = '$baseKeyPath.fields.${field.key}';
      widgets.add(
        const Divider(
          height: 1,
          thickness: 1,
          color: KalinkaColors.borderDefault,
        ),
      );
      widgets.add(
        _buildDynamicField(
          field.key,
          fieldSchema,
          fieldKeyPath,
          state,
          notifier,
        ),
      );
    }
    return widgets;
  }

  /// Render a single schema field. [fieldSchema] has keys: type, title, value,
  /// fields (for sections), values (for enums), password (bool), etc.
  /// [keyPath] points to the field object itself; staging uses keyPath + ".value".
  Widget _buildDynamicField(
    String fieldName,
    Map<String, dynamic> fieldSchema,
    String keyPath,
    SettingsState state,
    SettingsNotifier notifier,
  ) {
    final type = fieldSchema['type'] as String? ?? 'str';
    final title =
        fieldSchema['title'] as String? ?? _formatFieldName(fieldName);
    final valueKeyPath = '$keyPath.value';
    final isStaged = state.isStaged(valueKeyPath);
    final effectiveValue =
        state.getEffective(valueKeyPath) ?? fieldSchema['value'];

    // Section: render as collapsible sub-section
    if (type == 'section') {
      return SettingsSection(
        title: title,
        showTopBorder: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _buildFieldWidgets(keyPath, fieldSchema, state, notifier),
        ),
      );
    }

    // Boolean
    if (type == 'bool') {
      return SettingsRow(
        label: title,
        isStaged: isStaged,
        control: SettingsToggle(
          value: effectiveValue == true,
          onChanged: (v) => notifier.stageChange(valueKeyPath, v),
        ),
      );
    }

    // List
    if (type.startsWith('list[')) {
      return SettingsRow(
        label: title,
        isStaged: isStaged,
        isVertical: true,
        control: SettingsListEditor(
          items:
              (effectiveValue as List?)?.map((e) => e.toString()).toList() ??
              [],
          addHint: 'Add $fieldName...',
          onChanged: (items) => notifier.stageChange(valueKeyPath, items),
        ),
      );
    }

    // Enum
    if (type == 'enum') {
      final options =
          (fieldSchema['values'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [];
      return SettingsRow(
        label: title,
        isStaged: isStaged,
        isVertical: true,
        control: SettingsEnumPills(
          options: options,
          selected: (effectiveValue ?? '').toString(),
          onChanged: (v) => notifier.stageChange(valueKeyPath, v),
        ),
      );
    }

    // Number
    if (type == 'int' || type == 'float') {
      return SettingsRow(
        label: title,
        isStaged: isStaged,
        control: SettingsNumericInput(
          value: effectiveValue as num? ?? 0,
          onChanged: (v) => notifier.stageChange(valueKeyPath, v),
        ),
      );
    }

    // Password-like strings
    final isPassword =
        fieldName.toLowerCase().contains('password') ||
        fieldSchema['password'] == true ||
        fieldName.toLowerCase().contains('secret') ||
        fieldName.toLowerCase().contains('token');

    if (isPassword) {
      return SettingsRow(
        label: title,
        isStaged: isStaged,
        control: SettingsPasswordInput(
          value: (effectiveValue ?? '').toString(),
          onChanged: (v) => notifier.stageChange(valueKeyPath, v),
        ),
      );
    }

    // Default: text input
    return SettingsRow(
      label: title,
      isStaged: isStaged,
      control: SettingsTextInput(
        value: (effectiveValue ?? '').toString(),
        width: 145,
        onChanged: (v) => notifier.stageChange(valueKeyPath, v),
      ),
    );
  }

  /// Derive a subtitle from module config values.
  String _deriveSubtitle(
    String moduleName,
    Map<String, dynamic> config,
    SettingsState state,
  ) {
    final parts = <String>[];
    final name = moduleName.toLowerCase();
    final fields = config['fields'] as Map<String, dynamic>? ?? {};
    final basePath = 'root.fields.input_modules.fields.$moduleName.fields';

    if (name.contains('local') || name.contains('file')) {
      final musicFolders =
          state.getEffective('$basePath.music_folders.value') ??
          (fields['music_folders'] as Map?)?['value'];
      if (musicFolders is List && musicFolders.isNotEmpty) {
        parts.add(
          musicFolders.length == 1
              ? musicFolders.first.toString()
              : '${musicFolders.length} directories',
        );
      }
      final scanInterval =
          state.getEffective('$basePath.scan_interval_minutes.value') ??
          (fields['scan_interval_minutes'] as Map?)?['value'];
      if (scanInterval is num && scanInterval > 0) {
        parts.add('${scanInterval}m scan');
      }
    }

    if (name.contains('qobuz')) {
      final format =
          state.getEffective('$basePath.format.value') ??
          (fields['format'] as Map?)?['value'];
      if (format != null) parts.add(format.toString());
    }

    if (name.contains('tidal')) {
      final quality =
          state.getEffective('$basePath.quality.value') ??
          (fields['quality'] as Map?)?['value'];
      if (quality != null) parts.add(quality.toString());
    }

    if (parts.isEmpty) return 'Input module';
    return parts.join(' \u00b7 ');
  }

  String _formatModuleName(String name) {
    return name
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : w)
        .join(' ');
  }

  String _formatFieldName(String name) {
    return name
        .replaceAll('_', ' ')
        .split(' ')
        .map(
          (w) => w.isNotEmpty
              ? '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}'
              : w,
        )
        .join(' ');
  }
}

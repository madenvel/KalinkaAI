import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_theme.dart';
import '../settings_controls/footer_note.dart';
import '../settings_controls/module_header_row.dart';
import '../settings_controls/settings_enum_pills.dart';
import '../settings_controls/settings_list_editor.dart';
import '../settings_controls/settings_numeric_input.dart';
import '../settings_controls/settings_password_input.dart';
import '../settings_controls/settings_row.dart';
import '../settings_controls/settings_section.dart';
import '../settings_controls/settings_text_input.dart';
import '../settings_controls/settings_toggle.dart';

/// Devices settings tab: shows device plugin cards with their settings.
class DevicesTab extends ConsumerStatefulWidget {
  const DevicesTab({super.key});

  @override
  ConsumerState<DevicesTab> createState() => _DevicesTabState();
}

class _DevicesTabState extends ConsumerState<DevicesTab> {
  final Set<String> _expanded = {};
  bool _didAutoExpand = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(settingsProvider);
    final config = state.serverConfig;
    final notifier = ref.read(settingsProvider.notifier);

    // Navigate the API schema: root → fields → devices → fields
    final rootFields =
        (config['root'] as Map<String, dynamic>?)?['fields']
            as Map<String, dynamic>? ??
        {};
    final devicesSection =
        rootFields['devices'] as Map<String, dynamic>? ?? {};
    final devices = devicesSection['fields'] as Map<String, dynamic>? ?? {};

    // Auto-expand first device on initial build
    if (!_didAutoExpand && devices.isNotEmpty) {
      _expanded.add(devices.keys.first);
      _didAutoExpand = true;
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        _sectionLabel('Devices'),
        ...devices.entries.map((entry) {
          final deviceName = entry.key;
          final deviceConfig = entry.value is Map<String, dynamic>
              ? entry.value as Map<String, dynamic>
              : <String, dynamic>{};
          return _buildDeviceCard(deviceName, deviceConfig, state, notifier);
        }),
        const FooterNote(
          text:
              'Devices are auto-discovered. Configuration changes require a server restart.',
        ),
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

  Widget _buildDeviceCard(
    String deviceName,
    Map<String, dynamic> deviceConfig,
    SettingsState state,
    SettingsNotifier notifier,
  ) {
    final isExpanded = _expanded.contains(deviceName);
    final (icon, color) = ModuleHeaderRow.iconForDevice(deviceName);
    final displayName =
        deviceConfig['title'] as String? ?? _formatDeviceName(deviceName);
    final statusStr = deviceConfig['status'] as String?;
    final deviceStatus = switch (statusStr) {
      'ready' => ModuleStatus.ready,
      'error' => ModuleStatus.error,
      _ => null,
    };
    final baseKeyPath = 'root.fields.devices.fields.$deviceName';

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
            subtitle: 'Output device',
            icon: icon,
            iconColor: color,
            status: deviceStatus,
            expanded: isExpanded,
            onToggle: () {
              setState(() {
                if (isExpanded) {
                  _expanded.remove(deviceName);
                } else {
                  _expanded.add(deviceName);
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
                      deviceConfig,
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
  /// [baseKeyPath] is the path to the section (without trailing .fields).
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
        _buildDeviceField(
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
  Widget _buildDeviceField(
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

  String _formatDeviceName(String name) {
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

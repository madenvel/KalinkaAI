import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data_model/presentation_schema.dart';
import '../providers/connection_settings_provider.dart';
import '../providers/server_info_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import 'settings_controls/footer_note.dart';
import 'settings_controls/module_header_row.dart';
import 'settings_controls/settings_card.dart';
import 'settings_controls/settings_enum_pills.dart';
import 'settings_controls/settings_list_editor.dart';
import 'settings_controls/settings_numeric_input.dart';
import 'settings_controls/settings_password_input.dart';
import 'settings_controls/settings_row.dart';
import 'settings_controls/settings_section.dart';
import 'settings_controls/settings_slider.dart';
import 'settings_controls/settings_text_input.dart';
import 'settings_controls/settings_toggle.dart';
import 'settings_controls/warning_note.dart';

// ---------------------------------------------------------------------------
// Icons
// ---------------------------------------------------------------------------

/// Map a backend material icon name to a Flutter IconData. Only icons the
/// backend actually emits need entries here.
IconData _iconFromName(String? name) {
  switch (name) {
    case 'folder_outlined':
      return Icons.folder_outlined;
    case 'music_note_outlined':
      return Icons.music_note_outlined;
    case 'speaker_outlined':
      return Icons.speaker_outlined;
    case 'waves_outlined':
      return Icons.waves_outlined;
    case 'extension_outlined':
    default:
      return Icons.extension_outlined;
  }
}

Color _colorFromHex(String? hex, Color fallback) {
  if (hex == null || !hex.startsWith('#')) return fallback;
  final value = int.tryParse(hex.substring(1), radix: 16);
  if (value == null) return fallback;
  return Color(0xFF000000 | value);
}

// ---------------------------------------------------------------------------
// Banner
// ---------------------------------------------------------------------------

class SchemaBanner extends StatelessWidget {
  final BannerSpec banner;
  const SchemaBanner({super.key, required this.banner});

  @override
  Widget build(BuildContext context) {
    switch (banner.severity) {
      case Severity.warning:
      case Severity.danger:
        return WarningNote(message: banner.text);
      case Severity.info:
        final hasTitle = banner.title != null && banner.title!.isNotEmpty;
        final hasBody = banner.text.isNotEmpty;
        // Text-only info banner → muted footer style.
        if (!hasTitle && hasBody) {
          return FooterNote(text: banner.text);
        }
        // Title present (possibly with body) → prominent hero-style row.
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasTitle)
                Text(
                  banner.title!,
                  style: KalinkaTextStyles.trayRowLabel.copyWith(
                    fontSize: KalinkaTypography.baseSize + 6,
                    color: KalinkaColors.textPrimary,
                  ),
                ),
              if (hasTitle && hasBody) const SizedBox(height: 2),
              if (hasBody)
                Text(
                  banner.text,
                  style: KalinkaTextStyles.trayRowSublabel.copyWith(
                    fontSize: KalinkaTypography.baseSize + 1,
                  ),
                ),
            ],
          ),
        );
    }
  }
}

// ---------------------------------------------------------------------------
// Field renderer: FieldSpec → SettingsRow+control
// ---------------------------------------------------------------------------

class SchemaFieldRenderer extends ConsumerWidget {
  final FieldSpec field;
  const SchemaFieldRenderer({super.key, required this.field});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final isStaged = state.isStaged(field.path);
    final value = state.getEffective(field.path) ?? field.defaultValue;

    // Sliders carry their own label + value readout + range labels, so we
    // render them bare (no SettingsRow wrapper — that would duplicate the
    // label).
    if (field.widget == WidgetKind.numberSlider) {
      return _buildSlider(value, notifier);
    }

    // Pills, list editors, text inputs, and multi-line controls need the full
    // row width — they render stacked below the label rather than inline.
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
      label: field.label,
      sublabel: field.help,
      isStaged: isStaged,
      isVertical: vertical,
      control: _buildControl(value, notifier),
    );
  }

  Widget _buildSlider(dynamic value, SettingsNotifier notifier) {
    final v = (value as num? ?? 0).toDouble();
    final c = field.constraints;
    final min = c?.sliderMin ?? c?.ge ?? 0;
    final max = c?.sliderMax ?? c?.le ?? 100;
    final unit = c?.unit ?? '';
    String fmt(num n) =>
        '${n.toInt()}${unit.isEmpty ? '' : ' $unit'}';
    return SettingsSlider(
      label: field.label,
      value: v.clamp(min, max),
      min: min,
      max: max,
      divisions: 100,
      minLabel: fmt(min),
      maxLabel: fmt(max),
      valueLabel: fmt(v),
      onChanged: (nv) => notifier.stageChange(field.path, nv.round()),
    );
  }

  Widget _buildControl(dynamic value, SettingsNotifier notifier) {
    void stage(dynamic v) => notifier.stageChange(field.path, v);
    switch (field.widget) {
      case WidgetKind.toggle:
        return SettingsToggle(value: value == true, onChanged: stage);
      case WidgetKind.numberInput:
        return SettingsNumericInput(
          value: value is num ? value : 0,
          onChanged: stage,
        );
      case WidgetKind.numberSlider:
        // Handled above; unreachable here.
        return const SizedBox.shrink();
      case WidgetKind.enumPills:
      case WidgetKind.enumDropdown:
        return SettingsEnumPills(
          options: field.enumValues ?? const [],
          selected: (value ?? '').toString(),
          onChanged: stage,
        );
      case WidgetKind.listEditor:
      case WidgetKind.folderList:
        final items =
            (value as List?)?.map((e) => e.toString()).toList() ?? const [];
        return SettingsListEditor(
          items: items,
          addHint: field.widget == WidgetKind.folderList
              ? 'Add folder...'
              : 'Add item...',
          onChanged: stage,
        );
      case WidgetKind.password:
        return SettingsPasswordInput(
          value: (value ?? '').toString(),
          onChanged: stage,
        );
      case WidgetKind.text:
      case WidgetKind.path:
      case WidgetKind.url:
        return SettingsTextInput(
          value: (value ?? '').toString(),
          onChanged: stage,
        );
    }
  }
}

// ---------------------------------------------------------------------------
// Section renderer
// ---------------------------------------------------------------------------

class SchemaSectionRenderer extends ConsumerWidget {
  final SectionSpec section;
  final bool isTopLevel;
  const SchemaSectionRenderer({
    super.key,
    required this.section,
    this.isTopLevel = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expertMode = ref.watch(expertModeProvider);
    if (section.importance == Importance.expert && !expertMode) {
      return const SizedBox.shrink();
    }

    final visibleFields = section.fields
        .where((f) => f.importance != Importance.expert || expertMode)
        .toList();
    final visibleSubSections = section.sections
        .where((s) => s.importance != Importance.expert || expertMode)
        .toList();

    if (visibleFields.isEmpty && visibleSubSections.isEmpty) {
      return const SizedBox.shrink();
    }

    final rows = <Widget>[
      for (final f in visibleFields)
        SchemaFieldRenderer(key: ValueKey(f.path), field: f),
      for (final s in visibleSubSections)
        SchemaSectionRenderer(key: ValueKey(s.id), section: s),
    ];
    final separated = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      if (i > 0) {
        separated.add(
          const Divider(
            height: 1,
            thickness: 1,
            color: KalinkaColors.borderSubtle,
          ),
        );
      }
      separated.add(rows[i]);
    }
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: separated,
    );

    // Advanced sections render inside a collapsible at the top level.
    if (isTopLevel && section.importance == Importance.advanced) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...section.banners.map((b) => SchemaBanner(banner: b)),
          SettingsCard(
            children: [
              SettingsSection(
                title: section.title,
                showTopBorder: false,
                child: body,
              ),
            ],
          ),
        ],
      );
    }

    // Top-level normal section: label + card.
    if (isTopLevel) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionLabel(
            section.title,
            subtitle: section.id == 'base_config.server'
                ? const _ServerAddressBadge()
                : null,
          ),
          ...section.banners.map((b) => SchemaBanner(banner: b)),
          SettingsCard(children: [body]),
        ],
      );
    }

    // Nested section: inline collapsible.
    return SettingsSection(
      title: section.title,
      showTopBorder: false,
      initiallyExpanded: section.importance == Importance.normal,
      child: body,
    );
  }

  static Widget _sectionLabel(String label, {Widget? subtitle}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: KalinkaTextStyles.sectionHeaderMuted,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            subtitle,
          ],
        ],
      ),
    );
  }
}

/// Shows `host:port · v<version>` on the metadata line under the Server
/// section title. Version is shown in full; the Text ellipsises if it
/// overflows the available width.
class _ServerAddressBadge extends ConsumerWidget {
  const _ServerAddressBadge();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(connectionSettingsProvider);
    final serverInfo = ref.watch(serverInfoProvider);
    final version = serverInfo.whenOrNull(data: (i) => i.version);

    final parts = <String>[
      if (settings.host.isNotEmpty) '${settings.host}:${settings.port}',
      if (version != null && version != 'Unknown') 'v$version',
    ];
    if (parts.isEmpty) return const SizedBox.shrink();
    return Text(
      parts.join(' \u00b7 '),
      style: KalinkaTextStyles.trayRowSublabel.copyWith(
        fontSize: KalinkaTypography.baseSize + 1,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

// ---------------------------------------------------------------------------
// Module card renderer
// ---------------------------------------------------------------------------

class SchemaModuleCard extends ConsumerStatefulWidget {
  final ModuleSpec module;
  final bool initiallyExpanded;
  const SchemaModuleCard({
    super.key,
    required this.module,
    this.initiallyExpanded = false,
  });

  @override
  ConsumerState<SchemaModuleCard> createState() => _SchemaModuleCardState();
}

class _SchemaModuleCardState extends ConsumerState<SchemaModuleCard> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.module;
    final state = ref.watch(settingsProvider);
    final expertMode = ref.watch(expertModeProvider);

    final status = switch (m.status) {
      'ready' => ModuleStatus.ready,
      'error' => ModuleStatus.error,
      'disabled' => ModuleStatus.disabled,
      _ => null,
    };

    // Preview subtitle from backend-declared preview_fields.
    final subtitle = _subtitleFor(m, state);
    final icon = _iconFromName(m.icon);
    final color = _colorFromHex(m.iconColor, KalinkaColors.textSecondary);

    final visibleSections = m.sections
        .where((s) => s.importance != Importance.expert || expertMode)
        .toList();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: KalinkaColors.surfaceRaised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KalinkaColors.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ModuleHeaderRow(
            title: m.title,
            subtitle: subtitle,
            icon: icon,
            iconColor: color,
            status: status,
            expanded: _expanded,
            onToggle: () => setState(() => _expanded = !_expanded),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 340),
            curve: const Cubic(0.4, 0, 0.2, 1),
            alignment: Alignment.topCenter,
            child: _expanded
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (m.errorMessage != null)
                        WarningNote(message: m.errorMessage!),
                      for (final b in m.banners) SchemaBanner(banner: b),
                      for (final s in visibleSections) ...[
                        const Divider(
                          height: 1,
                          thickness: 1,
                          color: KalinkaColors.borderSubtle,
                        ),
                        SchemaSectionRenderer(
                          key: ValueKey(s.id),
                          section: s,
                        ),
                      ],
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  /// Build the subtitle by reading `module.previewFields` from the staged/server values.
  String _subtitleFor(ModuleSpec m, SettingsState state) {
    final parts = <String>[];
    final prefix = m.kind == 'device'
        ? 'devices.${m.id}'
        : 'input_modules.${m.id}';
    for (final name in m.previewFields) {
      final v = state.getEffective('$prefix.$name');
      if (v == null) continue;
      if (v is List) {
        if (v.isNotEmpty) {
          parts.add(v.length == 1 ? v.first.toString() : '${v.length} items');
        }
      } else if (v is num) {
        if (v > 0) parts.add(v.toString());
      } else {
        final s = v.toString();
        if (s.isNotEmpty) parts.add(s);
      }
    }
    if (parts.isEmpty) {
      return m.kind == 'device' ? 'Output device' : 'Input module';
    }
    return parts.join(' \u00b7 ');
  }
}

// ---------------------------------------------------------------------------
// Page renderer
// ---------------------------------------------------------------------------

class SchemaPageRenderer extends ConsumerWidget {
  final PageSpec page;
  const SchemaPageRenderer({super.key, required this.page});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expertMode = ref.watch(expertModeProvider);
    final visibleSections = page.sections
        .where((s) => s.importance != Importance.expert || expertMode)
        .toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        for (final b in page.banners) SchemaBanner(banner: b),
        for (final s in visibleSections)
          SchemaSectionRenderer(
            key: ValueKey(s.id),
            section: s,
            isTopLevel: true,
          ),
        if (page.modules.isNotEmpty) ...[
          for (int i = 0; i < page.modules.length; i++)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 8 : 0),
              child: SchemaModuleCard(
                key: ValueKey(page.modules[i].id),
                module: page.modules[i],
                initiallyExpanded: i == 0,
              ),
            ),
        ],
      ],
    );
  }
}

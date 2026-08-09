import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data_model/presentation_schema.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_theme.dart';
import '../settings_controls/module_header_row.dart' show ModuleHeaderRow;
import '../settings_controls/settings_card.dart';
import '../settings_controls/settings_toggle.dart';
import '../settings_controls/warning_note.dart';
import 'onboarding_fields.dart';
import 'onboarding_step_scaffold.dart';

/// Wizard step: enable and configure the sources that feed the library.
///
/// One card per installed input plugin, straight off the schema: the enable
/// switch, then the module's own simple fields while it is on — the schema
/// serves only the simple tier here, so whatever a plugin marks simple is
/// its setup form. Smart Search toggles are held back for their own step.
/// A source reads Ready once nothing required is missing (credentials,
/// folder lists); the step's Continue gates on at least one ready source.
class OnboardingMusicSourcesStep extends ConsumerWidget {
  const OnboardingMusicSourcesStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(settingsProvider);
    final modules = schemaModulesOfKind(state.schema, 'input_module');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final m in modules) _ModuleCard(module: m),
        if (!anySourceConfigured(state))
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: WarningNote(
              severity: WarningNoteSeverity.warning,
              message:
                  'Set up at least one source to continue — add a music '
                  'folder, or switch on a streaming source and fill in '
                  'what it asks for.',
            ),
          ),
        const OnboardingNote(
          'Folders live on the Kalinka server, not on this device. The '
          'first scan of a big library takes a while — it runs in the '
          'background after setup.',
        ),
      ],
    );
  }
}

/// One input plugin: header with switch and readiness pill, its schema
/// fields underneath while enabled, and what's missing called out inline.
class _ModuleCard extends ConsumerWidget {
  final ModuleSpec module;

  const _ModuleCard({required this.module});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    final isLocalFiles = module.id == 'localfiles';
    final enabledField = moduleEnabledField(module);
    final enabled = inputModuleEnabled(state, module);
    final missing = enabled
        ? moduleMissingFields(state, module)
        : const <String>[];
    final fields = setupModuleFields(module);

    final (icon, iconColor) = ModuleHeaderRow.iconForModule(module.id);

    final sublabel = isLocalFiles
        ? 'Your music folders on the server — always on.'
        : enabledField == null
        ? 'Set up later in Settings.'
        : 'Streaming source — can be changed later in Settings.';

    Widget toggle = SettingsToggle(
      value: enabled,
      onChanged: (v) {
        if (isLocalFiles || enabledField == null) return;
        notifier.stageChange(enabledField.path, v);
      },
    );
    if (isLocalFiles || enabledField == null) {
      toggle = IgnorePointer(child: Opacity(opacity: 0.4, child: toggle));
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: SettingsCard(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: KalinkaColors.surfaceOverlay,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: iconColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              module.title,
                              style: KalinkaTextStyles.trayRowLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _StatusPill(enabled: enabled, missing: missing),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(sublabel, style: KalinkaTextStyles.trayRowSublabel),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                toggle,
              ],
            ),
          ),
          if (enabled)
            for (final f in fields) ...[
              Divider(
                height: 1,
                thickness: 1,
                color: Colors.white.withValues(alpha: 0.07),
              ),
              OnboardingFieldRow(path: f.path),
            ],
          if (missing.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: WarningNote(
                severity: WarningNoteSeverity.warning,
                message:
                    '${missing.join(' and ')} '
                    '${missing.length == 1 ? 'is' : 'are'} required for '
                    '${module.title} to work.',
              ),
            ),
        ],
      ),
    );
  }
}

/// Readiness at a glance: READY once nothing required is missing, NEEDS
/// SETUP while something is, OFF when disabled. Staged readiness, not live —
/// the plugin only runs against these values after the final restart.
class _StatusPill extends StatelessWidget {
  final bool enabled;
  final List<String> missing;

  const _StatusPill({required this.enabled, required this.missing});

  @override
  Widget build(BuildContext context) {
    final (label, color) = !enabled
        ? ('OFF', KalinkaColors.textMuted)
        : missing.isEmpty
        ? ('READY', KalinkaColors.statusOnline)
        : ('NEEDS SETUP', KalinkaColors.statusPendingLight);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: KalinkaTextStyles.tagPill.copyWith(
          color: color,
          fontSize: KalinkaTypography.baseSize - 1,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

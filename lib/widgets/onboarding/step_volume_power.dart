import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data_model/presentation_schema.dart';
import '../../providers/renderer_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/haptics.dart';
import '../settings_controls/settings_card.dart';
import 'onboarding_fields.dart';
import 'onboarding_step_scaffold.dart';

/// Wizard step: what controls the volume (and power) where the music plays.
///
/// The default — "Kalinka Renderer default" — leaves volume with the output
/// itself and shows the built-in renderer volume module's options. Choosing a
/// device plugin (MusicCast today) stages its `enabled` flag and shows its
/// options; the output playing now is handed to it right after the final
/// restart, once the module is loaded (see the attach task in
/// `onboarding_screen.dart`). Only real device plugins are ever toggled —
/// the built-in module stays enabled no matter the choice.
class OnboardingVolumePowerStep extends ConsumerWidget {
  const OnboardingVolumePowerStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final outputName = ref.watch(
      rendererListProvider.select((s) => s.active?.friendlyName),
    );

    final choices = setupDeviceModules(state.schema);
    // The built-in module: its options render under the default choice. An
    // older server doesn't have it — the default row then reads "None", the
    // old semantics.
    ModuleSpec? rendererModule;
    for (final m in schemaModulesOfKind(state.schema, 'device')) {
      if (m.id == kRendererVolumeModuleId) {
        rendererModule = m;
        break;
      }
    }

    String enabledPath(ModuleSpec m) => 'devices.${m.id}.enabled';
    ModuleSpec? selected;
    for (final m in choices) {
      if (state.getEffective(enabledPath(m)) == true) {
        selected = m;
        break;
      }
    }

    void select(ModuleSpec? device) {
      KalinkaHaptics.lightImpact();
      for (final m in choices) {
        notifier.stageChange(enabledPath(m), m == device);
      }
    }

    final defaultTitle = rendererModule != null
        ? 'Kalinka Renderer default'
        : 'None';
    final defaultSubtitle = rendererModule != null
        ? 'The output applies volume itself — nothing else is controlled.'
        : choices.isEmpty
        ? 'No controllable devices were found — Kalinka plays straight '
              'to the audio output.'
        : 'Kalinka plays straight to the audio output — nothing else '
              'is controlled.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (outputName != null && outputName.isNotEmpty)
          OnboardingNote(
            'These choices apply to “$outputName” — the output the music '
            'plays on. Other outputs keep their own setting, changed any '
            'time from the gear in the output picker.',
          ),
        const OnboardingSectionLabel('Volume control'),
        SettingsCard(
          children: [
            _ChoiceRow(
              title: defaultTitle,
              subtitle: defaultSubtitle,
              selected: selected == null,
              // With nothing else to choose, the row is informational only.
              enabled: choices.isNotEmpty,
              onTap: () => select(null),
            ),
            for (final m in choices)
              _ChoiceRow(
                title: m.title,
                subtitle:
                    'An amplifier or receiver the music plays into — its '
                    'volume and power take over.',
                selected: selected == m,
                onTap: () => select(m),
              ),
          ],
        ),
        if (selected == null && rendererModule != null) ...[
          OnboardingSectionLabel('${rendererModule.title} options'),
          SettingsCard(
            children: [
              for (final f in rendererModule.fields)
                if (!f.path.endsWith('.enabled'))
                  OnboardingFieldRow(path: f.path),
            ],
          ),
        ],
        if (selected != null) ...[
          OnboardingSectionLabel('${selected.title} options'),
          SettingsCard(
            children: [
              for (final f in selected.fields)
                if (!f.path.endsWith('.enabled'))
                  OnboardingFieldRow(path: f.path),
            ],
          ),
          OnboardingNote(
            'Kalinka finds compatible devices on your network by itself — '
            'set an address only if yours isn’t found. '
            '${outputName != null && outputName.isNotEmpty ? '“$outputName” hands' : 'The output playing now hands'} '
            'volume and power to ${selected.title} when setup finishes.',
          ),
        ],
      ],
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _ChoiceRow({
    required this.title,
    required this.subtitle,
    required this.selected,
    this.enabled = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.45,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          color: selected ? KalinkaColors.surfaceElevated : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected
                        ? KalinkaColors.accent
                        : KalinkaColors.borderDefault,
                    width: 1.5,
                  ),
                ),
                child: selected
                    ? Center(
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: KalinkaColors.accent,
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: KalinkaTextStyles.trayRowLabel),
                    const SizedBox(height: 2),
                    Text(subtitle, style: KalinkaTextStyles.trayRowSublabel),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

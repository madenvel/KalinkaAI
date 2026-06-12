import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data_model/presentation_schema.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/haptics.dart';
import '../settings_controls/settings_card.dart';
import 'onboarding_fields.dart';
import 'onboarding_step_scaffold.dart';

/// Wizard step: amplifier/receiver control plugin — None (default) or one
/// of the device plugins the server ships (MusicCast today). Selecting a
/// device reveals its options and the power automation toggles.
class OnboardingDeviceControlStep extends ConsumerWidget {
  const OnboardingDeviceControlStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    // The dummy device is a developer stub — never offer it during setup.
    final devices = schemaModulesOfKind(
      state.schema,
      'device',
    ).where((m) => m.id != 'dummydevice').toList();

    String enabledPath(ModuleSpec m) => 'devices.${m.id}.enabled';
    ModuleSpec? selected;
    for (final m in devices) {
      if (state.getEffective(enabledPath(m)) == true) {
        selected = m;
        break;
      }
    }

    void select(ModuleSpec? device) {
      KalinkaHaptics.lightImpact();
      for (final m in devices) {
        notifier.stageChange(enabledPath(m), m == device);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const OnboardingSectionLabel('Device control'),
        SettingsCard(
          children: [
            _DeviceChoiceRow(
              title: 'None',
              subtitle: devices.isEmpty
                  ? 'No controllable devices were found — Kalinka plays '
                        'straight to the audio output you picked.'
                  : 'Kalinka plays straight to the audio output you '
                        'picked — nothing else is controlled.',
              selected: selected == null,
              // With nothing else to choose, the row is informational only.
              enabled: devices.isNotEmpty,
              onTap: () => select(null),
            ),
            for (final m in devices)
              _DeviceChoiceRow(
                title: m.title,
                subtitle:
                    'Powers the device on and off and switches it to '
                    'the right input automatically.',
                selected: selected == m,
                onTap: () => select(m),
              ),
          ],
        ),
        if (selected != null) ...[
          OnboardingSectionLabel('${selected.title} options'),
          SettingsCard(
            children: [
              for (final f in selected.fields)
                if (!f.path.endsWith('.enabled'))
                  OnboardingFieldRow(path: f.path),
            ],
          ),
          const OnboardingSectionLabel('Power automation'),
          const SettingsCard(
            children: [
              OnboardingFieldRow(
                path: 'base_config.device_automation.auto_power_on',
                label: 'Power on with playback',
                help: 'Wake the device when music starts.',
              ),
              OnboardingFieldRow(
                path: 'base_config.device_automation.auto_power_off',
                label: 'Power off when idle',
                help: 'Switch the device off after playback stops.',
              ),
            ],
          ),
        ],
        const OnboardingNote(
          'Kalinka finds compatible devices on your network by itself — '
          'set an address only if yours isn’t found. You can change this '
          'any time in Settings.',
        ),
      ],
    );
  }
}

class _DeviceChoiceRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _DeviceChoiceRow({
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

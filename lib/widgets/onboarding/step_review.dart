import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data_model/presentation_schema.dart' show ModuleSpec;
import '../../providers/connection_settings_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_theme.dart';
import '../settings_controls/settings_card.dart';
import '../settings_controls/warning_note.dart';
import 'onboarding_fields.dart';
import 'onboarding_step_scaffold.dart';
import 'step_features.dart';

/// Wizard step: read-only summary of every choice, ahead of the final
/// apply-and-restart.
class OnboardingReviewStep extends ConsumerWidget {
  const OnboardingReviewStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(settingsProvider);
    final connection = ref.watch(connectionSettingsProvider);

    String effectiveString(String path, String fallback) {
      final v = state.getEffective(path);
      final s = v?.toString().trim() ?? '';
      return s.isEmpty ? fallback : s;
    }

    // Audio device: prefer the live option label over the raw ALSA id.
    final deviceValue = effectiveString(
      'base_config.output.alsa.device',
      'System default',
    );
    var deviceLabel = deviceValue;
    for (final o
        in state.optionsFor('base_config.output.alsa.device') ?? const []) {
      if (o.value == deviceValue) {
        deviceLabel = o.label;
        break;
      }
    }

    final folders =
        (state.getEffective('input_modules.localfiles.music_folders') as List?)
            ?.map((e) => e.toString())
            .where((f) => f.trim().isNotEmpty)
            .toList() ??
        const <String>[];

    // Device control choice: the first enabled device plugin, if any.
    final devices = schemaModulesOfKind(
      state.schema,
      'device',
    ).where((m) => m.id != 'dummydevice').toList();
    ModuleSpec? controlledDevice;
    for (final m in devices) {
      if (state.getEffective('devices.${m.id}.enabled') == true) {
        controlledDevice = m;
        break;
      }
    }
    var deviceControlValue = 'None';
    if (controlledDevice != null) {
      final zone = effectiveString(
        'devices.${controlledDevice.id}.zone_name',
        '',
      );
      deviceControlValue = zone.isEmpty
          ? controlledDevice.title
          : '${controlledDevice.title} · $zone';
    }

    final aiSearchOn =
        state.getEffective(OnboardingFeaturesStep.aiSearchPath) == true;
    final acoustidOn =
        state.getEffective(OnboardingFeaturesStep.acoustidEnabledPath) == true;
    final acoustidKey = effectiveString(
      OnboardingFeaturesStep.acoustidKeyPath,
      '',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const OnboardingSectionLabel('Your setup'),
        SettingsCard(
          children: [
            _SummaryRow(
              label: 'Server',
              value:
                  '${effectiveString('base_config.server.service_name', connection.name)}'
                  ' · ${connection.host}:${connection.port}',
            ),
            _SummaryRow(label: 'Audio output', value: deviceLabel),
            _SummaryRow(
              label: 'Music folders',
              value: folders.isEmpty ? 'None yet' : folders.join('\n'),
            ),
            _SummaryRow(label: 'Device control', value: deviceControlValue),
            _SummaryRow(label: 'AI search', value: aiSearchOn ? 'On' : 'Off'),
            _SummaryRow(label: 'AcoustID', value: acoustidOn ? 'On' : 'Off'),
          ],
        ),
        if (folders.isEmpty)
          const WarningNote(
            severity: WarningNoteSeverity.warning,
            message:
                'No music folders configured — the library will be '
                'empty. Go back to add folders, or add them later in '
                'Settings.',
          ),
        if (acoustidOn && acoustidKey.isEmpty)
          const WarningNote(
            severity: WarningNoteSeverity.warning,
            message:
                'AcoustID is on but has no API key — fingerprinting '
                'won’t run until one is set.',
          ),
        const OnboardingNote(
          'Finishing saves these settings and restarts the server so '
          'they take effect — that takes about half a minute. The app '
          'reconnects automatically and drops you on the play queue.',
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: KalinkaTextStyles.trayRowSublabel.copyWith(
                fontSize: KalinkaTypography.baseSize + 2,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: KalinkaTextStyles.trayRowLabel.copyWith(
                fontSize: KalinkaTypography.baseSize + 3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/connection_settings_provider.dart';
import '../../providers/renderer_host_provider.dart'
    show rendererIdentityProvider;
import '../../providers/renderer_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_theme.dart';
import '../renderer_switcher.dart' show rendererDisplayName;
import '../settings_controls/settings_card.dart';
import '../settings_controls/warning_note.dart';
import 'onboarding_fields.dart';
import 'onboarding_step_scaffold.dart';

/// Wizard step: the setup at a glance, ahead of the final apply-and-restart.
///
/// Every row is derived from the same schema state the steps stage into, so
/// the summary cannot drift from the flow; rows carry a Change link back to
/// their step via [onEdit]. The server name rides here as the one optional
/// server-side touch — the server already has a default name.
class OnboardingReviewStep extends ConsumerWidget {
  /// Jumps the wizard to a step (1 = music, 2 = smart search, 3 = sound).
  final void Function(int step)? onEdit;

  const OnboardingReviewStep({super.key, this.onEdit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(settingsProvider);
    final connection = ref.watch(connectionSettingsProvider);
    final renderers = ref.watch(rendererListProvider);
    final ownId = ref.watch(rendererIdentityProvider).value?.rendererId;

    final modules = schemaModulesOfKind(state.schema, 'input_module');
    final enabledModules = [
      for (final m in modules)
        if (inputModuleEnabled(state, m)) m,
    ];
    final notReady = [
      for (final m in enabledModules)
        if (!moduleConfigured(state, m)) m,
    ];

    final sourcesValue = enabledModules.isEmpty
        ? 'None'
        : enabledModules
              .map(
                (m) => moduleConfigured(state, m)
                    ? '${m.title} · Ready'
                    : '${m.title} · Needs setup',
              )
              .join('\n');

    final smartCandidates = smartSearchCandidates(state);
    final smartValue = smartCandidates.isEmpty
        ? 'Not available'
        : smartCandidates
              .map(
                (c) =>
                    '${c.$1.title} · '
                    '${(state.getEffective(c.$2.path) ?? c.$2.defaultValue) == true ? 'On' : 'Off'}',
              )
              .join('\n');

    final activeRenderer = renderers.active;
    String outputValue;
    if (renderers.supported) {
      outputValue = activeRenderer == null
          ? 'None connected'
          : rendererDisplayName(
              activeRenderer,
              isSelf: activeRenderer.rendererId == ownId,
            );
    } else {
      // Pre-renderer server: the ALSA option label, over the raw id.
      final deviceValue =
          state
              .getEffective('base_config.output.alsa.device')
              ?.toString()
              .trim() ??
          '';
      outputValue = deviceValue.isEmpty ? 'System default' : deviceValue;
      for (final o
          in state.optionsFor('base_config.output.alsa.device') ?? const []) {
        if (o.value == deviceValue) {
          outputValue = o.label;
          break;
        }
      }
    }

    String? volumeControlTitle;
    for (final m in setupDeviceModules(state.schema)) {
      if (state.getEffective('devices.${m.id}.enabled') == true) {
        volumeControlTitle = m.title;
        break;
      }
    }
    final hasRendererModule = schemaModulesOfKind(
      state.schema,
      'device',
    ).any((m) => m.id == kRendererVolumeModuleId);
    final volumeValue =
        volumeControlTitle ??
        (hasRendererModule ? 'Kalinka Renderer default' : 'None');

    final serviceName = state
        .getEffective('base_config.server.service_name')
        ?.toString()
        .trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const OnboardingSectionLabel('Server'),
        const SettingsCard(
          children: [
            OnboardingFieldRow(
              path: 'base_config.server.service_name',
              label: 'Server name',
              help:
                  'Optional — how this server shows up on your network. '
                  'It already has a perfectly good default.',
            ),
          ],
        ),
        const OnboardingSectionLabel('Your setup'),
        SettingsCard(
          children: [
            _SummaryRow(
              label: 'Server',
              value:
                  '${(serviceName?.isNotEmpty ?? false) ? serviceName! : connection.name}'
                  ' · ${connection.host}:${connection.port}',
            ),
            _SummaryRow(
              label: 'Music sources',
              value: sourcesValue,
              onChange: onEdit == null ? null : () => onEdit!(1),
            ),
            _SummaryRow(
              label: 'Smart search',
              value: smartValue,
              onChange: onEdit == null ? null : () => onEdit!(2),
            ),
            _SummaryRow(
              label: 'Audio output',
              value: outputValue,
              onChange: onEdit == null ? null : () => onEdit!(3),
            ),
            _SummaryRow(
              label: 'Volume & power',
              value: volumeValue,
              onChange: onEdit == null ? null : () => onEdit!(3),
            ),
          ],
        ),
        if (renderers.supported && activeRenderer == null)
          const WarningNote(
            severity: WarningNoteSeverity.warning,
            message:
                'No outputs connected — nothing can play yet. Install the '
                'Kalinka renderer on the machine wired to your speakers, '
                'or open the web player in a browser.',
          ),
        for (final m in notReady)
          WarningNote(
            severity: WarningNoteSeverity.warning,
            message:
                '${m.title} still needs '
                '${moduleMissingFields(state, m).join(' and ')} — it '
                'won’t work until that is set.',
          ),
        const OnboardingNote(
          'Starting saves these settings and restarts the server so they '
          'take effect — that takes about half a minute. Library indexing '
          'and any Smart Search analysis run in the background afterwards; '
          'the app reconnects by itself and drops you on the play queue.',
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onChange;

  const _SummaryRow({required this.label, required this.value, this.onChange});

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
          if (onChange != null) ...[
            const SizedBox(width: 12),
            Semantics(
              label: 'Change $label',
              button: true,
              child: GestureDetector(
                onTap: onChange,
                behavior: HitTestBehavior.opaque,
                child: Text(
                  'Change',
                  style: KalinkaTextStyles.trayRowSublabel.copyWith(
                    fontSize: KalinkaTypography.baseSize + 2,
                    color: KalinkaColors.accentTint,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

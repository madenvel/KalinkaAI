import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_theme.dart';
import '../settings_controls/settings_card.dart';
import '../settings_controls/settings_row.dart';
import '../settings_controls/settings_section.dart';
import '../settings_controls/settings_slider.dart';
import '../settings_controls/settings_toggle.dart';
import '../settings_controls/settings_text_input.dart';
import '../settings_controls/settings_numeric_input.dart';
import '../settings_controls/settings_enum_pills.dart';
import '../settings_controls/sub_section_label.dart';
import '../settings_controls/warning_note.dart';

// Base schema paths (root → fields → base_config → fields → <subsection>)
const _srv = 'root.fields.base_config.fields.server.fields';
const _out = 'root.fields.base_config.fields.output.fields.alsa.fields';
const _inp = 'root.fields.base_config.fields.input.fields.http.fields';
const _dec = 'root.fields.base_config.fields.decoder.fields';
const _fix = 'root.fields.base_config.fields.fixups.fields';
const _da = 'root.fields.base_config.fields.device_automation.fields';

/// General settings tab: server, device automation, audio output, hardware fixups, buffers.
class GeneralTab extends ConsumerWidget {
  const GeneralTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        // ---- SERVER ----
        _sectionLabel('Server'),
        SettingsCard(
          children: [
            SettingsRow(
              label: 'Service name',
              sublabel: 'Shown during Zeroconf discovery',
              isStaged: state.isStaged('$_srv.service_name.value'),
              control: SettingsTextInput(
                value:
                    (state.getEffective('$_srv.service_name.value') ?? '')
                        .toString(),
                width: 145,
                onChanged: (v) =>
                    notifier.stageChange('$_srv.service_name.value', v),
              ),
            ),
            SettingsRow(
              label: 'Network interface',
              sublabel: 'Bind to specific interface or "all"',
              isStaged: state.isStaged('$_srv.interface.value'),
              control: SettingsTextInput(
                value:
                    (state.getEffective('$_srv.interface.value') ?? 'all')
                        .toString(),
                width: 145,
                onChanged: (v) =>
                    notifier.stageChange('$_srv.interface.value', v),
              ),
            ),
            SettingsRow(
              label: 'Port',
              sublabel: 'HTTP API port',
              isStaged: state.isStaged('$_srv.port.value'),
              control: SettingsNumericInput(
                value: state.getEffective('$_srv.port.value') ?? 8000,
                onChanged: (v) => notifier.stageChange('$_srv.port.value', v),
              ),
            ),
            SettingsRow(
              label: 'Log level',
              isStaged: state.isStaged('$_srv.log_level.value'),
              isVertical: true,
              control: SettingsEnumPills(
                options: const ['debug', 'info', 'warning', 'error'],
                selected:
                    (state.getEffective('$_srv.log_level.value') ?? 'info')
                        .toString(),
                onChanged: (v) =>
                    notifier.stageChange('$_srv.log_level.value', v),
              ),
            ),
          ],
        ),

        // ---- DEVICE AUTOMATION ----
        _sectionLabel('Device automation'),
        SettingsCard(
          children: [
            SettingsRow(
              label: 'Auto power on',
              sublabel: 'Turn on device when playback starts',
              isStaged: state.isStaged('$_da.auto_power_on.value'),
              control: SettingsToggle(
                value: state.getEffective('$_da.auto_power_on.value') == true,
                onChanged: (v) =>
                    notifier.stageChange('$_da.auto_power_on.value', v),
              ),
            ),
            SettingsRow(
              label: 'Auto power off',
              sublabel: 'Turn off device when playback stops',
              isStaged: state.isStaged('$_da.auto_power_off.value'),
              control: SettingsToggle(
                value: state.getEffective('$_da.auto_power_off.value') == true,
                onChanged: (v) =>
                    notifier.stageChange('$_da.auto_power_off.value', v),
              ),
            ),
            SettingsRow(
              label: 'Pause timeout',
              sublabel:
                  'Stop playback if paused for this many seconds (0 = disabled)',
              isStaged: state.isStaged('$_da.pause_timeout_seconds.value'),
              control: SettingsNumericInput(
                value:
                    state.getEffective('$_da.pause_timeout_seconds.value') ??
                    60,
                onChanged: (v) =>
                    notifier.stageChange('$_da.pause_timeout_seconds.value', v),
              ),
            ),
          ],
        ),

        // ---- AUDIO OUTPUT ----
        _sectionLabel('Audio output'),
        SettingsCard(
          children: [
            SettingsRow(
              label: 'ALSA device',
              sublabel: 'Hardware output device identifier',
              isStaged: state.isStaged('$_out.device.value'),
              control: SettingsTextInput(
                value:
                    (state.getEffective('$_out.device.value') ?? 'default')
                        .toString(),
                hintText: 'default',
                width: 145,
                onChanged: (v) =>
                    notifier.stageChange('$_out.device.value', v),
              ),
            ),
            SettingsSection(
              title: 'Advanced ALSA settings',
              showTopBorder: false,
              child: Column(
                children: [
                  SettingsSlider(
                    label: 'Output latency',
                    value:
                        (state.getEffective('$_out.latency_ms.value') as num? ??
                                160)
                            .toDouble(),
                    min: 0,
                    max: 500,
                    divisions: 100,
                    minLabel: '0 ms',
                    maxLabel: '500 ms',
                    valueLabel:
                        '${(state.getEffective('$_out.latency_ms.value') as num? ?? 160).toInt()} ms',
                    onChanged: (v) => notifier.stageChange(
                      '$_out.latency_ms.value',
                      v.round(),
                    ),
                  ),
                  SettingsSlider(
                    label: 'Period size',
                    value:
                        (state.getEffective('$_out.period_ms.value') as num? ??
                                40)
                            .toDouble(),
                    min: 0,
                    max: 500,
                    divisions: 100,
                    minLabel: '0 ms',
                    maxLabel: '500 ms',
                    valueLabel:
                        '${(state.getEffective('$_out.period_ms.value') as num? ?? 40).toInt()} ms',
                    onChanged: (v) => notifier.stageChange(
                      '$_out.period_ms.value',
                      v.round(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        // ---- HARDWARE FIXUPS ----
        _sectionLabel('Hardware fixups'),
        const WarningNote(
          message:
              'These settings work around hardware-specific bugs. Leave at defaults unless you experience audio glitches on track changes.',
        ),
        SettingsCard(
          children: [
            SettingsRow(
              label: 'Sleep after format setup',
              sublabel:
                  'Delay (ms) after ALSA format change. Increase if audio glitches when format switches.',
              isStaged: state.isStaged(
                '$_fix.alsa_sleep_after_format_setup_ms.value',
              ),
              control: SettingsNumericInput(
                value:
                    state.getEffective(
                        '$_fix.alsa_sleep_after_format_setup_ms.value') ??
                    0,
                onChanged: (v) => notifier.stageChange(
                  '$_fix.alsa_sleep_after_format_setup_ms.value',
                  v,
                ),
              ),
            ),
            SettingsRow(
              label: 'Reopen device on format change',
              sublabel:
                  'Full device reopen when format changes. Required by some DACs.',
              isStaged: state.isStaged(
                '$_fix.alsa_reopen_device_with_new_format.value',
              ),
              control: SettingsToggle(
                value:
                    state.getEffective(
                        '$_fix.alsa_reopen_device_with_new_format.value') ==
                    true,
                onChanged: (v) => notifier.stageChange(
                  '$_fix.alsa_reopen_device_with_new_format.value',
                  v,
                ),
              ),
            ),
          ],
        ),

        // ---- BUFFERS & DECODERS ----
        _sectionLabel('Buffers & decoders'),
        SettingsCard(
          children: [
            SettingsSection(
              title: 'Show buffer settings',
              showTopBorder: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SubSectionLabel(label: 'HTTP input'),
                  SettingsRow(
                    label: 'Buffer size',
                    sublabel: 'HTTP input buffer (bytes)',
                    isStaged: state.isStaged('$_inp.buffer_size.value'),
                    control: SettingsNumericInput(
                      value:
                          state.getEffective('$_inp.buffer_size.value') ??
                          384000,
                      onChanged: (v) =>
                          notifier.stageChange('$_inp.buffer_size.value', v),
                    ),
                  ),
                  SettingsRow(
                    label: 'Chunk size',
                    sublabel: 'HTTP input chunk (bytes)',
                    isStaged: state.isStaged('$_inp.chunk_size.value'),
                    control: SettingsNumericInput(
                      value:
                          state.getEffective('$_inp.chunk_size.value') ?? 768000,
                      onChanged: (v) =>
                          notifier.stageChange('$_inp.chunk_size.value', v),
                    ),
                  ),
                  const SubSectionLabel(label: 'Decoders'),
                  SettingsRow(
                    label: 'FLAC buffer',
                    sublabel: 'FLAC decoder buffer (bytes)',
                    isStaged: state.isStaged(
                      '$_dec.flac.fields.buffer_size.value',
                    ),
                    control: SettingsNumericInput(
                      value:
                          state.getEffective(
                              '$_dec.flac.fields.buffer_size.value') ??
                          1536000,
                      onChanged: (v) => notifier.stageChange(
                        '$_dec.flac.fields.buffer_size.value',
                        v,
                      ),
                    ),
                  ),
                  SettingsRow(
                    label: 'MPEG buffer',
                    sublabel: 'MPEG decoder buffer (bytes)',
                    isStaged: state.isStaged(
                      '$_dec.mpeg.fields.buffer_size.value',
                    ),
                    control: SettingsNumericInput(
                      value:
                          state.getEffective(
                              '$_dec.mpeg.fields.buffer_size.value') ??
                          176400,
                      onChanged: (v) => notifier.stageChange(
                        '$_dec.mpeg.fields.buffer_size.value',
                        v,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
}

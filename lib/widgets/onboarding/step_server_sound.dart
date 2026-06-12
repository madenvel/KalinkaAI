import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_theme.dart';
import '../kalinka_bottom_sheet.dart' show showKalinkaConfirmDialog;
import '../kalinka_button.dart';
import '../settings_controls/footer_note.dart';
import '../settings_controls/settings_card.dart';
import '../settings_controls/settings_row.dart';
import 'onboarding_fields.dart';
import 'onboarding_step_scaffold.dart';
import 'speaker_test_dialog.dart';

/// Wizard step: server name + ALSA output device + speaker test.
class OnboardingServerSoundStep extends ConsumerWidget {
  const OnboardingServerSoundStep({super.key});

  static const _devicePath = 'base_config.output.alsa.device';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              help: 'How this server shows up when devices on your '
                  'network look for it.',
            ),
          ],
        ),
        const OnboardingSectionLabel('Audio output'),
        SettingsCard(
          children: [
            const OnboardingFieldRow(
              path: _devicePath,
              label: 'Output device',
              help: 'Where the music comes out — your DAC, sound card '
                  'or HDMI output.',
            ),
            SettingsRow(
              label: 'Test output',
              sublabel: 'Plays a short tone on the left, then the right '
                  'channel.',
              control: KalinkaButton(
                label: 'Test',
                variant: KalinkaButtonVariant.neutral,
                size: KalinkaButtonSize.compact,
                onTap: () => showKalinkaConfirmDialog<void>(
                  context: context,
                  builder: (_) => const SpeakerTestDialog(),
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 20, top: 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: () =>
                  ref.read(settingsProvider.notifier).refreshEnumOptions(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.refresh_rounded,
                    size: 13,
                    color: KalinkaColors.accent,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Rescan devices',
                    style: KalinkaTextStyles.trayRowLabel.copyWith(
                      fontSize: KalinkaTypography.baseSize + 2,
                      color: KalinkaColors.accent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const FooterNote(
          text: 'Connect your DAC or audio interface first, then rescan if '
              'it isn’t listed.\n'
              'For bit-perfect playback choose the device itself, not an '
              'entry marked “auto-convert” — those resample the audio to '
              'fit the hardware.\n'
              'Not sure? “Auto-convert” is the safe choice: it plays '
              'anything, at the cost of format conversion.',
        ),
      ],
    );
  }
}

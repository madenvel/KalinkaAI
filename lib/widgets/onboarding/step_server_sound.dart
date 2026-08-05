import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/kalinka_player_api_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/haptics.dart';
import '../kalinka_dialog.dart' show showKalinkaDialog;
import '../settings_controls/settings_card.dart';
import 'onboarding_fields.dart';
import 'onboarding_step_scaffold.dart';
import 'speaker_test_dialog.dart';

/// Wizard step: server name + ALSA output device + speaker test.
class OnboardingServerSoundStep extends StatelessWidget {
  const OnboardingServerSoundStep({super.key});

  @override
  Widget build(BuildContext context) {
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
                  'How this server shows up when devices on your '
                  'network look for it.',
            ),
          ],
        ),
        const OnboardingSectionLabel('Audio output'),
        const OnboardingNote(
          'Connect your DAC or USB audio device first so it shows up in '
          'the list. For bit-perfect playback, pick a device that doesn’t '
          'do automatic conversion.',
        ),
        SettingsCard(
          children: [
            const OnboardingFieldRow(
              path: 'base_config.output.alsa.device',
              label: 'Output device',
              help:
                  'Where the music comes out — your DAC, sound card '
                  'or HDMI output.',
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Consumer(
                builder: (context, ref, _) => _TestOutputButton(
                  onTap: () => showKalinkaDialog<void>(
                    context: context,
                    builder: (_) => SpeakerTestDialog(
                      // Route through the user's (possibly still staged)
                      // device choice — the staged ALSA selection isn't
                      // applied until the final restart.
                      playTone: (channel) => ref
                          .read(kalinkaProxyProvider)
                          .testTone(
                            channel,
                            device: ref
                                .read(settingsProvider)
                                .getEffective('base_config.output.alsa.device')
                                ?.toString(),
                          ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Full-width speaker-test CTA. Brass-tinted — prominent without
/// competing with the step's berry-accented Continue button.
class _TestOutputButton extends StatelessWidget {
  final VoidCallback onTap;

  const _TestOutputButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: KalinkaColors.goldSubtle,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(13),
        side: BorderSide(color: KalinkaColors.gold.withValues(alpha: 0.35)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          KalinkaHaptics.lightImpact();
          onTap();
        },
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed) ||
              states.contains(WidgetState.hovered)) {
            return Colors.white.withValues(alpha: 0.06);
          }
          return null;
        }),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.volume_up_rounded,
                size: 16,
                color: KalinkaColors.gold,
              ),
              const SizedBox(width: 8),
              Text(
                'Test output',
                style: KalinkaTextStyles.trayRowLabel.copyWith(
                  fontSize: KalinkaTypography.baseSize + 3,
                  color: KalinkaColors.gold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

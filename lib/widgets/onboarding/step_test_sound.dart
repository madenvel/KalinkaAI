import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/kalinka_player_api_provider.dart';
import '../../providers/renderer_host_provider.dart'
    show rendererIdentityProvider;
import '../../providers/renderer_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_theme.dart';
import '../kalinka_dialog.dart' show showKalinkaDialog;
import '../renderer_switcher.dart' show rendererDisplayName;
import '../settings_controls/settings_card.dart';
import '../settings_controls/warning_note.dart';
import 'onboarding_step_scaffold.dart';
import 'sound_widgets.dart';
import 'speaker_test_dialog.dart';

/// Wizard step: hear the chosen output before committing to it.
///
/// Recommended, never required — the host offers "Skip for now" until a
/// test has run, and [onTested] tells it one did. The tone goes through
/// the selected renderer (or the staged ALSA device on an old server) and
/// the dialog offers the jump into the output's settings when nothing
/// comes out. Note the amplifier hand-over only happens after the final
/// restart, so with a device chosen the tone still rides the output's own
/// volume here.
class OnboardingTestSoundStep extends ConsumerWidget {
  /// Fired when the user starts a test, so the host can stop suggesting
  /// the step be skipped and the review can report it.
  final VoidCallback? onTested;

  /// Opens the tested output's own settings, hosted by the wizard.
  final OpenRendererSettings? onOpenSettings;

  const OnboardingTestSoundStep({
    super.key,
    this.onTested,
    this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final renderers = ref.watch(rendererListProvider);
    final ownId = ref.watch(rendererIdentityProvider).value?.rendererId;

    final active = renderers.active;
    final activeName = active == null
        ? null
        : rendererDisplayName(active, isSelf: active.rendererId == ownId);
    final canTest =
        !renderers.supported || (active != null && active.isConnected);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SettingsCard(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TestSoundButton(
                    enabled: canTest,
                    onTap: () {
                      onTested?.call();
                      showKalinkaDialog<void>(
                        context: context,
                        builder: (_) => SpeakerTestDialog(
                          targetName: activeName,
                          // Old servers read the staged ALSA device,
                          // renderer-era servers the renderer id — each
                          // ignores the parameter it doesn't know.
                          playTone: (channel) => ref
                              .read(kalinkaProxyProvider)
                              .testTone(
                                channel,
                                device: ref
                                    .read(settingsProvider)
                                    .getEffective(
                                      'base_config.output.alsa.device',
                                    )
                                    ?.toString(),
                                rendererId: active?.rendererId,
                              ),
                          onOpenSettings:
                              active == null || onOpenSettings == null
                              ? null
                              : () => onOpenSettings!(
                                  active.rendererId,
                                  activeName ?? 'Output',
                                ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Plays a short tone down each channel'
                    '${activeName == null ? '' : ' through “$activeName”'}. '
                    'New outputs start at a safe volume.',
                    style: KalinkaTextStyles.trayRowSublabel,
                  ),
                ],
              ),
            ),
          ],
        ),
        if (!canTest)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: WarningNote(
              severity: WarningNoteSeverity.warning,
              message:
                  'No output is connected, so there is nothing to test — '
                  'continue and test from the output’s settings once one '
                  'joins.',
            ),
          )
        else
          const OnboardingNote(
            'If the tone comes out wrong, the test offers this output’s '
            'settings — device, format, volume mode — applied and '
            're-testable on the spot.',
          ),
      ],
    );
  }
}

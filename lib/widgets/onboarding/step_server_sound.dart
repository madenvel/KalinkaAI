import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data_model/data_model.dart' show RendererInfo;
import '../../providers/kalinka_player_api_provider.dart';
import '../../providers/renderer_host_provider.dart'
    show rendererIdentityProvider;
import '../../providers/renderer_provider.dart';
import '../../providers/settings_provider.dart';
import '../../screens/renderer_settings_screen.dart';
import '../../theme/app_theme.dart';
import '../../utils/haptics.dart';
import '../kalinka_button.dart';
import '../kalinka_dialog.dart' show showKalinkaDialog;
import '../renderer_switcher.dart' show rendererDisplayName, rendererDetail;
import '../settings_controls/settings_card.dart';
import '../settings_controls/warning_note.dart';
import 'onboarding_fields.dart';
import 'onboarding_step_scaffold.dart';
import 'speaker_test_dialog.dart';

/// Wizard step: server name + where the music comes out.
///
/// On a renderer-era server the output is an output of a *renderer* — a
/// device that connected to the server — so this lists the outputs the
/// server knows, lets the user pick the one playback should use (applied
/// live, like the app's output picker), test it by ear, and open its own
/// settings behind the gear when the tone comes out wrong. On an older
/// server the schema still carries the ALSA device field, which renders in
/// the section's place, and the tone routes through the staged device.
class OnboardingServerSoundStep extends ConsumerStatefulWidget {
  const OnboardingServerSoundStep({super.key});

  @override
  ConsumerState<OnboardingServerSoundStep> createState() =>
      _OnboardingServerSoundStepState();
}

class _OnboardingServerSoundStepState
    extends ConsumerState<OnboardingServerSoundStep> {
  @override
  void initState() {
    super.initState();
    // Renderers announce themselves to the server, not to the app — re-read
    // on entry so one that connected since the wizard started shows up.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(rendererListProvider.notifier).refresh();
    });
  }

  void _openOutputSettings(RendererInfo renderer, String name) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RendererSettingsScreen(
          rendererId: renderer.rendererId,
          rendererName: name,
        ),
      ),
    );
  }

  void _testOutput({RendererInfo? renderer, String? name}) {
    showKalinkaDialog<void>(
      context: context,
      builder: (_) => SpeakerTestDialog(
        targetName: name,
        // Old servers read the staged ALSA device, renderer-era servers the
        // renderer id — each ignores the parameter it doesn't know.
        playTone: (channel) => ref
            .read(kalinkaProxyProvider)
            .testTone(
              channel,
              device: ref
                  .read(settingsProvider)
                  .getEffective('base_config.output.alsa.device')
                  ?.toString(),
              rendererId: renderer?.rendererId,
            ),
        onOpenSettings: renderer == null
            ? null
            : () => _openOutputSettings(renderer, name ?? 'Output'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final renderers = ref.watch(rendererListProvider);
    final ownId = ref.watch(rendererIdentityProvider).value?.rendererId;

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
        if (renderers.supported)
          ..._buildOutputs(renderers, ownId)
        else
          ..._buildLegacyOutput(),
      ],
    );
  }

  /// Renderer-era server: the connected outputs, selection, test and gear.
  List<Widget> _buildOutputs(RendererListState state, String? ownId) {
    if (state.renderers.isEmpty) {
      return [
        const OnboardingNote(
          'Music plays through an output — a device running the Kalinka '
          'renderer, or a browser with the web player open.',
        ),
        WarningNote(
          severity: WarningNoteSeverity.warning,
          message: state.loading
              ? 'Looking for outputs…'
              : 'No outputs connected — nothing can play yet. Install the '
                    'Kalinka renderer on the machine wired to your speakers '
                    'or DAC, or open the web player in a browser.',
        ),
        const SizedBox(height: 12),
        KalinkaButton(
          label: 'Check again',
          variant: KalinkaButtonVariant.neutral,
          size: KalinkaButtonSize.compact,
          enabled: !state.loading,
          onTap: ref.read(rendererListProvider.notifier).refresh,
        ),
      ];
    }

    final active = state.active;
    final activeName = active == null
        ? null
        : rendererDisplayName(active, isSelf: active.rendererId == ownId);

    return [
      const OnboardingNote(
        'Pick where the music comes out. The gear holds that output’s own '
        'settings — its playback device, volume behaviour — applied '
        'straight away, no restart. More outputs can join any time.',
      ),
      SettingsCard(
        children: [
          for (final r in state.renderers)
            _OutputRow(
              name: rendererDisplayName(r, isSelf: r.rendererId == ownId),
              detail: rendererDetail(r, isSelf: r.rendererId == ownId),
              selected: r.active,
              connected: r.isConnected,
              onTap: () {
                KalinkaHaptics.lightImpact();
                ref.read(rendererListProvider.notifier).select(r.rendererId);
              },
              onSettings: () => _openOutputSettings(
                r,
                rendererDisplayName(r, isSelf: r.rendererId == ownId),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: _TestOutputButton(
              enabled: active != null && active.isConnected,
              onTap: () => _testOutput(renderer: active, name: activeName),
            ),
          ),
        ],
      ),
    ];
  }

  /// Pre-renderer server: the ALSA device field straight off the schema.
  List<Widget> _buildLegacyOutput() {
    return [
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
            child: _TestOutputButton(onTap: _testOutput),
          ),
        ],
      ),
    ];
  }
}

/// One output: radio mark, name and detail, gear into its own settings.
/// Offline rows stay visible for context but can't be chosen — same rule as
/// the app's output picker.
class _OutputRow extends StatelessWidget {
  final String name;
  final String detail;
  final bool selected;
  final bool connected;
  final VoidCallback onTap;
  final VoidCallback onSettings;

  const _OutputRow({
    required this.name,
    required this.detail,
    required this.selected,
    required this.connected,
    required this.onTap,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: connected && !selected ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        color: selected ? KalinkaColors.surfaceElevated : Colors.transparent,
        padding: const EdgeInsets.fromLTRB(16, 7, 6, 7),
        child: Opacity(
          opacity: connected ? 1.0 : 0.45,
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
                    Text(
                      name,
                      style: KalinkaTextStyles.trayRowLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (detail.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        detail,
                        style: KalinkaTextStyles.trayRowSublabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              // Settings live on the renderer, so an offline one has nothing
              // to serve — the gear follows the row's enablement.
              Semantics(
                label: 'Output settings',
                button: true,
                child: GestureDetector(
                  onTap: connected ? onSettings : null,
                  behavior: HitTestBehavior.opaque,
                  child: const SizedBox(
                    width: 42,
                    height: 42,
                    child: Icon(
                      Icons.settings_outlined,
                      size: 18,
                      color: KalinkaColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-width speaker-test CTA. Brass-tinted — prominent without
/// competing with the step's berry-accented Continue button.
class _TestOutputButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool enabled;

  const _TestOutputButton({required this.onTap, this.enabled = true});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: Material(
        color: KalinkaColors.goldSubtle,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(13),
          side: BorderSide(color: KalinkaColors.gold.withValues(alpha: 0.35)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled
              ? () {
                  KalinkaHaptics.lightImpact();
                  onTap();
                }
              : null,
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
      ),
    );
  }
}

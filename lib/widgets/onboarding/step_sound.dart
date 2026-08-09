import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data_model/data_model.dart' show RendererInfo;
import '../../data_model/presentation_schema.dart';
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

/// Wizard step: where the music plays, what controls it, and the ear check.
///
/// Three parts on one screen so cause and effect stay together:
///
/// * **Audio output** — the connected renderers; tapping one moves playback
///   there (live, like the app's output picker) and the gear opens that
///   output's own settings. On a pre-renderer server the schema's ALSA
///   device field renders here instead.
/// * **Amplifier or receiver control** — per selected output: the default
///   leaves volume with the output itself (and shows the built-in module's
///   options); choosing a device plugin stages its enabled flag, and the
///   output is handed to it right after the final restart (see the attach
///   task in `onboarding_screen.dart`). The built-in module's enabled flag
///   is never written — disabling it would drop volume control everywhere.
/// * **Speaker test** — a tone through the selected output, with a jump
///   into its settings when nothing comes out. Sound isn't gated: an
///   install whose output isn't wired up yet can still finish setup.
class OnboardingSoundStep extends ConsumerStatefulWidget {
  const OnboardingSoundStep({super.key});

  @override
  ConsumerState<OnboardingSoundStep> createState() =>
      _OnboardingSoundStepState();
}

class _OnboardingSoundStepState extends ConsumerState<OnboardingSoundStep> {
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
    final settings = ref.watch(settingsProvider);
    final renderers = ref.watch(rendererListProvider);
    final ownId = ref.watch(rendererIdentityProvider).value?.rendererId;

    final active = renderers.active;
    final activeName = active == null
        ? null
        : rendererDisplayName(active, isSelf: active.rendererId == ownId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const OnboardingSectionLabel('Audio output'),
        if (renderers.supported)
          ..._buildOutputs(renderers, ownId)
        else
          ..._buildLegacyOutput(),
        ..._buildAmpControl(settings, activeName),
        const OnboardingSectionLabel('Speaker test'),
        SettingsCard(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TestOutputButton(
                    enabled:
                        !renderers.supported ||
                        (active != null && active.isConnected),
                    onTap: () =>
                        _testOutput(renderer: active, name: activeName),
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
      ],
    );
  }

  /// Renderer-era server: the connected outputs, selection and gear.
  List<Widget> _buildOutputs(RendererListState state, String? ownId) {
    if (state.renderers.isEmpty) {
      return [
        WarningNote(
          severity: WarningNoteSeverity.warning,
          message: state.loading
              ? 'Looking for outputs…'
              : 'No outputs connected — nothing can play yet. Install the '
                    'Kalinka renderer on the machine wired to your speakers '
                    'or DAC, or open the web player in a browser. Setup can '
                    'still finish without one.',
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
      const SettingsCard(
        children: [
          OnboardingFieldRow(
            path: 'base_config.output.alsa.device',
            label: 'Output device',
            help:
                'Where the music comes out — your DAC, sound card '
                'or HDMI output.',
          ),
        ],
      ),
    ];
  }

  /// Amplifier/receiver control for the selected output, plus the effective
  /// setup those choices add up to.
  List<Widget> _buildAmpControl(SettingsState state, String? outputName) {
    final notifier = ref.read(settingsProvider.notifier);
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

    return [
      const OnboardingSectionLabel('Amplifier or receiver control'),
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
            for (final f in setupModuleFields(rendererModule))
              OnboardingFieldRow(path: f.path),
          ],
        ),
      ],
      if (selected != null) ...[
        OnboardingSectionLabel('${selected.title} options'),
        SettingsCard(
          children: [
            for (final f in setupModuleFields(selected))
              OnboardingFieldRow(path: f.path),
          ],
        ),
        OnboardingNote(
          'Kalinka finds compatible devices on your network by itself — '
          'set an address only if yours isn’t found. '
          '${outputName != null ? '“$outputName” hands' : 'The output playing now hands'} '
          'volume and power to ${selected.title} when setup finishes.',
        ),
      ],
      const OnboardingSectionLabel('Your sound setup'),
      SettingsCard(
        children: [
          _EffectiveRow(
            label: 'Audio output',
            value: outputName ?? 'None connected yet',
          ),
          _EffectiveRow(
            label: 'Volume & power',
            value: selected?.title ?? 'The output itself',
          ),
          _EffectiveRow(
            label: 'Output volume',
            value: selected == null
                ? 'Its own control'
                : 'Fixed at full — ${selected.title} sets the level',
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
              _RadioMark(selected: selected),
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
              _RadioMark(selected: selected),
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

class _RadioMark extends StatelessWidget {
  final bool selected;

  const _RadioMark({required this.selected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? KalinkaColors.accent : KalinkaColors.borderDefault,
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
    );
  }
}

/// One line of the effective sound setup — label and outcome, no control.
class _EffectiveRow extends StatelessWidget {
  final String label;
  final String value;

  const _EffectiveRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: KalinkaTextStyles.trayRowSublabel),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(value, style: KalinkaTextStyles.trayRowLabel)),
        ],
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
                  'Play test sound',
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

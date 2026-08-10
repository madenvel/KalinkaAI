import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/renderer_host_provider.dart'
    show rendererIdentityProvider;
import '../../providers/renderer_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/haptics.dart';
import '../kalinka_button.dart';
import '../renderer_switcher.dart' show rendererDisplayName, rendererDetail;
import '../settings_controls/settings_card.dart';
import '../settings_controls/warning_note.dart';
import 'onboarding_fields.dart';
import 'onboarding_step_scaffold.dart';
import 'sound_widgets.dart';

/// Wizard step: choose the output renderer the music plays on.
///
/// Lists the renderers connected to the server; tapping a row moves
/// playback there (live, like the app's output picker) and the gear opens
/// that output's own settings — playback device, volume behaviour — applied
/// without any restart. Offline rows stay visible for context but can't be
/// chosen. On a pre-renderer server the schema's ALSA device field renders
/// here instead. A missing output warns rather than traps: setup can
/// finish and the output can join later.
class OnboardingOutputStep extends ConsumerStatefulWidget {
  /// Opens one output's own settings, hosted by the wizard.
  final OpenRendererSettings? onOpenSettings;

  const OnboardingOutputStep({super.key, this.onOpenSettings});

  @override
  ConsumerState<OnboardingOutputStep> createState() =>
      _OnboardingOutputStepState();
}

class _OnboardingOutputStepState extends ConsumerState<OnboardingOutputStep> {
  @override
  void initState() {
    super.initState();
    // Renderers announce themselves to the server, not to the app — re-read
    // on entry so one that connected since the wizard started shows up.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(rendererListProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final renderers = ref.watch(rendererListProvider);
    final ownId = ref.watch(rendererIdentityProvider).value?.rendererId;

    if (!renderers.supported) {
      // Pre-renderer server: the ALSA device field straight off the schema.
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          OnboardingNote(
            'Connect your DAC or USB audio device first so it shows up in '
            'the list. For bit-perfect playback, pick a device that doesn’t '
            'do automatic conversion.',
          ),
          SettingsCard(
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
        ],
      );
    }

    if (renderers.renderers.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          WarningNote(
            severity: WarningNoteSeverity.warning,
            message: renderers.loading
                ? 'Looking for outputs…'
                : 'No outputs connected — nothing can play yet. Install '
                      'the Kalinka renderer on the machine wired to your '
                      'speakers or DAC, or open the web player in a '
                      'browser. Setup can still finish without one.',
          ),
          const SizedBox(height: 12),
          KalinkaButton(
            label: 'Check again',
            variant: KalinkaButtonVariant.neutral,
            size: KalinkaButtonSize.compact,
            enabled: !renderers.loading,
            onTap: ref.read(rendererListProvider.notifier).refresh,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const OnboardingNote(
          'Pick where the music comes out. The gear holds that output’s '
          'own settings — its playback device, volume behaviour — applied '
          'straight away, no restart. More outputs can join any time.',
        ),
        SettingsCard(
          children: [
            for (final r in renderers.renderers)
              _OutputRow(
                name: rendererDisplayName(r, isSelf: r.rendererId == ownId),
                detail: rendererDetail(r, isSelf: r.rendererId == ownId),
                selected: r.active,
                connected: r.isConnected,
                onTap: () {
                  KalinkaHaptics.lightImpact();
                  ref.read(rendererListProvider.notifier).select(r.rendererId);
                },
                onSettings: widget.onOpenSettings == null
                    ? null
                    : () => widget.onOpenSettings!(
                        r.rendererId,
                        rendererDisplayName(r, isSelf: r.rendererId == ownId),
                      ),
              ),
          ],
        ),
      ],
    );
  }
}

/// One output: radio mark, name and detail, gear into its own settings.
class _OutputRow extends StatelessWidget {
  final String name;
  final String detail;
  final bool selected;
  final bool connected;
  final VoidCallback onTap;

  /// Null when the host offers no settings panel — the gear is then hidden
  /// rather than dead.
  final VoidCallback? onSettings;

  const _OutputRow({
    required this.name,
    required this.detail,
    required this.selected,
    required this.connected,
    required this.onTap,
    this.onSettings,
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
              RadioMark(selected: selected),
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
              if (onSettings != null)
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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data_model/presentation_schema.dart' show ModuleSpec;
import '../providers/connection_settings_provider.dart';
import '../providers/kalinka_player_api_provider.dart';
import '../providers/onboarding_provider.dart';
import '../providers/renderer_provider.dart';
import '../providers/restart_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/toast_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/discovery_screen.dart';
import '../widgets/kalinka_button.dart';
import '../widgets/onboarding/onboarding_fields.dart';
import '../widgets/onboarding/onboarding_step_scaffold.dart';
import '../widgets/onboarding/step_features.dart';
import '../widgets/onboarding/step_music_sources.dart';
import '../widgets/onboarding/step_review.dart';
import '../widgets/onboarding/step_server_sound.dart';
import '../widgets/onboarding/step_volume_power.dart';
import '../widgets/restart_overlay.dart';

/// First-run setup wizard (OOBE).
///
/// Six steps: discover & connect → server & sound → music sources →
/// device control → features → review & restart. The connection is held
/// in memory only and config changes are merely staged until the final
/// step, so killing the app mid-setup restarts the wizard from the
/// beginning; backgrounding keeps the current step (widget state stays
/// alive). On success the server connection is persisted, the
/// `oobeComplete` flag is set, and the wizard pops back to the play queue.
///
/// Whether the *server* is set up is its own config flag
/// (`base_config.server.oobe_complete`): the wizard reads it after
/// connecting and skips straight to the app when another client already
/// completed setup. With [startAtSetup] the discovery step is skipped
/// instead — for an already-connected (stored) server that reports the
/// flag false, e.g. an existing install pointing at a fresh server.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key, this.startAtSetup = false});

  final bool startAtSetup;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _stepCount = 6;

  late int _step = widget.startAtSetup ? 1 : 0;

  /// The lowest step the user can walk back to: discovery is not part of
  /// the flow when the connection came from outside the wizard.
  late final int _firstStep = widget.startAtSetup ? 1 : 0;
  bool _restartOverlayOpen = false;
  // Set when the restart succeeded and persistence was kicked off;
  // completes once the connection and the first-run flag are written.
  Future<void>? _commitFuture;

  // Captured at finish from the Volume & power step, applied after the
  // restart: the device module the wizard's output is handed to (null =
  // the renderer keeps control), and which output that is.
  bool _attachPrepared = false;
  String? _attachModuleId;
  String _attachModuleTitle = '';
  String? _attachRendererId;

  Future<void> _onConnected() async {
    // The discovery step keeps its "connecting" state up while this runs.
    await ref.read(settingsProvider.notifier).loadConfig();
    if (!mounted) return;
    // Another client already set up the server: just persist the
    // connection. The coach-mark tour still runs once per install.
    final values = ref.read(settingsProvider).values;
    if (!OnboardingStatusNotifier.forceOobe &&
        values[OnboardingStatusNotifier.serverOobeFlagPath] == true) {
      await _commitSetup();
      if (mounted) Navigator.of(context).pop();
      return;
    }
    setState(() => _step = 1);
  }

  void _finish() {
    // Mark the server set up; rides along with the staged config.
    ref
        .read(settingsProvider.notifier)
        .stageChange(OnboardingStatusNotifier.serverOobeFlagPath, true);

    // The Volume & power choice can't be applied yet — a freshly enabled
    // module only loads with the restart — so capture it here and hand the
    // output over once the server is back.
    final settings = ref.read(settingsProvider);
    ModuleSpec? chosen;
    for (final m in setupDeviceModules(settings.schema)) {
      if (settings.getEffective('devices.${m.id}.enabled') == true) {
        chosen = m;
        break;
      }
    }
    final renderers = ref.read(rendererListProvider);
    _attachPrepared = renderers.supported;
    _attachModuleId = chosen?.id;
    _attachModuleTitle = chosen?.title ?? '';
    _attachRendererId = renderers.active?.rendererId;

    setState(() => _restartOverlayOpen = true);
    ref.read(restartProvider.notifier).executeRestart();
  }

  /// Persist the connection and flip the first-run flag — only once the
  /// restart sequence has fully succeeded. If the app dies mid-restart the
  /// wizard simply runs again on next launch.
  Future<void> _commitSetup() async {
    final connection = ref.read(connectionSettingsProvider);
    final stagedName = ref
        .read(settingsProvider)
        .getEffective('base_config.server.service_name');
    final name = (stagedName is String && stagedName.trim().isNotEmpty)
        ? stagedName.trim()
        : connection.name;
    await ref
        .read(connectionSettingsProvider.notifier)
        .setDevice(name, connection.host, connection.port);
    await ref.read(onboardingStatusProvider.notifier).markOobeComplete();

    // Detached on purpose: the wizard pops right after this commit, and the
    // attach outlives it (the module loads and the renderer redials on its
    // own schedule). Everything it needs is captured up front.
    if (_attachPrepared) {
      _attachPrepared = false;
      unawaited(
        _attachVolumeControl(
          api: ref.read(kalinkaProxyProvider),
          toasts: ref.read(toastProvider.notifier),
          moduleId: _attachModuleId,
          moduleTitle: _attachModuleTitle,
          rendererId: _attachRendererId,
        ),
      );
    }
  }

  Future<void> _onRestartDismissed() async {
    setState(() => _restartOverlayOpen = false);
    final commit = _commitFuture;
    if (commit == null) return; // Restart failed — stay in the wizard.
    // The overlay's auto-dismiss can fire while the prefs writes are still
    // in flight; don't leave the wizard until they've finished.
    await commit;
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(restartProvider, (prev, next) {
      if (next.isDone && prev?.isDone != true && _commitFuture == null) {
        // A failed write is benign — the wizard would simply run again on
        // the next launch — so log and still let the user into the app.
        _commitFuture = _commitSetup().catchError((Object e) {
          debugPrint('Onboarding: failed to persist setup: $e');
        });
      }
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // System back walks one step backwards; never leaves the wizard.
        if (_step > _firstStep && !_restartOverlayOpen) {
          setState(() => _step--);
        }
      },
      child: Scaffold(
        backgroundColor: KalinkaColors.background,
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              child: KeyedSubtree(
                key: ValueKey('oobe_step_$_step'),
                child: _buildStep(),
              ),
            ),
            if (_restartOverlayOpen)
              Positioned.fill(
                child: RestartOverlay(onDismiss: _onRestartDismissed),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep() {
    if (_step == 0) {
      final connection = ref.read(connectionSettingsProvider);
      return DiscoveryScreen(
        allowCancel: false,
        persistConnection: false,
        currentServerHost: null,
        onConnected: _onConnected,
        isTablet: MediaQuery.of(context).size.width >= kKalinkaTabletBreakpoint,
        // Re-entering after "Back": preselect nothing, fresh scan.
        key: ValueKey('oobe_discovery_${connection.host}'),
      );
    }

    final (title, subtitle, body, nextLabel) = switch (_step) {
      1 => (
        'Server & output',
        'Name your server and pick where the music comes out.',
        const OnboardingServerSoundStep() as Widget,
        'Continue',
      ),
      2 => (
        'Music sources',
        'Choose what feeds your library.',
        const OnboardingMusicSourcesStep() as Widget,
        'Continue',
      ),
      3 => (
        'Volume & power',
        'Choose what sets the volume where the music plays — the output '
            'itself, or an amplifier it feeds.',
        const OnboardingVolumePowerStep() as Widget,
        'Continue',
      ),
      4 => (
        'Smart features',
        'Optional extras — everything can be changed later in Settings.',
        const OnboardingFeaturesStep() as Widget,
        'Continue',
      ),
      _ => (
        'Almost there',
        'Check your choices, then restart the server to apply them.',
        const OnboardingReviewStep() as Widget,
        'Finish setup & restart',
      ),
    };

    return OnboardingStepScaffold(
      stepNumber: _step + 1,
      stepCount: _stepCount,
      title: title,
      subtitle: subtitle,
      onBack: _step > _firstStep ? () => setState(() => _step--) : null,
      onNext: _step == _stepCount - 1 ? _finish : () => setState(() => _step++),
      nextLabel: nextLabel,
      children: [_wrapSettingsState(body)],
    );
  }

  /// Steps after connect need the server config; gate on its load state.
  Widget _wrapSettingsState(Widget child) {
    final settings = ref.watch(settingsProvider);
    if (settings.isLoading) {
      return const Padding(
        padding: EdgeInsets.only(top: 80),
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(KalinkaColors.accent),
          ),
        ),
      );
    }
    if (settings.schema == null) {
      return Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: KalinkaColors.statusOffline,
                size: 32,
              ),
              const SizedBox(height: 12),
              Text(
                'Could not load server settings',
                style: KalinkaTextStyles.cardTitle,
              ),
              if (settings.error != null) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    settings.error!,
                    textAlign: TextAlign.center,
                    style: KalinkaTextStyles.trayRowSublabel,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              KalinkaButton(
                label: 'Retry',
                variant: KalinkaButtonVariant.accent,
                size: KalinkaButtonSize.compact,
                onTap: () => ref.read(settingsProvider.notifier).loadConfig(),
              ),
            ],
          ),
        ),
      );
    }
    return child;
  }
}

/// Hands the wizard's output to the chosen device module — or back to the
/// renderer itself — once the restarted server is up.
///
/// The mapping is per renderer and the server refuses it until the module is
/// loaded, which only happens with the restart; the renderer also has to
/// redial the restarted server. So this retries for a while and reports a
/// failed hand-over as a toast — the mapping can always be set later from
/// the output's settings. Clearing (null [moduleId]) fails silently: it only
/// matters on a wizard re-run, and the default is what it resets to.
Future<void> _attachVolumeControl({
  required KalinkaPlayerProxy api,
  required ToastNotifier toasts,
  required String? moduleId,
  required String moduleTitle,
  required String? rendererId,
}) async {
  const attempts = 10;
  for (var i = 0; i < attempts; i++) {
    if (i > 0) await Future<void>.delayed(const Duration(seconds: 3));
    try {
      var target = rendererId;
      if (target == null) {
        // No output was connected while the wizard ran — take the one
        // playback would use now.
        for (final r in await api.listRenderers()) {
          if (r.active) {
            target = r.rendererId;
            break;
          }
        }
        if (target == null) continue;
      }
      await api.setRendererVolumeControl(target, moduleId);
      return;
    } on RenderersUnsupportedException {
      return; // Older server — nothing to attach.
    } catch (_) {
      // Server still coming back or renderer not redialled yet — try again.
    }
  }
  if (moduleId != null) {
    toasts.show(
      'Couldn’t hand volume control to $moduleTitle — set it in the '
      'output’s settings.',
      isError: true,
    );
  }
}

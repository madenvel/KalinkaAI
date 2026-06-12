import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/connection_settings_provider.dart';
import '../providers/onboarding_provider.dart';
import '../providers/restart_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/discovery_screen.dart';
import '../widgets/kalinka_button.dart';
import '../widgets/onboarding/onboarding_step_scaffold.dart';
import '../widgets/onboarding/step_device_control.dart';
import '../widgets/onboarding/step_features.dart';
import '../widgets/onboarding/step_music_sources.dart';
import '../widgets/onboarding/step_review.dart';
import '../widgets/onboarding/step_server_sound.dart';
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
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _stepCount = 6;

  int _step = 0;
  bool _restartOverlayOpen = false;
  bool _committed = false;

  void _onConnected() {
    ref.read(settingsProvider.notifier).loadConfig();
    setState(() => _step = 1);
  }

  void _finish() {
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
  }

  void _onRestartDismissed() {
    setState(() => _restartOverlayOpen = false);
    if (_committed && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(restartProvider, (prev, next) {
      if (next.isDone && prev?.isDone != true && !_committed) {
        _committed = true;
        _commitSetup();
      }
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // System back walks one step backwards; never leaves the wizard.
        if (_step > 0 && !_restartOverlayOpen) {
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
        isTablet: MediaQuery.of(context).size.width >= 900,
        // Re-entering after "Back": preselect nothing, fresh scan.
        key: ValueKey('oobe_discovery_${connection.host}'),
      );
    }

    final (title, subtitle, body, nextLabel) = switch (_step) {
      1 => (
        'Server & sound',
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
        'Amplifier control',
        'Let Kalinka switch your amplifier or receiver on and off with '
            'the music.',
        const OnboardingDeviceControlStep() as Widget,
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
      onBack: () => setState(() => _step--),
      onNext: _step == _stepCount - 1
          ? _finish
          : () => setState(() => _step++),
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
                onTap: () =>
                    ref.read(settingsProvider.notifier).loadConfig(),
              ),
            ],
          ),
        ),
      );
    }
    return child;
  }
}

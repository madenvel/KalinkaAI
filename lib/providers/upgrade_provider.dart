import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart' show Logger;

import 'kalinka_player_api_provider.dart';
import 'server_update_provider.dart';

final _logger = Logger();

enum UpgradeStep { installing, reconnecting }

class UpgradeState {
  final bool isUpgrading;
  final UpgradeStep? currentStep;
  final Set<UpgradeStep> completedSteps;
  final String? error;
  final bool isDone;
  final String? targetVersion;

  const UpgradeState({
    this.isUpgrading = false,
    this.currentStep,
    this.completedSteps = const {},
    this.error,
    this.isDone = false,
    this.targetVersion,
  });

  UpgradeState copyWith({
    bool? isUpgrading,
    UpgradeStep? currentStep,
    Set<UpgradeStep>? completedSteps,
    String? error,
    bool? isDone,
  }) {
    return UpgradeState(
      isUpgrading: isUpgrading ?? this.isUpgrading,
      currentStep: currentStep ?? this.currentStep,
      completedSteps: completedSteps ?? this.completedSteps,
      error: error,
      isDone: isDone ?? this.isDone,
      targetVersion: targetVersion,
    );
  }
}

final upgradeProvider = NotifierProvider<UpgradeNotifier, UpgradeState>(
  UpgradeNotifier.new,
);

class UpgradeNotifier extends Notifier<UpgradeState> {
  @override
  UpgradeState build() => const UpgradeState();

  /// Execute the upgrade sequence:
  /// 1. Request the upgrade (server validates the version)
  /// 2. "Installing" — wait for the server to go down and come back
  ///    (download + apt can take minutes; the server keeps answering
  ///    until the new package restarts it)
  /// 3. "Reconnecting" lights up once the server answers again; verify
  ///    it actually runs the new version
  Future<void> executeUpgrade(String version) async {
    final api = ref.read(kalinkaProxyProvider);
    final completed = <UpgradeStep>{};
    state = UpgradeState(
      isUpgrading: true,
      currentStep: UpgradeStep.installing,
      targetVersion: version,
    );

    try {
      await api.upgradeServer(version);
    } on ServerUpgradeException catch (e) {
      _logger.e('Upgrade request rejected', error: e);
      state = state.copyWith(error: e.message);
      return;
    } catch (e) {
      _logger.e('Upgrade request rejected', error: e);
      state = state.copyWith(error: 'The server rejected the upgrade request.');
      return;
    }

    // Poll until the server answers with the target version. The old
    // version answering just means apt hasn't restarted it yet, so it is
    // never treated as failure before the deadline — only the deadline
    // decides that (a connection blip mid-install must not be misread as
    // "came back on the old version"). One generous deadline covers the
    // whole install: download + apt time dominates and varies wildly
    // between a Pi and a PC.
    final deadline = DateTime.now().add(const Duration(minutes: 15));
    var wentDown = false;
    var success = false;
    String? lastSeen;
    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(seconds: 3));
      try {
        final v = await api.getServerVersion();
        lastSeen = v['server_version'] as String?;
        if (lastSeen == version) {
          success = true;
          break;
        }
      } catch (_) {
        if (!wentDown) {
          wentDown = true;
          completed.add(UpgradeStep.installing);
          state = state.copyWith(
            currentStep: UpgradeStep.reconnecting,
            completedSteps: Set.from(completed),
          );
        }
      }
    }

    if (!success) {
      state = state.copyWith(
        completedSteps: Set.from(completed),
        error: wentDown
            ? 'Server did not come back on the new version — '
                  'check it manually.'
            : 'Server is still on version ${lastSeen ?? 'unknown'} — '
                  'the upgrade did not start.',
      );
      return;
    }

    completed.add(UpgradeStep.reconnecting);
    state = UpgradeState(
      isUpgrading: true,
      isDone: true,
      completedSteps: Set.from(completed),
      targetVersion: version,
    );
    // The new server re-checks for updates itself; refetch so the banner
    // disappears instead of advertising the version we just installed.
    ref.invalidate(serverUpdateProvider);
  }

  void dismiss() {
    state = const UpgradeState();
  }
}

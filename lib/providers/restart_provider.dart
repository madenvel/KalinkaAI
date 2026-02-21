import 'dart:async' show Timer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart' show Logger;
import 'kalinka_player_api_provider.dart';
import 'settings_provider.dart';

final _logger = Logger();

enum RestartStep { saving, stopping, starting, reconnecting }

class RestartState {
  final bool isRestarting;
  final RestartStep? currentStep;
  final Set<RestartStep> completedSteps;
  final String? error;
  final bool isDone;

  const RestartState({
    this.isRestarting = false,
    this.currentStep,
    this.completedSteps = const {},
    this.error,
    this.isDone = false,
  });

  RestartState copyWith({
    bool? isRestarting,
    RestartStep? currentStep,
    Set<RestartStep>? completedSteps,
    String? error,
    bool? isDone,
  }) {
    return RestartState(
      isRestarting: isRestarting ?? this.isRestarting,
      currentStep: currentStep ?? this.currentStep,
      completedSteps: completedSteps ?? this.completedSteps,
      error: error,
      isDone: isDone ?? this.isDone,
    );
  }
}

final restartProvider = NotifierProvider<RestartNotifier, RestartState>(
  RestartNotifier.new,
);

class RestartNotifier extends Notifier<RestartState> {
  @override
  RestartState build() {
    return const RestartState();
  }

  /// Execute the full restart sequence:
  /// 1. Save config
  /// 2. Trigger restart
  /// 3. Wait for server to go down
  /// 4. Poll until server comes back
  Future<void> executeRestart() async {
    final completed = <RestartStep>{};

    try {
      // Step 1: Save config
      state = RestartState(
        isRestarting: true,
        currentStep: RestartStep.saving,
        completedSteps: Set.from(completed),
      );

      await ref.read(settingsProvider.notifier).applyChanges();
      completed.add(RestartStep.saving);

      // Step 2: Trigger restart
      state = state.copyWith(
        currentStep: RestartStep.stopping,
        completedSteps: Set.from(completed),
      );

      final api = ref.read(kalinkaProxyProvider);
      try {
        await api.restartServer();
      } catch (_) {
        // Server may close the connection during restart — that's expected
      }
      completed.add(RestartStep.stopping);

      // Step 3: Wait for server to go down
      state = state.copyWith(
        currentStep: RestartStep.starting,
        completedSteps: Set.from(completed),
      );
      await Future.delayed(const Duration(seconds: 2));
      completed.add(RestartStep.starting);

      // Step 4: Poll health check until server comes back
      state = state.copyWith(
        currentStep: RestartStep.reconnecting,
        completedSteps: Set.from(completed),
      );

      bool connected = false;
      for (int attempt = 0; attempt < 20; attempt++) {
        await Future.delayed(const Duration(seconds: 2));
        try {
          await ref.read(kalinkaProxyProvider).listModules();
          connected = true;
          break;
        } catch (_) {
          _logger.d('Restart reconnect attempt ${attempt + 1}/20');
        }
      }

      completed.add(RestartStep.reconnecting);

      if (!connected) {
        state = state.copyWith(
          completedSteps: Set.from(completed),
          error: 'Server did not come back after restart.',
        );
        return;
      }

      // All done
      state = RestartState(
        isRestarting: true,
        isDone: true,
        completedSteps: Set.from(completed),
        currentStep: null,
      );

      // Auto-dismiss after 2.2 seconds
      Timer(const Duration(milliseconds: 2200), () {
        state = const RestartState();
      });
    } catch (e) {
      _logger.e('Restart failed', error: e);
      state = state.copyWith(
        error: e.toString(),
        completedSteps: Set.from(completed),
      );
    }
  }

  void dismiss() {
    state = const RestartState();
  }
}

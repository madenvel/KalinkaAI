import 'dart:async' show Timer;

import 'package:dio/dio.dart' show DioException;
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart' show Logger;
import 'connection_settings_provider.dart';
import 'kalinka_player_api_provider.dart';
import 'playback_time_provider.dart' show appLifecycleProvider;

final _logger = Logger();

enum ConnectionStatus { none, connecting, connected, reconnecting, offline }

final connectionStateProvider =
    NotifierProvider<ConnectionStateNotifier, ConnectionStatus>(
      ConnectionStateNotifier.new,
    );

/// Incremented each time a reconnect attempt fires. `webSocketProvider` watches
/// this so that only timer-driven ticks (or a manual retry) trigger new socket
/// connection attempts — preventing Riverpod's autoDispose rebuild loop.
final retryEpochProvider =
    NotifierProvider<_RetryEpochNotifier, int>(_RetryEpochNotifier.new);

class _RetryEpochNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void increment() => state++;
}

class ConnectionStateNotifier extends Notifier<ConnectionStatus> {
  Timer? _retryTimer;
  int _retryCount = 0;
  DateTime? _reconnectStartedAt;

  /// When the connection was last known to be healthy.
  DateTime? lastConnectedAt;

  /// Whether the user dismissed the 30-second escalation card this session.
  bool escalationDismissed = false;

  /// True when reconnecting has been going for >= 30 seconds.
  bool get escalationReached =>
      _reconnectStartedAt != null &&
      DateTime.now().difference(_reconnectStartedAt!).inSeconds >= 30;

  @override
  ConnectionStatus build() {
    final settings = ref.read(connectionSettingsProvider);
    ref.onDispose(_cancelRetryTimer);

    ref.listen<AppLifecycleState>(appLifecycleProvider, (_, next) {
      _onLifecycleChange(next);
    });

    return settings.isSet ? ConnectionStatus.connecting : ConnectionStatus.none;
  }

  void _onLifecycleChange(AppLifecycleState lifecycle) {
    if (lifecycle == AppLifecycleState.resumed) {
      // Foregrounded: restart reconnection immediately if it was paused.
      if (state == ConnectionStatus.reconnecting ||
          state == ConnectionStatus.offline) {
        _startRetryTimer();
        _attemptReconnect();
      }
    } else {
      // Backgrounded: pause reconnection attempts to save battery.
      _cancelRetryTimer();
    }
  }

  void connecting() {
    _cancelRetryTimer();
    state = ConnectionStatus.connecting;
  }

  void connected() {
    _cancelRetryTimer();
    _retryCount = 0;
    _reconnectStartedAt = null;
    lastConnectedAt = DateTime.now();
    state = ConnectionStatus.connected;
  }

  void disconnected() {
    _cancelRetryTimer();
    state = ConnectionStatus.none;
  }

  /// Begin automatic reconnect attempts every 5 seconds.
  void startReconnecting() {
    if (state == ConnectionStatus.reconnecting ||
        state == ConnectionStatus.offline) {
      return;
    }
    _retryCount = 0;
    _reconnectStartedAt = DateTime.now();
    state = ConnectionStatus.reconnecting;
    _startRetryTimer();
  }

  void _startRetryTimer() {
    _retryTimer?.cancel();
    _retryTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _attemptReconnect();
    });
  }

  void markEscalationDismissed() {
    escalationDismissed = true;
  }

  /// Manually trigger a single reconnect attempt (e.g. from Retry button).
  void retryNow() {
    if (state == ConnectionStatus.offline) {
      _retryCount = 0;
      _reconnectStartedAt = DateTime.now();
      escalationDismissed = false;
      state = ConnectionStatus.reconnecting;
      _startRetryTimer();
    }
    _attemptReconnect();
  }

  Future<void> _attemptReconnect() async {
    if (ref.read(appLifecycleProvider) != AppLifecycleState.resumed) return;
    _retryCount++;
    _logger.d('Reconnect attempt #$_retryCount');
    ref.read(retryEpochProvider.notifier).increment();

    try {
      final proxy = ref.read(kalinkaProxyProvider);
      await proxy.listModules();
      // Success — server is reachable
      connected();
    } on DioException {
      _checkEscalation();
    } on Exception {
      _checkEscalation();
    }
  }

  void _checkEscalation() {
    if (_reconnectStartedAt != null &&
        DateTime.now().difference(_reconnectStartedAt!).inSeconds >= 30) {
      _cancelRetryTimer();
      state = ConnectionStatus.offline;
    }
  }

  void _cancelRetryTimer() {
    _retryTimer?.cancel();
    _retryTimer = null;
  }
}

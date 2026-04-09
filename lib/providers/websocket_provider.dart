import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/connection_settings_provider.dart';
import '../providers/connection_state_provider.dart'
    show ConnectionStatus, connectionStateProvider, retryEpochProvider;
import 'package:logger/logger.dart';

final logger = Logger();

/// Provides a configured WebSocket connection for the given path.
///
/// This keeps all connection semantics (host/port, ws vs wss) in one place,
/// and disposes the socket when the provider is torn down. Callers can
/// transform the returned socket into a `Stream<String>` similar to
final webSocketProvider = FutureProvider.family<WebSocket, String>((
  ref,
  path,
) async {
  final settings = ref.watch(connectionSettingsProvider);
  final connection = ref.read(connectionStateProvider.notifier);

  if (!settings.isSet) {
    // Stay in loading state rather than entering error state.
    // Riverpod rebuilds this provider when connectionSettingsProvider changes,
    // so the loading future is abandoned and a fresh connection is attempted.
    await Completer<void>().future; // never completes
    throw StateError('unreachable');
  }

  // Rebuild this provider each time connection_state_provider schedules a
  // retry. Without this, the rapid autoDispose dispose+recreate loop driven
  // by wire_event_provider rebuilds would bypass the 5-second timer.
  ref.watch(retryEpochProvider);

  // While offline (30 s escalation reached), hang until a manual retry
  // increments the epoch and rebuilds this provider.
  final currentStatus = ref.read(connectionStateProvider);
  if (currentStatus == ConnectionStatus.offline) {
    await Completer<void>().future; // never completes until rebuilt
    throw StateError('unreachable');
  }

  // Defer state updates to avoid modifying providers during build.
  // Skip during reconnection — calling connecting() would cancel the retry
  // timer that drives epoch increments.
  if (currentStatus != ConnectionStatus.reconnecting) {
    Future.microtask(connection.connecting);
  }

  final uri = Uri(
    scheme: 'ws',
    host: settings.host,
    port: settings.port,
    path: path.startsWith('/') ? path.substring(1) : path,
  );

  try {
    final socket = await WebSocket.connect(uri.toString());
    Future.microtask(connection.connected);

    ref.onDispose(() {
      socket.close();
    });

    return socket;
  } on Object catch (e) {
    logger.e('WebSocket connection error to $uri', error: e);
    Future.microtask(connection.startReconnecting);
    rethrow;
  }
});

final deviceWebSocketProvider = webSocketProvider('/device/ws');

final queueWebSocketProvider = webSocketProvider('/queue/ws');

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/connection_settings_provider.dart';
import '../providers/connection_state_provider.dart';
import 'package:logger/logger.dart';

final logger = Logger();

/// Provides a configured WebSocket connection for the given path.
///
/// This keeps all connection semantics (host/port, ws vs wss) in one place,
/// and disposes the socket when the provider is torn down. Callers can
/// transform the returned socket into a `Stream<String>` similar to
final webSocketProvider = FutureProvider.autoDispose.family<WebSocket, String>((
  ref,
  path,
) async {
  final settings = ref.watch(connectionSettingsProvider);
  final connection = ref.read(connectionStateProvider.notifier);

  if (!settings.isSet) {
    throw StateError('Connection settings are not configured');
  }

  // Defer state updates to avoid modifying providers during build.
  Future.microtask(connection.connecting);

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

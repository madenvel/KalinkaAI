import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data_model/kalinka_ws_api.dart';
import '../providers/websocket_provider.dart';

/// Simple WebSocket command sender for device and play queue.
final kalinkaWsApiProvider = Provider<KalinkaWsApi>((ref) {
  return KalinkaWsApi(ref);
});

class KalinkaWsApi {
  KalinkaWsApi(this._ref);

  final Ref _ref;

  /// Send a device command over the /device/ws socket.
  Future<void> sendDeviceCommand(DeviceCommand command) async {
    final socket = await _ref.read(deviceWebSocketProvider.future);
    socket.add(jsonEncode(command.toJson()));
  }

  /// Send a play queue command over the /queue/ws socket.
  Future<void> sendQueueCommand(QueueCommand command) async {
    final socket = await _ref.read(queueWebSocketProvider.future);
    socket.add(jsonEncode(command.toJson()));
  }
}

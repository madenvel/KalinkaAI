import 'package:flutter_riverpod/flutter_riverpod.dart'
    show Notifier, NotifierProvider;

enum ConnectionStatus { disconnected, connecting, connected, error }

final connectionStateProvider =
    NotifierProvider<ConnectionStateNotifier, ConnectionStatus>(
        () => ConnectionStateNotifier());

class ConnectionStateNotifier extends Notifier<ConnectionStatus> {
  @override
  ConnectionStatus build() => ConnectionStatus.disconnected;
  void connecting() => state = ConnectionStatus.connecting;
  void connected() => state = ConnectionStatus.connected;
  void error() => state = ConnectionStatus.error;
  void disconnected() => state = ConnectionStatus.disconnected;
}

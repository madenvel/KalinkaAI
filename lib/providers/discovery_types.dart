import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One address a server can be reached at, with its probe result.
class ServerEndpoint {
  final String host;
  final int port;
  final int latencyMs;

  const ServerEndpoint({
    required this.host,
    required this.port,
    required this.latencyMs,
  });
}

class DiscoveredServer {
  final String name;

  /// The fastest reachable endpoint; the one connecting uses.
  final String host;
  final int port;
  final int latencyMs;
  final String? version;

  /// The Core's stable identity (TXT server_id); null on older servers.
  final String? serverId;

  /// Every advertised address, best first; the losers are failover
  /// candidates rather than noise.
  final List<ServerEndpoint> endpoints;

  const DiscoveredServer({
    required this.name,
    required this.host,
    required this.port,
    this.latencyMs = 0,
    this.version,
    this.serverId,
    this.endpoints = const [],
  });

  /// Whether [candidate] is the listed [host] or any alternate endpoint.
  bool reachableAt(String candidate) =>
      host == candidate || endpoints.any((e) => e.host == candidate);

  /// Signal strength 0-3 derived from latency.
  int get signalStrength {
    if (latencyMs <= 0) return 0;
    if (latencyMs < 50) return 3;
    if (latencyMs < 150) return 2;
    if (latencyMs < 400) return 1;
    return 0;
  }
}

class DiscoveryState {
  final bool isScanning;
  final List<DiscoveredServer> servers;
  final String? error;

  const DiscoveryState({
    this.isScanning = false,
    this.servers = const [],
    this.error,
  });

  DiscoveryState copyWith({
    bool? isScanning,
    List<DiscoveredServer>? servers,
    String? error,
  }) {
    return DiscoveryState(
      isScanning: isScanning ?? this.isScanning,
      servers: servers ?? this.servers,
      error: error,
    );
  }
}

/// Selected at compile time: the mDNS scanner on native, a no-op stub on web.
abstract class DiscoveryNotifier extends Notifier<DiscoveryState> {
  Future<void> startScan();
  Future<void> stopScan();
  Future<void> rescan();
}

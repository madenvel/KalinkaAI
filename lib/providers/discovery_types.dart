import 'package:flutter_riverpod/flutter_riverpod.dart';

class DiscoveredServer {
  final String name;
  final String host;
  final int port;
  final int latencyMs;
  final String? version;

  const DiscoveredServer({
    required this.name,
    required this.host,
    required this.port,
    this.latencyMs = 0,
    this.version,
  });

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

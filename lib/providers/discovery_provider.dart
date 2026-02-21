import 'dart:async' show Timer;
import 'dart:convert' show utf8;

import 'package:dio/dio.dart' show Dio, BaseOptions;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart' show Logger;
import 'package:nsd/nsd.dart'
    show Discovery, ServiceStatus, startDiscovery, stopDiscovery;

final _logger = Logger();

class DiscoveredServer {
  final String name;
  final String host;
  final int port;
  final int latencyMs;

  const DiscoveredServer({
    required this.name,
    required this.host,
    required this.port,
    this.latencyMs = 0,
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

final discoveryProvider = NotifierProvider<DiscoveryNotifier, DiscoveryState>(
  DiscoveryNotifier.new,
);

class DiscoveryNotifier extends Notifier<DiscoveryState> {
  Discovery? _discovery;
  Timer? _minDurationTimer;

  @override
  DiscoveryState build() {
    ref.onDispose(() {
      stopScan();
    });
    return const DiscoveryState();
  }

  /// Start scanning for `_misc._tcp` services on the local network.
  Future<void> startScan() async {
    await stopScan();
    state = const DiscoveryState(isScanning: true);

    final foundServers = <DiscoveredServer>[];
    bool minDurationElapsed = false;

    // Enforce minimum 1.2 second scan duration for visual stability
    _minDurationTimer = Timer(const Duration(milliseconds: 1200), () {
      minDurationElapsed = true;
      if (foundServers.isNotEmpty || state.isScanning) {
        _finalizeScan(foundServers);
      }
    });

    try {
      _discovery = await startDiscovery('_misc._tcp');

      _discovery!.addServiceListener((service, status) async {
        if (status == ServiceStatus.found) {
          final host = service.addresses?.firstOrNull?.address;
          final port = service.port;

          // Read name from TXT record or fall back to service name
          String name = service.name ?? 'Kalinka Server';
          final txtName = service.txt?['name'];
          if (txtName != null) {
            name = utf8.decode(txtName);
          }

          if (host != null && port != null) {
            // Measure latency with a quick ping
            final latency = await _measureLatency(host, port);
            final server = DiscoveredServer(
              name: name,
              host: host,
              port: port,
              latencyMs: latency,
            );

            foundServers.add(server);

            if (minDurationElapsed) {
              _finalizeScan(foundServers);
            }
          }
        }
      });

      // Timeout: stop scanning after 5 seconds regardless
      Timer(const Duration(seconds: 5), () {
        if (state.isScanning) {
          _finalizeScan(foundServers);
        }
      });
    } catch (e) {
      _logger.e('mDNS discovery error', error: e);
      // If mDNS fails, just show empty results after min duration
      if (minDurationElapsed) {
        state = DiscoveryState(
          isScanning: false,
          servers: foundServers,
          error: e.toString(),
        );
      }
    }
  }

  void _finalizeScan(List<DiscoveredServer> servers) {
    // Sort by latency (best first)
    servers.sort((a, b) => a.latencyMs.compareTo(b.latencyMs));
    state = DiscoveryState(isScanning: false, servers: List.of(servers));
    _cleanupDiscovery();
  }

  /// Measure latency to a server with a quick HTTP health check.
  Future<int> _measureLatency(String host, int port) async {
    try {
      final dio = Dio(
        BaseOptions(
          baseUrl: 'http://$host:$port',
          connectTimeout: const Duration(seconds: 2),
          receiveTimeout: const Duration(seconds: 2),
        ),
      );
      final stopwatch = Stopwatch()..start();
      await dio.get('/server/modules');
      stopwatch.stop();
      dio.close();
      return stopwatch.elapsedMilliseconds;
    } catch (e) {
      return 9999;
    }
  }

  Future<void> stopScan() async {
    _minDurationTimer?.cancel();
    _minDurationTimer = null;
    await _cleanupDiscovery();
  }

  Future<void> _cleanupDiscovery() async {
    if (_discovery != null) {
      try {
        await stopDiscovery(_discovery!);
      } catch (_) {}
      _discovery = null;
    }
  }

  Future<void> rescan() async {
    await startScan();
  }
}

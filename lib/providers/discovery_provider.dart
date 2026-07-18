import 'dart:async' show StreamSubscription, Timer;
import 'dart:io' show RawDatagramSocket;

import 'package:dio/dio.dart' show Dio, BaseOptions;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart' show Logger;
import 'package:multicast_dns/multicast_dns.dart';

final _logger = Logger();

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

final discoveryProvider = NotifierProvider<DiscoveryNotifier, DiscoveryState>(
  DiscoveryNotifier.new,
);

class DiscoveryNotifier extends Notifier<DiscoveryState> {
  MDnsClient? _client;
  Timer? _minDurationTimer;
  Timer? _timeoutTimer;
  StreamSubscription<PtrResourceRecord>? _ptrSubscription;

  @override
  DiscoveryState build() {
    ref.onDispose(() {
      stopScan();
    });
    return const DiscoveryState();
  }

  /// Start scanning for `_kalinkaplayer._tcp` services on the local network.
  Future<void> startScan() async {
    await stopScan();
    state = const DiscoveryState(isScanning: true);

    final foundServers = <DiscoveredServer>[];
    bool minDurationElapsed = false;

    // Enforce minimum 1.2 second scan duration for visual stability
    _minDurationTimer = Timer(const Duration(milliseconds: 1200), () {
      minDurationElapsed = true;
    });

    // Timeout: stop scanning after 5 seconds regardless
    _timeoutTimer = Timer(const Duration(seconds: 5), () {
      if (state.isScanning) {
        _finalizeScan(foundServers);
      }
    });

    try {
      _client = MDnsClient(
        rawDatagramSocketFactory: (
          dynamic host,
          int port, {
          bool reuseAddress = false,
          bool reusePort = false,
          int ttl = 1,
        }) async {
          try {
            return await RawDatagramSocket.bind(
              host,
              port,
              reuseAddress: reuseAddress,
              reusePort: reusePort,
              ttl: ttl,
            );
          } catch (_) {
            // SO_REUSEPORT is not supported on some Android kernels — retry without it.
            return RawDatagramSocket.bind(
              host,
              port,
              reuseAddress: reuseAddress,
              reusePort: false,
              ttl: ttl,
            );
          }
        },
      );
      await _client!.start();

      const serviceType = '_kalinkaplayer._tcp.local';

      _ptrSubscription = _client!
          .lookup<PtrResourceRecord>(
            ResourceRecordQuery.serverPointer(serviceType),
            timeout: const Duration(seconds: 4),
          )
          .listen(
            (ptr) async {
              await _resolveService(ptr, foundServers);
              if (minDurationElapsed) {
                _finalizeScan(foundServers);
              }
            },
            onError: (Object e) {
              _logger.e('mDNS discovery error', error: e);
            },
          );
    } catch (e) {
      _logger.e('mDNS discovery error', error: e);
      _minDurationTimer?.cancel();
      _timeoutTimer?.cancel();
      state = DiscoveryState(
        isScanning: false,
        servers: foundServers,
        error: e.toString(),
      );
    }
  }

  Future<void> _resolveService(
    PtrResourceRecord ptr,
    List<DiscoveredServer> foundServers,
  ) async {
    final client = _client;
    if (client == null) return;

    // Service name from the PTR domain (strip the service type suffix)
    final name = ptr.domainName.split('.').first;

    String? host;
    int port = 0;
    String? version;

    // SRV record gives host and port
    await for (final SrvResourceRecord srv in client.lookup<SrvResourceRecord>(
      ResourceRecordQuery.service(ptr.domainName),
      timeout: const Duration(seconds: 2),
    )) {
      port = srv.port;

      // IPv4 address
      await for (final IPAddressResourceRecord ip
          in client.lookup<IPAddressResourceRecord>(
        ResourceRecordQuery.addressIPv4(srv.target),
        timeout: const Duration(seconds: 2),
      )) {
        host = ip.address.address;
        break;
      }

      // Fallback to IPv6 if no IPv4 found
      if (host == null) {
        await for (final IPAddressResourceRecord ip
            in client.lookup<IPAddressResourceRecord>(
          ResourceRecordQuery.addressIPv6(srv.target),
          timeout: const Duration(seconds: 2),
        )) {
          host = ip.address.address;
          break;
        }
      }
      break;
    }

    // TXT record for server_version
    await for (final TxtResourceRecord txt in client.lookup<TxtResourceRecord>(
      ResourceRecordQuery.text(ptr.domainName),
      timeout: const Duration(seconds: 2),
    )) {
      for (final entry in txt.text.split('\n')) {
        if (entry.startsWith('server_version=')) {
          version = entry.substring('server_version='.length);
        }
      }
      break;
    }

    if (host != null && port > 0) {
      final latency = await _measureLatency(host, port);
      foundServers.add(DiscoveredServer(
        name: name,
        host: host,
        port: port,
        latencyMs: latency,
        version: version,
      ));
    }
  }

  void _finalizeScan(List<DiscoveredServer> servers) {
    if (!state.isScanning) return;
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
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    await _ptrSubscription?.cancel();
    _ptrSubscription = null;
    await _cleanupDiscovery();
  }

  Future<void> _cleanupDiscovery() async {
    _client?.stop();
    _client = null;
  }

  Future<void> rescan() async {
    await startScan();
  }
}

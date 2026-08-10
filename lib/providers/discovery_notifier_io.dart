import 'dart:async' show StreamSubscription, Timer;
import 'dart:io'
    show
        InternetAddress,
        InternetAddressType,
        NetworkInterface,
        Platform,
        RawDatagramSocket;

import 'package:dio/dio.dart' show Dio, BaseOptions;
import 'package:logger/logger.dart' show Logger;
import 'package:multicast_dns/multicast_dns.dart';

import 'discovery_types.dart';

final _logger = Logger();

/// How long to wait for every A/AAAA record of a service — a multi-homed
/// server answers with one per interface, so we cannot stop at the first.
const _addressLookupTimeout = Duration(seconds: 1);

/// Budget for the health check that decides whether an address is reachable.
const _probeTimeout = Duration(seconds: 1);

const _unreachableLatencyMs = 9999;

/// How long to keep listening for service announcements.
const _announcementWindow = Duration(seconds: 4);

/// Backstop for the whole scan: the announcement window plus room for one
/// last service to resolve within it.
const _scanTimeout = Duration(seconds: 7);

// `multicast_dns` keeps its own copies of these private.
final _mDnsGroupIPv4 = InternetAddress('224.0.0.251');
final _mDnsGroupIPv6 = InternetAddress('FF02::FB');

/// Interfaces that accept a multicast join for the mDNS group.
///
/// `MDnsClient.start()` joins on every interface it is handed without guarding
/// the call, so one adapter that refuses takes down the whole scan — Windows
/// virtual adapters reject it with WSAENOPROTOOPT. Rehearse the joins the same
/// way, on one throwaway socket, and keep the interfaces that survive.
Future<Iterable<NetworkInterface>> _multicastCapableInterfaces(
  InternetAddressType type,
) async {
  final isIPv6 = type == InternetAddressType.IPv6;
  final group = isIPv6 ? _mDnsGroupIPv6 : _mDnsGroupIPv4;
  final interfaces = await NetworkInterface.list(
    includeLinkLocal: true,
    type: type,
    includeLoopback: true,
  );

  final usable = <NetworkInterface>[];
  final probe = await RawDatagramSocket.bind(
    isIPv6 ? InternetAddress.anyIPv6 : InternetAddress.anyIPv4,
    0,
    reuseAddress: true,
  );
  try {
    for (final interface in interfaces) {
      try {
        probe.joinMulticast(group, interface);
        usable.add(interface);
      } catch (e) {
        _logger.d('Skipping ${interface.name}: multicast join failed ($e)');
      }
    }
  } finally {
    probe.close();
  }
  return usable;
}

DiscoveryNotifier createDiscoveryNotifier() => IoDiscoveryNotifier();

/// Native mDNS discovery of `_kalinkaplayer._tcp` services on the local network.
class IoDiscoveryNotifier extends DiscoveryNotifier {
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
  @override
  Future<void> startScan() async {
    await stopScan();
    state = const DiscoveryState(isScanning: true);

    final foundServers = <DiscoveredServer>[];
    // SRV target host:port pairs already resolved — re-announcements within
    // the scan window would otherwise list the same server repeatedly.
    final resolvedTargets = <String>{};
    bool minDurationElapsed = false;
    // Resolutions run concurrently, and a slow one (an unreachable address
    // costs a full probe timeout) must not be finalized away by a faster
    // neighbour, nor by the announcement window closing around it.
    bool announcementsDone = false;
    int pendingResolutions = 0;

    // Everything announced has been resolved and there is nothing left to wait
    // for. Servers keep re-announcing, so finishing early would list whichever
    // ones happened to answer first.
    void finalizeWhenSettled() {
      if (minDurationElapsed && announcementsDone && pendingResolutions == 0) {
        _finalizeScan(foundServers);
      }
    }

    // Enforce minimum 1.2 second scan duration for visual stability
    _minDurationTimer = Timer(const Duration(milliseconds: 1200), () {
      minDurationElapsed = true;
      finalizeWhenSettled();
    });

    // Timeout: stop scanning regardless. Sits past the announcement window so
    // a service announced at the end of it still gets its resolution.
    _timeoutTimer = Timer(_scanTimeout, () {
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
              // Windows has no SO_REUSEPORT; asking logs a native error per bind.
              reusePort: reusePort && !Platform.isWindows,
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
      await _client!.start(interfacesFactory: _multicastCapableInterfaces);

      const serviceType = '_kalinkaplayer._tcp.local';

      _ptrSubscription = _client!
          .lookup<PtrResourceRecord>(
            ResourceRecordQuery.serverPointer(serviceType),
            timeout: _announcementWindow,
          )
          .listen(
            (ptr) async {
              pendingResolutions++;
              try {
                await _resolveService(ptr, foundServers, resolvedTargets);
              } finally {
                pendingResolutions--;
              }
              finalizeWhenSettled();
            },
            onError: (Object e) {
              _logger.e('mDNS discovery error', error: e);
            },
            onDone: () {
              announcementsDone = true;
              finalizeWhenSettled();
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
    Set<String> resolvedTargets,
  ) async {
    final client = _client;
    if (client == null) return;

    // Service name from the PTR domain (strip the service type suffix)
    final name = ptr.domainName.split('.').first;

    // A multi-homed server answers with one A record per interface; only the
    // ones on a network we share are reachable.
    final candidates = <String>[];
    int port = 0;
    String? version;

    // SRV record gives host and port
    await for (final SrvResourceRecord srv in client.lookup<SrvResourceRecord>(
      ResourceRecordQuery.service(ptr.domainName),
      timeout: const Duration(seconds: 2),
    )) {
      // One machine per list entry.
      if (!resolvedTargets.add('${srv.target}:${srv.port}')) return;
      port = srv.port;

      // IPv4 addresses
      await for (final IPAddressResourceRecord ip
          in client.lookup<IPAddressResourceRecord>(
        ResourceRecordQuery.addressIPv4(srv.target),
        timeout: _addressLookupTimeout,
      )) {
        final address = ip.address.address;
        if (!candidates.contains(address)) candidates.add(address);
      }

      // Fallback to IPv6 if no IPv4 found
      if (candidates.isEmpty) {
        await for (final IPAddressResourceRecord ip
            in client.lookup<IPAddressResourceRecord>(
          ResourceRecordQuery.addressIPv6(srv.target),
          timeout: _addressLookupTimeout,
        )) {
          final address = ip.address.address;
          if (!candidates.contains(address)) candidates.add(address);
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

    if (candidates.isEmpty || port <= 0) return;

    // Probe every advertised address at once and keep the fastest that answers,
    // so an interface we cannot route to never becomes the listed entry.
    final probes = await Future.wait([
      for (final candidate in candidates) _measureLatency(candidate, port),
    ]);
    var best = 0;
    for (var i = 1; i < probes.length; i++) {
      if (probes[i] < probes[best]) best = i;
    }

    foundServers.add(DiscoveredServer(
      name: name,
      host: candidates[best],
      port: port,
      latencyMs: probes[best],
      version: version,
    ));
  }

  void _finalizeScan(List<DiscoveredServer> servers) {
    if (!state.isScanning) return;
    _minDurationTimer?.cancel();
    _minDurationTimer = null;
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    // Sort by latency (best first)
    servers.sort((a, b) => a.latencyMs.compareTo(b.latencyMs));
    state = DiscoveryState(isScanning: false, servers: List.of(servers));
    _cleanupDiscovery();
  }

  /// Measure latency to a server with a quick HTTP health check.
  ///
  /// Doubles as the reachability test: an address on a network we cannot route
  /// to times out and scores [_unreachableLatencyMs].
  Future<int> _measureLatency(String host, int port) async {
    try {
      final dio = Dio(
        BaseOptions(
          // Uri() brackets IPv6 hosts (the SRV lookup can resolve one).
          baseUrl: Uri(scheme: 'http', host: host, port: port).toString(),
          connectTimeout: _probeTimeout,
          receiveTimeout: _probeTimeout,
        ),
      );
      final stopwatch = Stopwatch()..start();
      await dio.get('/server/modules');
      stopwatch.stop();
      dio.close();
      return stopwatch.elapsedMilliseconds;
    } catch (e) {
      return _unreachableLatencyMs;
    }
  }

  @override
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

  @override
  Future<void> rescan() async {
    await startScan();
  }
}

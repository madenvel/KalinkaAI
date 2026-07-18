import 'discovery_types.dart';

DiscoveryNotifier createDiscoveryNotifier() => StubDiscoveryNotifier();

/// Web: no mDNS in the browser — scans complete immediately with no results.
class StubDiscoveryNotifier extends DiscoveryNotifier {
  @override
  DiscoveryState build() => const DiscoveryState();

  @override
  Future<void> startScan() async {
    state = const DiscoveryState(isScanning: false, servers: []);
  }

  @override
  Future<void> stopScan() async {}

  @override
  Future<void> rescan() async {}
}

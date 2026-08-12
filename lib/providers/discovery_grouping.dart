/// Groups resolved mDNS instances into servers, one entry per Core.
///
/// A new-style Core announces one single-address instance per interface, all
/// carrying the same `server_id` TXT value; the interface-suffixed instance
/// names only keep the per-interface responders out of RFC 6762 conflict
/// defence and must never reach the user. An old Core announces a single
/// instance with neither key. Mirrors the native renderer's CoreGrouper.
library;

import 'discovery_types.dart';

/// One resolved service instance, its candidate addresses already probed.
class ResolvedInstance {
  /// Full PTR domain name; unique per instance, the fallback group key.
  final String instanceName;

  /// The PTR label — what old Cores are listed as.
  final String label;
  final List<ServerEndpoint> endpoints;
  final String? version;
  final String? serverId;
  final String? displayName;

  const ResolvedInstance({
    required this.instanceName,
    required this.label,
    required this.endpoints,
    this.version,
    this.serverId,
    this.displayName,
  });
}

/// One entry per Core, fastest first: instances sharing a `server_id` merge,
/// their endpoint unions sorted best-first; an instance without one (an old
/// Core) stands alone, keyed by its instance name and named by its PTR label.
List<DiscoveredServer> groupResolvedInstances(
  List<ResolvedInstance> instances,
) {
  // Insertion-ordered so the output is stable across scans.
  final groups = <String, List<ResolvedInstance>>{};
  for (final instance in instances) {
    final serverId = instance.serverId;
    final key = (serverId == null || serverId.isEmpty)
        ? instance.instanceName
        : serverId;
    groups.putIfAbsent(key, () => []).add(instance);
  }

  final servers = <DiscoveredServer>[];
  for (final members in groups.values) {
    final endpoints = <ServerEndpoint>[];
    final seen = <String>{};
    for (final member in members) {
      for (final endpoint in member.endpoints) {
        if (seen.add('${endpoint.host}:${endpoint.port}')) {
          endpoints.add(endpoint);
        }
      }
    }
    if (endpoints.isEmpty) continue;
    endpoints.sort((a, b) => a.latencyMs.compareTo(b.latencyMs));

    final first = members.first;
    final displayName = first.displayName;
    servers.add(
      DiscoveredServer(
        name: (displayName == null || displayName.isEmpty)
            ? first.label
            : displayName,
        host: endpoints.first.host,
        port: endpoints.first.port,
        latencyMs: endpoints.first.latencyMs,
        version: first.version,
        serverId: first.serverId,
        endpoints: endpoints,
      ),
    );
  }
  servers.sort((a, b) => a.latencyMs.compareTo(b.latencyMs));
  return servers;
}

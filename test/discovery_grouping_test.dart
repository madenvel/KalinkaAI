// Grouping resolved mDNS instances into one list entry per Core, mirroring
// the native renderer's CoreGrouper: server_id is the group key when a Core
// advertises one, the instance name otherwise (old Cores, unchanged).

import 'package:flutter_test/flutter_test.dart';
import 'package:kalinka/providers/discovery_grouping.dart';
import 'package:kalinka/providers/discovery_types.dart';

const serverId = '9f1c9f2e-1111-2222-3333-444455556666';

ResolvedInstance instance(
  String interface, {
  required String host,
  int latencyMs = 10,
  String? serverId,
  String? displayName,
  String? version = '1.2.0',
}) {
  return ResolvedInstance(
    instanceName: 'My Kalinka Service ($interface)._kalinkaplayer._tcp.local',
    label: 'My Kalinka Service ($interface)',
    endpoints: [ServerEndpoint(host: host, port: 8000, latencyMs: latencyMs)],
    version: version,
    serverId: serverId,
    displayName: displayName,
  );
}

void main() {
  test('instances sharing a server_id are one Core with every endpoint', () {
    final servers = groupResolvedInstances([
      instance(
        'eth0',
        host: '192.168.1.20',
        latencyMs: 40,
        serverId: serverId,
        displayName: 'My Kalinka Service',
      ),
      instance(
        'wlan0',
        host: '10.20.0.15',
        latencyMs: 8,
        serverId: serverId,
        displayName: 'My Kalinka Service',
      ),
    ]);

    final server = servers.single;
    // The suffixed instance names stay invisible.
    expect(server.name, 'My Kalinka Service');
    expect(server.serverId, serverId);
    // Fastest endpoint listed; the loser kept as an alternate.
    expect(server.host, '10.20.0.15');
    expect(server.latencyMs, 8);
    expect(
      [for (final e in server.endpoints) e.host],
      ['10.20.0.15', '192.168.1.20'],
    );
  });

  test('an old-style single instance is listed as before', () {
    final servers = groupResolvedInstances([
      const ResolvedInstance(
        instanceName: 'My Kalinka Service._kalinkaplayer._tcp.local',
        label: 'My Kalinka Service',
        endpoints: [
          // Multi-homed old Core: several A records on one instance.
          ServerEndpoint(host: '192.168.1.20', port: 8000, latencyMs: 9999),
          ServerEndpoint(host: '10.20.0.15', port: 8000, latencyMs: 12),
        ],
        version: '0.9.0',
      ),
    ]);

    final server = servers.single;
    expect(server.name, 'My Kalinka Service');
    expect(server.serverId, isNull);
    expect(server.host, '10.20.0.15');
    expect(server.port, 8000);
    expect(server.latencyMs, 12);
    expect(server.version, '0.9.0');
    expect(server.endpoints, hasLength(2));
  });

  test('two Cores with the same display_name stay two entries', () {
    final servers = groupResolvedInstances([
      instance(
        'eth0',
        host: '192.168.1.20',
        latencyMs: 5,
        serverId: 'core-a',
        displayName: 'Kalinka',
      ),
      instance(
        'eth0',
        host: '192.168.1.30',
        latencyMs: 15,
        serverId: 'core-b',
        displayName: 'Kalinka',
      ),
    ]);

    expect(servers, hasLength(2));
    expect(servers[0].name, 'Kalinka');
    expect(servers[1].name, 'Kalinka');
    expect(servers[0].serverId, 'core-a');
    expect(servers[1].serverId, 'core-b');
    expect(servers[0].host, '192.168.1.20');
    expect(servers[1].host, '192.168.1.30');
  });

  test('old and new Cores share a scan, listed fastest first', () {
    final servers = groupResolvedInstances([
      const ResolvedInstance(
        instanceName: 'Old Kalinka._kalinkaplayer._tcp.local',
        label: 'Old Kalinka',
        endpoints: [
          ServerEndpoint(host: '192.168.1.5', port: 8000, latencyMs: 20),
        ],
      ),
      instance(
        'eth0',
        host: '192.168.1.20',
        serverId: serverId,
        displayName: 'New Kalinka',
      ),
      instance(
        'wlan0',
        host: '10.20.0.15',
        serverId: serverId,
        displayName: 'New Kalinka',
      ),
    ]);

    expect(servers, hasLength(2));
    expect(servers[0].name, 'New Kalinka');
    expect(servers[0].endpoints, hasLength(2));
    expect(servers[1].name, 'Old Kalinka');
  });

  test('a duplicate address across instances appears once', () {
    final servers = groupResolvedInstances([
      instance('eth0', host: '192.168.1.20', serverId: serverId),
      instance('eth0 (2)', host: '192.168.1.20', serverId: serverId),
    ]);

    expect(servers.single.endpoints, hasLength(1));
  });

  test('metadata missing on one member is taken from another', () {
    final servers = groupResolvedInstances([
      instance(
        'eth0',
        host: '192.168.1.20',
        serverId: serverId,
        displayName: null,
        version: null,
      ),
      instance(
        'wlan0',
        host: '10.20.0.15',
        serverId: serverId,
        displayName: 'My Kalinka Service',
      ),
    ]);

    final server = servers.single;
    expect(server.name, 'My Kalinka Service');
    expect(server.version, '1.2.0');
  });

  test('an instance without a display_name falls back to its label', () {
    final servers = groupResolvedInstances([
      instance('eth0', host: '192.168.1.20', serverId: serverId),
    ]);

    expect(servers.single.name, 'My Kalinka Service (eth0)');
  });

  test('an instance with no reachable endpoint still lists', () {
    // Unreachable addresses score a sentinel latency instead of vanishing.
    final servers = groupResolvedInstances([
      instance('eth0', host: '192.168.1.20', latencyMs: 9999),
    ]);

    expect(servers.single.latencyMs, 9999);
  });

  test('reachableAt matches the listed host and every alternate', () {
    final server = groupResolvedInstances([
      instance('eth0', host: '192.168.1.20', latencyMs: 40, serverId: serverId),
      instance('wlan0', host: '10.20.0.15', latencyMs: 8, serverId: serverId),
    ]).single;

    expect(server.reachableAt('10.20.0.15'), isTrue);
    expect(server.reachableAt('192.168.1.20'), isTrue);
    expect(server.reachableAt('192.168.1.99'), isFalse);
  });
}

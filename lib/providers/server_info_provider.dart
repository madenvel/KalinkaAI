import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'kalinka_player_api_provider.dart';

class ServerInfo {
  final String version;
  final int latencyMs;

  const ServerInfo({required this.version, required this.latencyMs});
}

/// Fetches server version and measures latency via a round-trip GET.
final serverInfoProvider = FutureProvider.autoDispose<ServerInfo>((ref) async {
  final api = ref.read(kalinkaProxyProvider);
  final stopwatch = Stopwatch()..start();
  final settings = await api.getSettings();
  stopwatch.stop();

  final version = settings['version']?.toString() ?? 'Unknown';
  return ServerInfo(version: version, latencyMs: stopwatch.elapsedMilliseconds);
});

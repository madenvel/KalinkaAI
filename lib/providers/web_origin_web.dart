import 'package:web/web.dart' as web;

/// Derive the serving host + port from `window.location`. An empty port means
/// the protocol default (443 for https, else 80).
({String host, int port})? webServingOrigin() {
  final loc = web.window.location;
  final host = loc.hostname;
  if (host.isEmpty) return null;
  final portStr = loc.port;
  final port = portStr.isNotEmpty
      ? (int.tryParse(portStr) ?? 0)
      : (loc.protocol == 'https:' ? 443 : 80);
  if (port <= 0) return null;
  return (host: host, port: port);
}

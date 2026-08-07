import 'dart:math';

/// Who this renderer says it is in Hello.
class RendererIdentity {
  /// Stable across restarts/reloads (persisted); how the server tells
  /// renderers apart — and how the app recognises its own row in the picker.
  final String rendererId;

  /// Fresh per app session.
  final String instanceId;

  final String friendlyName;
  final String softwareVersion;

  /// Platform.os on the wire, e.g. "web".
  final String os;

  const RendererIdentity({
    required this.rendererId,
    required this.instanceId,
    required this.friendlyName,
    required this.softwareVersion,
    required this.os,
  });
}

/// Random (v4) UUID, lowercase hex — no dependency needed for one id.
String newUuid() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = [
    for (final b in bytes) b.toRadixString(16).padLeft(2, '0'),
  ].join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

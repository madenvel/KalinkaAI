import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'discovery_types.dart';
// Native uses the mDNS scanner; web has no mDNS, so a no-op stub is compiled in.
import 'discovery_notifier_io.dart'
    if (dart.library.js_interop) 'discovery_notifier_stub.dart';

export 'discovery_types.dart' show DiscoveredServer, DiscoveryState;

final discoveryProvider = NotifierProvider<DiscoveryNotifier, DiscoveryState>(
  createDiscoveryNotifier,
);

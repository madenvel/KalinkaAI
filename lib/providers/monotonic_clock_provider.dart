import 'package:flutter_riverpod/flutter_riverpod.dart' show Provider;

final monotonicClockProvider = Provider<Stopwatch>((ref) {
  final sw = Stopwatch()..start();
  ref.onDispose(sw.stop);
  return sw;
});

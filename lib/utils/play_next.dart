import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_state_provider.dart' show playerStateProvider;

int? playNextInsertIndex(WidgetRef ref) {
  final currentIndex = ref.read(playerStateProvider).index;
  if (currentIndex == null) {
    return null;
  }
  return currentIndex + 1;
}

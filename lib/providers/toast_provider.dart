import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A single in-app toast notification.
class ToastEntry {
  final String id;
  final String message;
  final bool isError;

  /// When true the [_ToastCard] widget plays its exit animation.
  /// The entry is removed from the list ~250 ms after this flips.
  final bool dismissing;

  const ToastEntry({
    required this.id,
    required this.message,
    required this.isError,
    this.dismissing = false,
  });

  ToastEntry copyWith({bool? dismissing}) => ToastEntry(
    id: id,
    message: message,
    isError: isError,
    dismissing: dismissing ?? this.dismissing,
  );
}

class ToastNotifier extends Notifier<List<ToastEntry>> {
  static const _maxToasts = 3;
  static const _animationExtraMs = 250;

  final Map<String, Timer> _timers = {};
  int _counter = 0;

  @override
  List<ToastEntry> build() => [];

  /// Show a toast. Success toasts dismiss after 2 s; error toasts after 3 s.
  void show(String message, {bool isError = false}) {
    final id = '${DateTime.now().millisecondsSinceEpoch}_${_counter++}';
    final entry = ToastEntry(id: id, message: message, isError: isError);

    var list = [...state, entry];

    // Drop oldest if over the limit
    if (list.length > _maxToasts) {
      final removed = list.first;
      list = list.sublist(1);
      _timers.remove(removed.id)?.cancel();
    }

    state = list;

    final displayMs = isError ? 3000 : 2000;
    _timers[id] = Timer(Duration(milliseconds: displayMs), () => _beginDismiss(id));
  }

  void _beginDismiss(String id) {
    state = [
      for (final e in state) if (e.id == id) e.copyWith(dismissing: true) else e,
    ];
    _timers[id] = Timer(
      const Duration(milliseconds: _animationExtraMs),
      () => _remove(id),
    );
  }

  void _remove(String id) {
    _timers.remove(id)?.cancel();
    state = state.where((e) => e.id != id).toList();
  }
}

final toastProvider = NotifierProvider<ToastNotifier, List<ToastEntry>>(
  ToastNotifier.new,
);

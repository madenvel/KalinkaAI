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

  ToastEntry copyWith({String? message, bool? isError, bool? dismissing}) =>
      ToastEntry(
        id: id,
        message: message ?? this.message,
        isError: isError ?? this.isError,
        dismissing: dismissing ?? this.dismissing,
      );
}

class ToastNotifier extends Notifier<List<ToastEntry>> {
  static const _maxToasts = 3;
  static const _animationExtraMs = 250;
  static const _successDisplayMs = 2000;
  static const _errorDisplayMs = 3000;

  final Map<String, Timer> _timers = {};
  String? _trackDeletionToastId;
  final List<String> _deletedTrackTitles = [];
  int _counter = 0;

  @override
  List<ToastEntry> build() => [];

  /// Show a toast. Success toasts dismiss after 2 s; error toasts after 3 s.
  void show(String message, {bool isError = false}) {
    final id = _appendToast(message: message, isError: isError);
    final displayMs = isError ? _errorDisplayMs : _successDisplayMs;
    _restartDisplayTimer(id, displayMs);
  }

  /// Aggregate sequential queue track deletions into a single toast.
  void showTrackRemoved(String title) {
    _deletedTrackTitles.add(_shortenTitle(title));
    final message = _buildTrackDeletedMessage();

    final activeId = _trackDeletionToastId;
    if (activeId != null && state.any((entry) => entry.id == activeId)) {
      state = [
        for (final entry in state)
          if (entry.id == activeId)
            entry.copyWith(message: message, isError: false, dismissing: false)
          else
            entry,
      ];
      _restartDisplayTimer(activeId, _successDisplayMs);
      return;
    }

    final id = _appendToast(message: message, isError: false);
    _trackDeletionToastId = id;
    _restartDisplayTimer(id, _successDisplayMs);
  }

  void _beginDismiss(String id) {
    state = [
      for (final e in state)
        if (e.id == id) e.copyWith(dismissing: true) else e,
    ];
    _timers[id] = Timer(
      const Duration(milliseconds: _animationExtraMs),
      () => _remove(id),
    );
  }

  void _remove(String id) {
    _timers.remove(id)?.cancel();
    if (id == _trackDeletionToastId) {
      _trackDeletionToastId = null;
      _deletedTrackTitles.clear();
    }
    state = state.where((e) => e.id != id).toList();
  }

  String _appendToast({required String message, required bool isError}) {
    final id = '${DateTime.now().millisecondsSinceEpoch}_${_counter++}';
    final entry = ToastEntry(id: id, message: message, isError: isError);

    var list = [...state, entry];

    if (list.length > _maxToasts) {
      final removed = list.first;
      list = list.sublist(1);
      _timers.remove(removed.id)?.cancel();
      if (removed.id == _trackDeletionToastId) {
        _trackDeletionToastId = null;
        _deletedTrackTitles.clear();
      }
    }

    state = list;
    return id;
  }

  void _restartDisplayTimer(String id, int displayMs) {
    _timers.remove(id)?.cancel();
    _timers[id] = Timer(
      Duration(milliseconds: displayMs),
      () => _beginDismiss(id),
    );
  }

  String _buildTrackDeletedMessage() {
    final count = _deletedTrackTitles.length;
    if (count == 0) return 'Track removed';
    if (count == 1) return 'Removed ${_deletedTrackTitles[0]}';
    if (count == 2) {
      return 'Removed ${_deletedTrackTitles[0]}, ${_deletedTrackTitles[1]}';
    }
    final others = count - 2;
    final noun = others == 1 ? 'other' : 'others';
    return 'Removed ${_deletedTrackTitles[0]}, ${_deletedTrackTitles[1]} and $others $noun';
  }

  String _shortenTitle(String title) {
    final normalized = title.trim();
    if (normalized.isEmpty) return 'Untitled';
    if (normalized.length <= 28) return '"$normalized"';
    final shortened = '${normalized.substring(0, 27)}…';
    return '"$shortened"';
  }
}

final toastProvider = NotifierProvider<ToastNotifier, List<ToastEntry>>(
  ToastNotifier.new,
);

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A single in-app toast notification.
class ToastEntry {
  final String id;
  final String message;
  final bool isError;

  /// When true the card shows a spinner instead of a status dot and does not
  /// auto-dismiss (used for the shared "queue activity" toast while an add or
  /// playback request is in flight).
  final bool isLoading;

  /// When true the card renders as a compact, right-aligned pill (used for the
  /// queue-activity spinner and its result) rather than a full-width toast.
  final bool compact;

  /// When true the [_ToastCard] widget plays its exit animation.
  /// The entry is removed from the list ~250 ms after this flips.
  final bool dismissing;

  const ToastEntry({
    required this.id,
    required this.message,
    required this.isError,
    this.isLoading = false,
    this.compact = false,
    this.dismissing = false,
  });

  ToastEntry copyWith({
    String? message,
    bool? isError,
    bool? isLoading,
    bool? compact,
    bool? dismissing,
  }) => ToastEntry(
    id: id,
    message: message ?? this.message,
    isError: isError ?? this.isError,
    isLoading: isLoading ?? this.isLoading,
    compact: compact ?? this.compact,
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
  bool _isDisposed = false;

  // Shared "queue activity" toast: a single spinner that reflects all in-flight
  // add/playback requests. Stays a spinner while [_pendingQueueOps] > 0 and
  // morphs into the result of the last operation to finish.
  int _pendingQueueOps = 0;
  String? _queueActivityToastId;

  @override
  List<ToastEntry> build() {
    _isDisposed = false;
    ref.onDispose(() {
      _isDisposed = true;
      for (final timer in _timers.values) {
        timer.cancel();
      }
      _timers.clear();
      _trackDeletionToastId = null;
      _deletedTrackTitles.clear();
      _pendingQueueOps = 0;
      _queueActivityToastId = null;
    });
    return [];
  }

  /// Show a toast. Success toasts dismiss after 2 s; error toasts after 3 s.
  void show(String message, {bool isError = false}) {
    if (_isDisposed) return;
    final id = _appendToast(message: message, isError: isError);
    final displayMs = isError ? _errorDisplayMs : _successDisplayMs;
    _restartDisplayTimer(id, displayMs);
  }

  /// Aggregate sequential queue track deletions into a single toast.
  void showTrackRemoved(String title) {
    if (_isDisposed) return;
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

  /// Begin one queue add/playback operation. Shows the shared spinner toast,
  /// or — if a previous result toast is still on screen — reverts it back to a
  /// spinner. Every call MUST be paired with [endQueueActivity].
  void beginQueueActivity(String message) {
    if (_isDisposed) return;
    _pendingQueueOps++;

    final activeId = _queueActivityToastId;
    if (activeId != null && state.any((e) => e.id == activeId)) {
      // Revive/keep the existing activity toast as a spinner. Cancelling its
      // timer covers the "result still showing, user adds again" case.
      _timers.remove(activeId)?.cancel();
      state = [
        for (final e in state)
          if (e.id == activeId)
            e.copyWith(
              message: message,
              isError: false,
              isLoading: true,
              dismissing: false,
            )
          else
            e,
      ];
      return;
    }

    _queueActivityToastId = _appendToast(
      message: message,
      isError: false,
      isLoading: true,
      compact: true,
    );
  }

  /// Complete one queue operation. While other operations are still in flight
  /// the spinner stays; when the last one finishes the toast morphs into
  /// [message] and auto-dismisses.
  void endQueueActivity(String message, {bool isError = false}) {
    if (_isDisposed) return;
    if (_pendingQueueOps > 0) _pendingQueueOps--;

    final activeId = _queueActivityToastId;
    if (activeId == null || !state.any((e) => e.id == activeId)) {
      // Activity toast was evicted (e.g. by other toasts) — surface the result
      // as a normal compact toast instead.
      final id = _appendToast(
        message: message,
        isError: isError,
        compact: true,
      );
      _restartDisplayTimer(id, isError ? _errorDisplayMs : _successDisplayMs);
      return;
    }

    // Still more requests pending — keep the spinner.
    if (_pendingQueueOps > 0) return;

    state = [
      for (final e in state)
        if (e.id == activeId)
          e.copyWith(
            message: message,
            isError: isError,
            isLoading: false,
            dismissing: false,
          )
        else
          e,
    ];
    _restartDisplayTimer(
      activeId,
      isError ? _errorDisplayMs : _successDisplayMs,
    );
  }

  void _beginDismiss(String id) {
    if (_isDisposed) return;
    state = [
      for (final e in state)
        if (e.id == id) e.copyWith(dismissing: true) else e,
    ];
    _timers[id] = Timer(const Duration(milliseconds: _animationExtraMs), () {
      if (_isDisposed) return;
      _remove(id);
    });
  }

  void _remove(String id) {
    if (_isDisposed) return;
    _timers.remove(id)?.cancel();
    if (id == _trackDeletionToastId) {
      _trackDeletionToastId = null;
      _deletedTrackTitles.clear();
    }
    if (id == _queueActivityToastId) {
      _queueActivityToastId = null;
    }
    state = state.where((e) => e.id != id).toList();
  }

  String _appendToast({
    required String message,
    required bool isError,
    bool isLoading = false,
    bool compact = false,
  }) {
    if (_isDisposed) return '';
    final id = '${DateTime.now().millisecondsSinceEpoch}_${_counter++}';
    final entry = ToastEntry(
      id: id,
      message: message,
      isError: isError,
      isLoading: isLoading,
      compact: compact,
    );

    var list = [...state, entry];

    if (list.length > _maxToasts) {
      final removed = list.first;
      list = list.sublist(1);
      _timers.remove(removed.id)?.cancel();
      if (removed.id == _trackDeletionToastId) {
        _trackDeletionToastId = null;
        _deletedTrackTitles.clear();
      }
      if (removed.id == _queueActivityToastId) {
        _queueActivityToastId = null;
      }
    }

    state = list;
    return id;
  }

  void _restartDisplayTimer(String id, int displayMs) {
    if (_isDisposed || id.isEmpty) return;
    _timers.remove(id)?.cancel();
    _timers[id] = Timer(Duration(milliseconds: displayMs), () {
      if (_isDisposed) return;
      _beginDismiss(id);
    });
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

extension ConsumerStateToastX<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  void showSafeToast(String message, {bool isError = false}) {
    if (!mounted) return;
    ref.read(toastProvider.notifier).show(message, isError: isError);
  }

  /// Runs a queue add/playback request behind the shared activity spinner: shows
  /// [pending] while [action] is in flight, then morphs the toast into [done]
  /// (or [failed] on error). Safe to call concurrently — overlapping calls keep
  /// the spinner until the last finishes. The toast notifier is captured up
  /// front so completion is reported even if this widget is disposed mid-request
  /// (e.g. the row scrolls off).
  Future<void> runQueueActivity<R>({
    required String pending,
    required Future<R> Function() action,
    required String Function(R result) done,
    String Function(Object error)? failed,
  }) async {
    final toast = ref.read(toastProvider.notifier);
    toast.beginQueueActivity(pending);
    try {
      final result = await action();
      toast.endQueueActivity(done(result));
    } catch (e) {
      toast.endQueueActivity(failed?.call(e) ?? 'Failed: $e', isError: true);
    }
  }
}

void showToastIfMounted(
  BuildContext context,
  WidgetRef ref,
  String message, {
  bool isError = false,
}) {
  if (!context.mounted) return;
  ref.read(toastProvider.notifier).show(message, isError: isError);
}

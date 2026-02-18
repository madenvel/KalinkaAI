import 'package:flutter_riverpod/flutter_riverpod.dart';

/// State for multi-select mode in search results.
class SelectionState {
  final bool isActive;
  final Set<String> selectedIds;

  const SelectionState({this.isActive = false, this.selectedIds = const {}});

  int get count => selectedIds.length;

  SelectionState copyWith({bool? isActive, Set<String>? selectedIds}) {
    return SelectionState(
      isActive: isActive ?? this.isActive,
      selectedIds: selectedIds ?? this.selectedIds,
    );
  }
}

class SelectionStateNotifier extends Notifier<SelectionState> {
  @override
  SelectionState build() {
    return const SelectionState();
  }

  void enterSelectionMode(String id) {
    state = SelectionState(isActive: true, selectedIds: {id});
  }

  void toggle(String id) {
    if (!state.isActive) {
      enterSelectionMode(id);
      return;
    }
    final ids = {...state.selectedIds};
    if (ids.contains(id)) {
      ids.remove(id);
      if (ids.isEmpty) {
        state = const SelectionState();
        return;
      }
    } else {
      ids.add(id);
    }
    state = state.copyWith(selectedIds: ids);
  }

  void selectAll(Iterable<String> ids) {
    state = state.copyWith(selectedIds: {...state.selectedIds, ...ids});
  }

  void exitSelectionMode() {
    state = const SelectionState();
  }
}

final selectionStateProvider =
    NotifierProvider<SelectionStateNotifier, SelectionState>(
      SelectionStateNotifier.new,
    );

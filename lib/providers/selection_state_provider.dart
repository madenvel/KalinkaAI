import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'browse_detail_provider.dart';

/// State for multi-select mode in search results.
class SelectionState {
  final bool isActive;
  final Set<String> selectedIds;
  final Set<String> selectedContainerIds;
  final Map<String, Set<String>> containerExclusions;

  const SelectionState({
    this.isActive = false,
    this.selectedIds = const {},
    this.selectedContainerIds = const {},
    this.containerExclusions = const {},
  });

  int get count => selectedIds.length + selectedContainerIds.length;

  bool isContainerSelected(String id) => selectedContainerIds.contains(id);

  bool isContainerPartial(String id) =>
      selectedContainerIds.contains(id) &&
      (containerExclusions[id]?.isNotEmpty ?? false);

  bool isTrackInContainerSelected(String containerId, String trackId) =>
      selectedContainerIds.contains(containerId) &&
      !(containerExclusions[containerId]?.contains(trackId) ?? false);

  SelectionState copyWith({
    bool? isActive,
    Set<String>? selectedIds,
    Set<String>? selectedContainerIds,
    Map<String, Set<String>>? containerExclusions,
  }) {
    return SelectionState(
      isActive: isActive ?? this.isActive,
      selectedIds: selectedIds ?? this.selectedIds,
      selectedContainerIds: selectedContainerIds ?? this.selectedContainerIds,
      containerExclusions: containerExclusions ?? this.containerExclusions,
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
      if (ids.isEmpty && state.selectedContainerIds.isEmpty) {
        state = const SelectionState();
        return;
      }
    } else {
      ids.add(id);
    }
    state = state.copyWith(selectedIds: ids);
  }

  void toggleContainer(String containerId) {
    if (!state.isActive) {
      state = SelectionState(
        isActive: true,
        selectedContainerIds: {containerId},
      );
      return;
    }
    final containers = {...state.selectedContainerIds};
    final exclusions = Map<String, Set<String>>.from(state.containerExclusions);
    if (containers.contains(containerId)) {
      containers.remove(containerId);
      exclusions.remove(containerId);
      if (containers.isEmpty && state.selectedIds.isEmpty) {
        state = const SelectionState();
        return;
      }
    } else {
      containers.add(containerId);
    }
    state = state.copyWith(
      selectedContainerIds: containers,
      containerExclusions: exclusions,
    );
  }

  void toggleTrackInContainer(String containerId, String trackId) {
    if (!state.selectedContainerIds.contains(containerId)) return;
    final exclusions = Map<String, Set<String>>.from(state.containerExclusions);
    final trackExcl = {...(exclusions[containerId] ?? <String>{})};
    if (trackExcl.contains(trackId)) {
      trackExcl.remove(trackId);
    } else {
      trackExcl.add(trackId);
    }
    
    // Check if all tracks are now excluded by comparing to browse data
    bool shouldDeselect = false;
    if (trackExcl.isNotEmpty) {
      final browseData = ref.read(browseDetailProvider(containerId));
      final items = browseData.value?.items ?? [];
      final trackItems = items.where((item) => item.track != null).toList();
      // If all track items are excluded, deselect the container
      shouldDeselect = trackExcl.length == trackItems.length &&
          trackItems.every((item) => trackExcl.contains(item.id));
    }
    
    if (shouldDeselect) {
      // All tracks excluded - deselect the container
      final containers = {...state.selectedContainerIds};
      containers.remove(containerId);
      exclusions.remove(containerId);
      if (containers.isEmpty && state.selectedIds.isEmpty) {
        state = const SelectionState();
        return;
      }
      state = state.copyWith(
        selectedContainerIds: containers,
        containerExclusions: exclusions,
      );
    } else {
      if (trackExcl.isEmpty) {
        exclusions.remove(containerId);
      } else {
        exclusions[containerId] = trackExcl;
      }
      state = state.copyWith(containerExclusions: exclusions);
    }
  }

  void selectAll(Iterable<String> ids) {
    state = state.copyWith(selectedIds: {...state.selectedIds, ...ids});
  }

  void exitSelectionMode() {
    state = const SelectionState();
  }

  List<String> resolveIdsForApi() {
    final ids = <String>{...state.selectedIds};
    for (final containerId in state.selectedContainerIds) {
      final exclusions = state.containerExclusions[containerId];
      if (exclusions == null || exclusions.isEmpty) {
        ids.add(containerId);
      } else {
        final browseData = ref.read(browseDetailProvider(containerId));
        final items = browseData.value?.items ?? [];
        for (final item in items) {
          if (!exclusions.contains(item.id)) {
            ids.add(item.id);
          }
        }
      }
    }
    return ids.toList();
  }
}

final selectionStateProvider =
    NotifierProvider<SelectionStateNotifier, SelectionState>(
      SelectionStateNotifier.new,
    );

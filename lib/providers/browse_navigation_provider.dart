import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data_model/data_model.dart';
import '../providers/kalinka_player_api_provider.dart';

/// A single level in the browse navigation stack.
class BrowseLevel {
  final String id;
  final String label;
  final List<BrowseItem> items;
  final int totalItems;

  const BrowseLevel({
    required this.id,
    required this.label,
    required this.items,
    required this.totalItems,
  });
}

/// State for inline browse navigation within a search result section.
class BrowseNavigationState {
  final List<BrowseLevel> stack;
  final bool isLoading;
  final bool isExpanded;

  const BrowseNavigationState({
    this.stack = const [],
    this.isLoading = false,
    this.isExpanded = false,
  });

  BrowseLevel? get current => stack.isNotEmpty ? stack.last : null;
  List<String> get pathSegments => stack.map((l) => l.label).toList();

  BrowseNavigationState copyWith({
    List<BrowseLevel>? stack,
    bool? isLoading,
    bool? isExpanded,
  }) {
    return BrowseNavigationState(
      stack: stack ?? this.stack,
      isLoading: isLoading ?? this.isLoading,
      isExpanded: isExpanded ?? this.isExpanded,
    );
  }
}

/// Manages browse navigation for a specific section (keyed by section ID).
class BrowseNavigationNotifier extends Notifier<BrowseNavigationState> {
  @override
  BrowseNavigationState build() {
    return const BrowseNavigationState();
  }

  void expand() {
    state = state.copyWith(isExpanded: true);
  }

  void collapse() {
    state = state.copyWith(isExpanded: false, stack: []);
  }

  Future<void> drillDown(BrowseItem item) async {
    if (state.stack.length >= 3) return;

    state = state.copyWith(isLoading: true);
    try {
      final api = ref.read(kalinkaProxyProvider);
      final result = await api.browse(item.id);
      final label = item.name ?? item.id;
      final newStack = [
        ...state.stack,
        BrowseLevel(
          id: item.id,
          label: label,
          items: result.items,
          totalItems: result.total,
        ),
      ];
      state = state.copyWith(stack: newStack, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> navigateToLevel(int index) async {
    if (index < 0) {
      // Navigate to root
      state = state.copyWith(stack: []);
      return;
    }
    if (index >= state.stack.length - 1) return;

    // Navigate back to a specific level and reload its data
    final target = state.stack[index];
    state = state.copyWith(isLoading: true);
    try {
      final api = ref.read(kalinkaProxyProvider);
      final result = await api.browse(target.id);
      final newStack = state.stack.sublist(0, index + 1);
      newStack[index] = BrowseLevel(
        id: target.id,
        label: target.label,
        items: result.items,
        totalItems: result.total,
      );
      state = state.copyWith(stack: newStack, isLoading: false);
    } catch (e) {
      // Fall back to just trimming the stack
      state = state.copyWith(
        stack: state.stack.sublist(0, index + 1),
        isLoading: false,
      );
    }
  }

  Future<void> loadMore(String browseId) async {
    final current = state.current;
    if (current == null || state.isLoading) return;

    state = state.copyWith(isLoading: true);
    try {
      final api = ref.read(kalinkaProxyProvider);
      final result = await api.browse(
        browseId,
        offset: current.items.length,
        limit: 10,
      );
      final updatedLevel = BrowseLevel(
        id: current.id,
        label: current.label,
        items: [...current.items, ...result.items],
        totalItems: result.total,
      );
      final newStack = [...state.stack];
      newStack[newStack.length - 1] = updatedLevel;
      state = state.copyWith(stack: newStack, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }
}

final browseNavigationProvider =
    NotifierProvider.family<
      BrowseNavigationNotifier,
      BrowseNavigationState,
      String
    >((_) => BrowseNavigationNotifier());

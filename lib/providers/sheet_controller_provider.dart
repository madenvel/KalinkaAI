import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Sheet state for tracking collapse/peek/expanded
enum SheetState { collapsed, peek, expanded }

/// Controller provider for DraggableScrollableSheet
final sheetControllerProvider = Provider<DraggableScrollableController>((ref) {
  final controller = DraggableScrollableController();
  ref.onDispose(() => controller.dispose());
  return controller;
});

/// Current sheet state based on size
final sheetStateProvider = NotifierProvider<SheetStateNotifier, SheetState>(
  SheetStateNotifier.new,
);

class SheetStateNotifier extends Notifier<SheetState> {
  @override
  SheetState build() => SheetState.collapsed;

  void update(SheetState newState) {
    state = newState;
  }
}

/// Sheet size constants
class SheetSizes {
  static const double collapsed = 0.08; // Just peeking out above playbar
  static const double peek = 0.15; // Small preview
  static const double expanded = 0.75; // Full queue

  static const double collapsedThreshold = 0.10;
  static const double peekThreshold = 0.30;
}

/// Helper methods to control sheet
extension SheetControllerExtension on DraggableScrollableController {
  void snapToCollapsed() {
    animateTo(
      SheetSizes.collapsed,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void snapToPeek() {
    animateTo(
      SheetSizes.peek,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void snapToExpanded() {
    animateTo(
      SheetSizes.expanded,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }
}

/// Determine sheet state from size
SheetState getSheetStateFromSize(double size) {
  if (size < SheetSizes.collapsedThreshold) {
    return SheetState.collapsed;
  } else if (size < SheetSizes.peekThreshold) {
    return SheetState.peek;
  } else {
    return SheetState.expanded;
  }
}

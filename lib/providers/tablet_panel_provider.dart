import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which panel is active on the tablet right side.
enum TabletPanel { search, queue }

class TabletPanelNotifier extends Notifier<TabletPanel> {
  @override
  TabletPanel build() => TabletPanel.search;

  void showSearch() => state = TabletPanel.search;
  void showQueue() => state = TabletPanel.queue;
  void toggle() {
    state = state == TabletPanel.search
        ? TabletPanel.queue
        : TabletPanel.search;
  }
}

final tabletPanelProvider = NotifierProvider<TabletPanelNotifier, TabletPanel>(
  TabletPanelNotifier.new,
);

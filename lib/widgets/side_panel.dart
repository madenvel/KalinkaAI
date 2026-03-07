import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/tablet_panel_provider.dart';
import '../theme/app_theme.dart';
import 'completion_strip.dart';
import 'kalinka_search_bar.dart';
import 'search_results_feed.dart';
import 'queue_zone.dart';

/// Tabbed side panel for tablet layout.
/// Shows Search or Queue content, inline (no overlays).
class SidePanel extends ConsumerWidget {
  const SidePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activePanel = ref.watch(tabletPanelProvider);

    return Column(
      children: [
        // Tab selector
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: Row(
            children: [
              _buildTab(
                ref,
                'Search',
                Icons.search,
                activePanel == TabletPanel.search,
                () => ref.read(tabletPanelProvider.notifier).showSearch(),
              ),
              const SizedBox(width: 8),
              _buildTab(
                ref,
                'Queue',
                Icons.queue_music,
                activePanel == TabletPanel.queue,
                () => ref.read(tabletPanelProvider.notifier).showQueue(),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Content — IndexedStack keeps both panels mounted so queue scroll
        // position is preserved between tab switches. TickerMode stops
        // BerryPulse (and any other tickers) in the inactive panel.
        Expanded(
          child: IndexedStack(
            index: activePanel == TabletPanel.queue ? 0 : 1,
            children: [
              TickerMode(
                enabled: activePanel == TabletPanel.queue,
                child: const RepaintBoundary(
                  child: QueueZone(bottomPadding: 0, isTablet: true),
                ),
              ),
              RepaintBoundary(child: _buildSearchPanel()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTab(
    WidgetRef ref,
    String label,
    IconData icon,
    bool isActive,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isActive ? KalinkaColors.accent : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isActive
                    ? KalinkaColors.accent
                    : KalinkaColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.ibmPlexMono(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  color: isActive
                      ? KalinkaColors.accent
                      : KalinkaColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchPanel() {
    return const Column(
      children: [
        // Shared search bar (always expanded in tablet mode)
        Padding(
          padding: EdgeInsets.all(8),
          child: KalinkaSearchBar(alwaysExpanded: true),
        ),
        // Pinned completion strip
        CompletionStrip(),
        // Shared search results feed (no bottom padding needed in tablet)
        Expanded(child: SearchResultsFeed(bottomPadding: 0)),
      ],
    );
  }
}

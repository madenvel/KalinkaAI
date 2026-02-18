import 'package:flutter/material.dart';
import '../widgets/album_art_background.dart';
import '../widgets/playbar.dart';
import '../widgets/expandable_queue.dart';
import '../widgets/search_bar.dart';
import '../widgets/side_panel.dart';

class MusicPlayerScreen extends StatelessWidget {
  const MusicPlayerScreen({super.key});

  static const _tabletBreakpoint = 900.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= _tabletBreakpoint) {
            return _buildTabletLayout(context);
          }
          return _buildPhoneLayout(context);
        },
      ),
    );
  }

  Widget _buildPhoneLayout(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      children: [
        // Main content layer: background + playbar
        Column(
          children: [
            // Main content area
            const Expanded(child: AlbumArtBackground()),
            // Playbar at bottom with color extending beyond safe area
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: SafeArea(top: false, child: const Playbar()),
            ),
          ],
        ),
        // Search bar overlay: positioned at top
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: ExpandableSearchBar(),
        ),
        // Queue overlay: slides up from bottom, covers everything including playbar
        const Positioned.fill(child: ExpandableQueue()),
      ],
    );
  }

  Widget _buildTabletLayout(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        // Left panel: album art + playbar (always visible)
        Expanded(
          flex: 1,
          child: Column(
            children: [
              const Expanded(child: AlbumArtBackground()),
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                child: SafeArea(top: false, child: const Playbar()),
              ),
            ],
          ),
        ),
        // Divider
        VerticalDivider(width: 1, thickness: 1),
        // Right panel: tabbed search/queue
        Expanded(
          flex: 1,
          child: SafeArea(child: const SidePanel()),
        ),
      ],
    );
  }
}

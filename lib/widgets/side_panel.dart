import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/tablet_panel_provider.dart';
import '../providers/search_state_provider.dart';
import '../theme/app_theme.dart';
import 'search_content.dart';
import 'queue_zone.dart';

/// Tabbed side panel for tablet layout.
/// Shows Search or Queue content, inline (no overlays).
class SidePanel extends ConsumerStatefulWidget {
  const SidePanel({super.key});

  @override
  ConsumerState<SidePanel> createState() => _SidePanelState();
}

class _SidePanelState extends ConsumerState<SidePanel> {
  late TextEditingController _textController;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activePanel = ref.watch(tabletPanelProvider);
    final searchState = ref.watch(searchStateProvider);

    // Sync text controller
    if (_textController.text != searchState.query) {
      _textController.text = searchState.query;
    }

    return Column(
      children: [
        // Tab selector
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: Row(
            children: [
              _buildTab(
                'Search',
                Icons.search,
                activePanel == TabletPanel.search,
                () => ref.read(tabletPanelProvider.notifier).showSearch(),
              ),
              const SizedBox(width: 8),
              _buildTab(
                'Queue',
                Icons.queue_music,
                activePanel == TabletPanel.queue,
                () => ref.read(tabletPanelProvider.notifier).showQueue(),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Content
        Expanded(
          child: activePanel == TabletPanel.search
              ? _buildSearchPanel(searchState)
              : const QueueZone(bottomPadding: 0),
        ),
      ],
    );
  }

  Widget _buildTab(
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

  Widget _buildSearchPanel(SearchState searchState) {
    return Column(
      children: [
        // Inline search bar
        Padding(
          padding: const EdgeInsets.all(8),
          child: Container(
            decoration: BoxDecoration(
              color: KalinkaColors.inputSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: KalinkaColors.accent.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            child: TextField(
              controller: _textController,
              focusNode: _focusNode,
              style: GoogleFonts.ibmPlexMono(
                fontSize: 13,
                color: KalinkaColors.textPrimary,
              ),
              onChanged: (value) {
                ref.read(searchStateProvider.notifier).setQuery(value);
              },
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  ref.read(searchStateProvider.notifier).performSearch();
                }
              },
              decoration: InputDecoration(
                hintText: 'Search music\u2026',
                hintStyle: KalinkaTextStyles.searchPlaceholder,
                prefixIcon: const Icon(
                  Icons.search,
                  color: KalinkaColors.accent,
                  size: 20,
                ),
                suffixIcon: searchState.query.isNotEmpty
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.clear,
                              size: 18,
                              color: KalinkaColors.textSecondary,
                            ),
                            onPressed: () {
                              _textController.clear();
                              ref
                                  .read(searchStateProvider.notifier)
                                  .clearSearch();
                            },
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.search,
                              size: 18,
                              color: KalinkaColors.accent,
                            ),
                            onPressed: () {
                              ref
                                  .read(searchStateProvider.notifier)
                                  .performSearch();
                            },
                          ),
                        ],
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
          ),
        ),
        // Search content
        const Expanded(child: SearchContent()),
      ],
    );
  }
}

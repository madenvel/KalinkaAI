import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/search_state_provider.dart';
import '../theme/app_theme.dart';
import 'search_results_feed.dart';

/// AI search sheet overlay — adaptive bottom sheet with 3-detent system.
/// Peek (~47%), Comfortable (65%), Full (100%).
/// Uses DraggableScrollableSheet for natural expand-then-scroll behaviour.
class AiSearchSheet extends ConsumerStatefulWidget {
  final AnimationController animationController;
  final VoidCallback onClose;

  const AiSearchSheet({
    super.key,
    required this.animationController,
    required this.onClose,
  });

  @override
  ConsumerState<AiSearchSheet> createState() => _AiSearchSheetState();
}

class _AiSearchSheetState extends ConsumerState<AiSearchSheet>
    with WidgetsBindingObserver {
  late TextEditingController _textController;
  late FocusNode _searchFocusNode;
  late DraggableScrollableController _sheetController;
  bool _keyboardVisible = false;
  bool _dismissed = false;

  static const double _peekFraction = 0.47;
  static const double _comfortableFraction = 0.65;
  static const double _fullFraction = 1.0;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _searchFocusNode = FocusNode();
    _sheetController = DraggableScrollableController();
    WidgetsBinding.instance.addObserver(this);

    _sheetController.addListener(_onSheetSizeChanged);

    // Sync text controller with existing query
    final currentQuery = ref.read(searchStateProvider).query;
    if (currentQuery.isNotEmpty) {
      _textController.text = currentQuery;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sheetController.removeListener(_onSheetSizeChanged);
    _sheetController.dispose();
    _textController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final bottomInset = view.viewInsets.bottom / view.devicePixelRatio;
    final isKeyboard = bottomInset > 100;

    if (isKeyboard != _keyboardVisible) {
      _keyboardVisible = isKeyboard;
      if (!_sheetController.isAttached) return;

      if (isKeyboard) {
        _sheetController.animateTo(
          _fullFraction,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      } else {
        _sheetController.animateTo(
          _comfortableFraction,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
        );
      }
    }
  }

  void _onSheetSizeChanged() {
    if (!_sheetController.isAttached) return;
    final size = _sheetController.size;
    if (size <= 0.05 && !_dismissed) {
      _dismissed = true;
      widget.onClose();
    }
  }

  void _performSearch() {
    final query = _textController.text.trim();
    if (query.isEmpty) return;
    ref.read(searchStateProvider.notifier).setQuery(query);
    ref.read(searchStateProvider.notifier).performSearch();
    _searchFocusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final slideAnimation = CurvedAnimation(
      parent: widget.animationController,
      curve: Curves.easeOut,
    );

    final fadeAnimation = CurvedAnimation(
      parent: widget.animationController,
      curve: Curves.easeOut,
    );

    return Stack(
      children: [
        // Blur + darkened backdrop (no tap dismiss)
        FadeTransition(
          opacity: fadeAnimation,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(color: Colors.black.withValues(alpha: 0.5)),
          ),
        ),
        // Sheet
        SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(slideAnimation),
          child: _buildDraggableSheet(context),
        ),
      ],
    );
  }

  Widget _buildDraggableSheet(BuildContext context) {
    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: _peekFraction,
      minChildSize: 0.0,
      maxChildSize: _fullFraction,
      snap: true,
      snapSizes: const [_peekFraction, _comfortableFraction],
      snapAnimationDuration: const Duration(milliseconds: 200),
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: KalinkaColors.miniPlayerSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              // Sticky header
              _buildStickyHeader(),
              // Scrollable content
              Expanded(
                child: SearchResultsFeed(
                  scrollController: scrollController,
                  sheetController: _sheetController,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStickyHeader() {
    final searchState = ref.watch(searchStateProvider);

    return Container(
      decoration: BoxDecoration(
        color: KalinkaColors.headerSurface,
        border: const Border(
          bottom: BorderSide(color: KalinkaColors.borderElevated, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          // Drag handle: 36x4px, 2px radius
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: KalinkaColors.pillSurface,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Search input
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: KalinkaColors.inputSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: KalinkaColors.accent, width: 1.5),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.search,
                    size: 20,
                    color: KalinkaColors.accent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      focusNode: _searchFocusNode,
                      style: GoogleFonts.ibmPlexMono(
                        fontSize: 13,
                        color: KalinkaColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search music\u2026',
                        hintStyle: KalinkaTextStyles.searchPlaceholder,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                      ),
                      onSubmitted: (_) => _performSearch(),
                      onChanged: (value) {
                        ref.read(searchStateProvider.notifier).setQuery(value);
                      },
                    ),
                  ),
                  // Interaction mode toggle
                  GestureDetector(
                    onTap: () {
                      ref
                          .read(searchStateProvider.notifier)
                          .cycleInteractionMode();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _buildModeIndicator(searchState.interactionMode),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Mic button
                  GestureDetector(
                    onTap: () {},
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(9),
                        color: KalinkaColors.accent.withValues(alpha: 0.1),
                      ),
                      child: const Icon(
                        Icons.mic_none,
                        size: 18,
                        color: KalinkaColors.accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Result count hint
          if (searchState.searchResults != null &&
              searchState.totalResultCount > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${searchState.totalResultCount} RESULTS \u00B7 RANKED BY RELEVANCE',
                  style: KalinkaTextStyles.resultCountHint,
                ),
              ),
            )
          else
            const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildModeIndicator(InteractionMode mode) {
    final isContextMenu = mode == InteractionMode.contextMenu;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: KalinkaColors.pillSurface,
      ),
      child: Icon(
        isContextMenu ? Icons.menu : Icons.bolt,
        size: 14,
        color: isContextMenu ? KalinkaColors.textSecondary : KalinkaColors.gold,
      ),
    );
  }
}

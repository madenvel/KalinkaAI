import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/search_state_provider.dart';
import '../theme/app_theme.dart';

/// Shared search bar used in both phone (HeaderZone) and tablet (SidePanel).
///
/// When [alwaysExpanded] is false (phone), the bar starts as a pill with
/// placeholder text and expands into a real TextField on tap.
/// When [alwaysExpanded] is true (tablet), the TextField is always visible.
///
/// [onCancel] — when non-null, a Cancel button is shown (phone layout).
/// [onActivate] — called when the search bar transitions from pill to active
/// state (phone layout only).
class KalinkaSearchBar extends ConsumerStatefulWidget {
  final bool alwaysExpanded;
  final VoidCallback? onCancel;
  final VoidCallback? onActivate;

  const KalinkaSearchBar({
    super.key,
    this.alwaysExpanded = false,
    this.onCancel,
    this.onActivate,
  });

  @override
  ConsumerState<KalinkaSearchBar> createState() => _KalinkaSearchBarState();
}

class _KalinkaSearchBarState extends ConsumerState<KalinkaSearchBar>
    with TickerProviderStateMixin {
  late TextEditingController _textController;
  late FocusNode _searchFocusNode;
  late AnimationController _cancelAnimController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _clearMicController;
  bool _isActive = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _searchFocusNode = FocusNode();
    _cancelAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 0.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _clearMicController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );

    _searchFocusNode.addListener(_onFocusChange);

    if (widget.alwaysExpanded) {
      _isActive = true;
    }

    final currentQuery = ref.read(searchStateProvider).query;
    if (currentQuery.isNotEmpty) {
      _textController.text = currentQuery;
      _clearMicController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _searchFocusNode.removeListener(_onFocusChange);
    _textController.dispose();
    _searchFocusNode.dispose();
    _cancelAnimController.dispose();
    _pulseController.dispose();
    _clearMicController.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_searchFocusNode.hasFocus && !_isActive) {
      _activateSearch();
    }
  }

  void _activateSearch() {
    setState(() => _isActive = true);
    if (!widget.alwaysExpanded) {
      _cancelAnimController.forward();
    }
    widget.onActivate?.call();
  }

  void _onQueryChanged(String value) {
    ref.read(searchStateProvider.notifier).setQuery(value);
    // Animate clear/mic icon transition
    if (value.isNotEmpty) {
      _clearMicController.forward();
    } else {
      _clearMicController.reverse();
    }
  }

  void _onSubmitted(String _) {
    final query = _textController.text.trim();
    if (query.isEmpty) return;
    ref.read(searchStateProvider.notifier).setQuery(query);
    ref.read(searchStateProvider.notifier).performSearch();
    _searchFocusNode.unfocus();
  }

  void _onClearTapped() {
    _textController.clear();
    _clearMicController.reverse();
    ref.read(searchStateProvider.notifier).clearQueryMidSession();
    // Keep focus — do NOT unfocus or dismiss keyboard
  }

  void cancelSearch() {
    _cancelAnimController.reverse();
    _searchFocusNode.unfocus();
    _textController.clear();
    _clearMicController.value = 0.0;
    setState(() => _isActive = false);
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchStateProvider);

    // Sync text field if query changed externally (e.g. history tap).
    if (_isActive &&
        _textController.text != searchState.query &&
        !_searchFocusNode.hasFocus) {
      _textController.text = searchState.query;
      if (searchState.query.isNotEmpty) {
        _clearMicController.value = 1.0;
      } else {
        _clearMicController.value = 0.0;
      }
    }

    return Row(
      children: [
        Expanded(child: _buildSearchBar(searchState)),
        if (widget.onCancel != null) _buildCancelButton(),
      ],
    );
  }

  Widget _buildSearchBar(SearchState searchState) {
    final borderColor = _isActive
        ? KalinkaColors.accent.withValues(alpha: 0.55)
        : KalinkaColors.accent;

    return GestureDetector(
      onTap: () {
        if (!_isActive) {
          _activateSearch();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _searchFocusNode.requestFocus();
          });
        }
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 42,
        decoration: BoxDecoration(
          color: KalinkaColors.inputSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: _isActive
              ? [
                  BoxShadow(
                    color: KalinkaColors.accent.withValues(alpha: 0.12),
                    blurRadius: 4,
                    spreadRadius: 0,
                  ),
                ]
              : [],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            // Search icon
            const Icon(Icons.search, size: 18, color: KalinkaColors.accent),
            const SizedBox(width: 10),
            // TextField or placeholder
            Expanded(
              child: _isActive
                  ? TextField(
                      controller: _textController,
                      focusNode: _searchFocusNode,
                      style: KalinkaTextStyles.searchBarInput,
                      cursorColor: KalinkaColors.accent,
                      decoration: InputDecoration(
                        hintText: 'Search music\u2026',
                        hintStyle: KalinkaTextStyles.searchPlaceholder,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                        isDense: true,
                      ),
                      onChanged: _onQueryChanged,
                      onSubmitted: _onSubmitted,
                    )
                  : Text(
                      'moody electronic, late night\u2026',
                      style: KalinkaTextStyles.searchPlaceholder,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
            ),
            const SizedBox(width: 8),
            // Mode indicator (only when active)
            if (_isActive) ...[
              _buildModeIndicator(
                ref.watch(searchStateProvider).interactionMode,
              ),
              const SizedBox(width: 4),
            ],
            // Mic / Clear (×) button — animated crossfade
            if (_isActive) _buildMicClearButton(),
            if (!_isActive) ...[
              // AI badge with pulsing dot (only when inactive)
              _buildAiBadge(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMicClearButton() {
    return AnimatedBuilder(
      animation: _clearMicController,
      builder: (context, _) {
        final progress = CurvedAnimation(
          parent: _clearMicController,
          curve: Curves.easeOut,
        ).value;
        return SizedBox(
          width: 28,
          height: 28,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Mic icon — visible when query is empty (progress near 0)
              Opacity(
                opacity: 1.0 - progress,
                child: Transform.scale(
                  scale: 0.85 + 0.15 * (1.0 - progress),
                  child: GestureDetector(
                    onTap: () {
                      // Mic placeholder — no-op for now
                    },
                    child: const Icon(
                      Icons.mic_none_rounded,
                      size: 20,
                      color: KalinkaColors.textSecondary,
                    ),
                  ),
                ),
              ),
              // Clear (×) icon — visible when query is non-empty (progress near 1)
              Opacity(
                opacity: progress,
                child: Transform.scale(
                  scale: 0.85 + 0.15 * progress,
                  child: GestureDetector(
                    onTap: progress > 0.5 ? _onClearTapped : null,
                    child: const Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: KalinkaColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAiBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: KalinkaColors.accent.withValues(alpha: 0.12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('AI', style: KalinkaTextStyles.aiBadge),
          const SizedBox(width: 4),
          FadeTransition(
            opacity: _pulseAnimation,
            child: Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: KalinkaColors.accent,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCancelButton() {
    return AnimatedBuilder(
      animation: _cancelAnimController,
      builder: (context, child) {
        final progress = CurvedAnimation(
          parent: _cancelAnimController,
          curve: Curves.easeOut,
        ).value;
        return Transform.translate(
          offset: Offset(20 * (1 - progress), 0),
          child: Opacity(opacity: progress, child: child),
        );
      },
      child: GestureDetector(
        onTap: () {
          cancelSearch();
          widget.onCancel?.call();
        },
        child: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Text('Cancel', style: KalinkaTextStyles.cancelButton),
        ),
      ),
    );
  }

  Widget _buildModeIndicator(InteractionMode mode) {
    final isContextMenu = mode == InteractionMode.contextMenu;
    return GestureDetector(
      onTap: () {
        ref.read(searchStateProvider.notifier).cycleInteractionMode();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: KalinkaColors.pillSurface,
        ),
        child: Icon(
          isContextMenu ? Icons.menu : Icons.bolt,
          size: 14,
          color: isContextMenu
              ? KalinkaColors.textSecondary
              : KalinkaColors.gold,
        ),
      ),
    );
  }
}

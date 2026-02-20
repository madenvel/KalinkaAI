import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/search_state_provider.dart';
import '../theme/app_theme.dart';

/// Header zone with status bar safe area and persistent search bar.
/// The search bar has two states: inactive (pill with placeholder) and
/// active (real TextField with Cancel button).
class HeaderZone extends ConsumerStatefulWidget {
  const HeaderZone({super.key});

  @override
  ConsumerState<HeaderZone> createState() => _HeaderZoneState();
}

class _HeaderZoneState extends ConsumerState<HeaderZone>
    with TickerProviderStateMixin {
  late TextEditingController _textController;
  late FocusNode _searchFocusNode;
  late AnimationController _cancelAnimController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
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

    _searchFocusNode.addListener(_onFocusChange);

    // Sync text controller with existing query
    final currentQuery = ref.read(searchStateProvider).query;
    if (currentQuery.isNotEmpty) {
      _textController.text = currentQuery;
    }
  }

  @override
  void dispose() {
    _searchFocusNode.removeListener(_onFocusChange);
    _textController.dispose();
    _searchFocusNode.dispose();
    _cancelAnimController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_searchFocusNode.hasFocus && !_isActive) {
      _activateSearch();
    }
  }

  void _activateSearch() {
    setState(() => _isActive = true);
    ref.read(searchStateProvider.notifier).activateSearch();
    _cancelAnimController.forward();
  }

  void _cancelSearch() {
    _cancelAnimController.reverse();
    _searchFocusNode.unfocus();
    _textController.clear();
    ref.read(searchStateProvider.notifier).deactivateSearch();
    setState(() => _isActive = false);
  }

  void _onQueryChanged(String value) {
    ref.read(searchStateProvider.notifier).setQuery(value);
  }

  void _onSubmitted(String _) {
    final query = _textController.text.trim();
    if (query.isEmpty) return;
    ref.read(searchStateProvider.notifier).setQuery(query);
    ref.read(searchStateProvider.notifier).performSearch();
    _searchFocusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchStateProvider);

    // Sync text field if query changed externally (e.g. history tap)
    if (_isActive &&
        _textController.text != searchState.query &&
        !_searchFocusNode.hasFocus) {
      _textController.text = searchState.query;
    }

    return Container(
      decoration: const BoxDecoration(
        color: KalinkaColors.headerSurface,
        border: Border(
          bottom: BorderSide(color: KalinkaColors.borderElevated, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            offset: Offset(0, 2),
            blurRadius: 6,
            color: Color(0x40000000),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(child: _buildSearchBar()),
              // Cancel button (animated slide+fade)
              _buildCancelButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    final borderColor = _isActive
        ? KalinkaColors.accent.withValues(alpha: 0.55)
        : KalinkaColors.accent;

    return GestureDetector(
      onTap: () {
        if (!_isActive) {
          _activateSearch();
          // Request focus after the TextField is built on next frame
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
            // AI badge with pulsing dot
            Container(
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
            ),
          ],
        ),
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
        onTap: _cancelSearch,
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

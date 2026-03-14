import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/connection_state_provider.dart';
import '../providers/search_state_provider.dart';
import '../theme/app_theme.dart';
import '../utils/haptics.dart';

/// Shared search bar used in both phone (HeaderZone) and tablet (SidePanel).
///
/// The bar always shows its full layout — search icon, text field, conditional
/// clear button, AI mode pill toggle, and mic icon. There is no pill/collapsed
/// state. The border brightens on focus and a subtle glow appears.
///
/// [alwaysExpanded] — when true (tablet), the TextField auto-activates search
/// on mount. When false (phone), search activates on first tap.
/// [onActivate] — called when the bar transitions from ambient to focused.
class KalinkaSearchBar extends ConsumerStatefulWidget {
  final bool alwaysExpanded;
  final VoidCallback? onActivate;
  final VoidCallback? onLeadingAction;
  final bool showBackChevron;
  final bool fullBleedMode;
  final double height;
  final EdgeInsetsGeometry? contentPadding;

  const KalinkaSearchBar({
    super.key,
    this.alwaysExpanded = false,
    this.onActivate,
    this.onLeadingAction,
    this.showBackChevron = false,
    this.fullBleedMode = false,
    this.height = 36,
    this.contentPadding,
  });

  @override
  ConsumerState<KalinkaSearchBar> createState() => KalinkaSearchBarState();
}

class KalinkaSearchBarState extends ConsumerState<KalinkaSearchBar>
    with TickerProviderStateMixin {
  static const _searchOpenFocusDelay = Duration(milliseconds: 240);

  late TextEditingController _textController;
  late FocusNode _searchFocusNode;
  late AnimationController _clearButtonController;
  late AnimationController _borderController;
  late Animation<double> _borderAnimation;

  bool _isActive = false;
  bool _isAiModeActive = true;

  // State 3 → State 2 (editing) tracking
  String _committedQuery = '';
  bool _enteredFocusFromResults = false;

  bool get isActive => _isActive;
  bool get isEditingFromResults => _enteredFocusFromResults;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _searchFocusNode = FocusNode();

    _clearButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      reverseDuration: const Duration(milliseconds: 100),
    );

    _borderController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _borderAnimation = CurvedAnimation(
      parent: _borderController,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeOut,
    );

    _searchFocusNode.addListener(_onFocusChange);

    if (widget.alwaysExpanded) {
      _isActive = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final phase = ref.read(searchStateProvider).searchPhase;
        if (phase == SearchPhase.inactive) {
          ref.read(searchStateProvider.notifier).activateSearch();
        }
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final phase = ref.read(searchStateProvider).searchPhase;
        if (phase == SearchPhase.activated) {
          ref.read(searchStateProvider.notifier).deactivateSearch();
        }
      });
    }

    final currentQuery = ref.read(searchStateProvider).query;
    if (currentQuery.isNotEmpty) {
      _textController.text = currentQuery;
      _clearButtonController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _searchFocusNode.removeListener(_onFocusChange);
    _textController.dispose();
    _searchFocusNode.dispose();
    _clearButtonController.dispose();
    _borderController.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_searchFocusNode.hasFocus) {
      if (!_isActive) {
        _activateSearch();
      } else {
        // Already active (e.g. tapping bar while in results state)
        final phase = ref.read(searchStateProvider).searchPhase;
        if (phase == SearchPhase.results && !_enteredFocusFromResults) {
          _enteredFocusFromResults = true;
          _committedQuery = _textController.text;
        }
      }
      _borderController.animateTo(
        1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    } else {
      _borderController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    }
  }

  void _activateSearch() {
    final phase = ref.read(searchStateProvider).searchPhase;
    if (phase == SearchPhase.results) {
      _enteredFocusFromResults = true;
      _committedQuery = _textController.text;
    } else {
      _enteredFocusFromResults = false;
    }
    setState(() => _isActive = true);
    widget.onActivate?.call();
  }

  void activateFromExternal({bool requestFocus = true}) {
    if (!_isActive) {
      final phase = ref.read(searchStateProvider).searchPhase;
      if (phase == SearchPhase.results) {
        _enteredFocusFromResults = true;
        _committedQuery = _textController.text;
      } else {
        _enteredFocusFromResults = false;
      }
      setState(() => _isActive = true);
    }

    if (!requestFocus) return;

    Future.delayed(_searchOpenFocusDelay, () {
      if (!mounted || !_isActive) return;
      _searchFocusNode.requestFocus();
    });
  }

  void _onQueryChanged(String value) {
    ref.read(searchStateProvider.notifier).setQuery(value);
    if (value.isNotEmpty) {
      _clearButtonController.forward();
    } else {
      _clearButtonController.reverse();
    }
  }

  void _onSubmitted(String _) {
    final query = _textController.text.trim();
    if (query.isEmpty) return;
    _committedQuery = query;
    _enteredFocusFromResults = false;
    ref.read(searchStateProvider.notifier).setQuery(query);
    ref.read(searchStateProvider.notifier).performSearch();
    _searchFocusNode.unfocus();
  }

  void _onClearTapped() {
    KalinkaHaptics.lightImpact();
    final phase = ref.read(searchStateProvider).searchPhase;
    if (phase == SearchPhase.results) {
      // State 3 ✕: clear query and return to ambient (State 1)
      _textController.clear();
      _clearButtonController.value = 0.0;
      _committedQuery = '';
      _enteredFocusFromResults = false;
      _searchFocusNode.unfocus();
      setState(() => _isActive = false);
      ref.read(searchStateProvider.notifier).deactivateSearch();
    } else {
      // State 2 ✕: clear text only, stay focused
      _textController.clear();
      _clearButtonController.reverse();
      ref.read(searchStateProvider.notifier).clearQueryMidSession();
    }
  }

  /// Called externally (back button / PopScope) to dismiss search.
  ///
  /// If the user was editing from results (State 3 → 2), restores the
  /// committed query and stays in results (State 3). Otherwise clears the
  /// bar so the caller can transition to ambient.
  void cancelSearch() {
    _searchFocusNode.unfocus();
    _borderController.animateTo(
      0.0,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );

    if (_enteredFocusFromResults) {
      // Restore committed query, stay in results
      _textController.text = _committedQuery;
      _enteredFocusFromResults = false;
      if (_committedQuery.isNotEmpty) {
        _clearButtonController.value = 1.0;
      } else {
        _clearButtonController.value = 0.0;
      }
      return;
    }

    // Full cancel — caller will call deactivateSearch()
    _textController.clear();
    _clearButtonController.value = 0.0;
    _committedQuery = '';
    setState(() => _isActive = false);
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchStateProvider);
    final connectionStatus = ref.watch(connectionStateProvider);
    final isDisconnected = connectionStatus == ConnectionStatus.none;

    // Sync text field if query changed externally (e.g. history tap).
    if (_isActive &&
        _textController.text != searchState.query &&
        !_searchFocusNode.hasFocus) {
      _textController.text = searchState.query;
      if (searchState.query.isNotEmpty) {
        _clearButtonController.value = 1.0;
      } else {
        _clearButtonController.value = 0.0;
      }
    }

    final bar = _buildSearchBar();

    if (isDisconnected) {
      return IgnorePointer(child: Opacity(opacity: 0.38, child: bar));
    }

    return bar;
  }

  Widget _buildSearchBar() {
    return GestureDetector(
      onTap: () {
        if (!_isActive) {
          KalinkaHaptics.lightImpact();
          _activateSearch();
          Future.delayed(_searchOpenFocusDelay, () {
            if (!mounted || !_isActive) return;
            _searchFocusNode.requestFocus();
          });
          return;
        }

        _searchFocusNode.requestFocus();
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _borderAnimation,
        builder: (context, child) {
          final t = _borderAnimation.value;
          final isFullBleed = widget.fullBleedMode;
          final borderColor = Color.lerp(
            KalinkaColors.accent.withValues(alpha: 0.38),
            KalinkaColors.accent.withValues(alpha: 0.62),
            t,
          )!;
          final hasShadow = t > 0 && !isFullBleed;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            height: widget.height,
            decoration: BoxDecoration(
              color: KalinkaColors.surfaceInput,
              borderRadius: isFullBleed
                  ? BorderRadius.zero
                  : BorderRadius.circular(14),
              border: isFullBleed
                  ? null
                  : Border.all(color: borderColor, width: 1.5),
              boxShadow: hasShadow
                  ? [
                      BoxShadow(
                        color: KalinkaColors.accent.withValues(alpha: 0.12 * t),
                        blurRadius: 6,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            padding:
                widget.contentPadding ??
                const EdgeInsets.symmetric(horizontal: 12),
            child: child,
          );
        },
        child: Row(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) {
                final scale = Tween<double>(
                  begin: 0.9,
                  end: 1.0,
                ).animate(animation);
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(scale: scale, child: child),
                );
              },
              child: widget.showBackChevron
                  ? GestureDetector(
                      key: const ValueKey('search-leading-back'),
                      onTap: widget.onLeadingAction,
                      behavior: HitTestBehavior.opaque,
                      child: const SizedBox(
                        width: 20,
                        height: 20,
                        child: Center(
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 16,
                            color: KalinkaColors.textPrimary,
                          ),
                        ),
                      ),
                    )
                  : const SizedBox(
                      key: ValueKey('search-leading-search'),
                      width: 20,
                      height: 20,
                      child: Center(
                        child: Icon(
                          Icons.search,
                          size: 16,
                          color: KalinkaColors.accent,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 8),
            // Text input
            Expanded(
              child: Semantics(
                label: 'Search music',
                hint: 'Double tap to search',
                textField: true,
                child: TextField(
                  controller: _textController,
                  focusNode: _searchFocusNode,
                  style: KalinkaTextStyles.searchBarInput,
                  cursorColor: KalinkaColors.accent,
                  decoration: InputDecoration(
                    hintText: 'Search music\u2026',
                    hintStyle: KalinkaTextStyles.searchPlaceholder,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isCollapsed: true,
                  ),
                  onChanged: _onQueryChanged,
                  onSubmitted: _onSubmitted,
                ),
              ),
            ),
            // ✕ clear button — animated, only when text is present
            _buildClearButton(),
            // AI pill toggle — always visible
            _buildAiPill(),
            const SizedBox(width: 6),
            // Mic button — always visible
            _buildMicButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildClearButton() {
    return AnimatedBuilder(
      animation: _clearButtonController,
      builder: (context, _) {
        final progress = CurvedAnimation(
          parent: _clearButtonController,
          curve: Curves.easeOut,
          reverseCurve: Curves.easeIn,
        ).value;

        if (progress == 0) return const SizedBox.shrink();

        return Opacity(
          opacity: progress,
          child: SizedBox(
            width: 28 * progress,
            child: GestureDetector(
              onTap: progress > 0.5 ? _onClearTapped : null,
              child: Center(
                child: Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: KalinkaColors.textMuted,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAiPill() {
    return Semantics(
      label: _isAiModeActive
          ? 'AI search active. Tap to switch to direct search.'
          : 'AI search inactive. Tap to enable AI search.',
      button: true,
      child: GestureDetector(
        onTap: () {
          KalinkaHaptics.lightImpact();
          setState(() => _isAiModeActive = !_isAiModeActive);
        },
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: const Color(0x0DFFFFFF),
                border: Border.all(
                  color: _isAiModeActive
                      ? KalinkaColors.accentBorder
                      : KalinkaColors.borderDefault,
                  width: 1,
                ),
              ),
              child: Text(
                _isAiModeActive ? 'AI \u25CF' : 'AI \u25CB',
                style: KalinkaTextStyles.aiBadge.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: _isAiModeActive
                      ? KalinkaColors.accentTint
                      : KalinkaColors.textMuted,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMicButton() {
    return GestureDetector(
      onTap: () {
        KalinkaHaptics.mediumImpact();
        // Mic placeholder — no-op for now
      },
      behavior: HitTestBehavior.opaque,
      child: const SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: Icon(
            Icons.mic_none_rounded,
            size: 16,
            color: KalinkaColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

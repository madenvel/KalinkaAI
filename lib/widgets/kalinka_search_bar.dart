import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../providers/connection_state_provider.dart';
import '../providers/search_state_provider.dart';
import '../theme/app_theme.dart';
import '../utils/haptics.dart';

/// Shared search bar used in both phone (HeaderZone) and tablet (SidePanel).
///
/// The bar always shows its full layout — Kalinka logo, text field, conditional
/// clear button, vertical separator, AI mode pill toggle, mic icon, and
/// connection dot. There is no pill/collapsed state. The border brightens from
/// borderDefault to textMuted on focus.
///
/// [alwaysExpanded] — when true (tablet), the TextField auto-activates search
/// on mount. When false (phone), search activates on first tap.
/// [onActivate] — called when the bar transitions from ambient to focused.
class KalinkaSearchBar extends ConsumerStatefulWidget {
  final bool alwaysExpanded;
  final VoidCallback? onActivate;
  final VoidCallback? onLeadingAction;
  final VoidCallback? onServerChipTap;
  final bool showBackChevron;
  final bool fullBleedMode;
  final double height;
  final EdgeInsetsGeometry? contentPadding;

  const KalinkaSearchBar({
    super.key,
    this.alwaysExpanded = false,
    this.onActivate,
    this.onLeadingAction,
    this.onServerChipTap,
    this.showBackChevron = false,
    this.fullBleedMode = false,
    this.height = 44,
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
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  bool _isActive = false;
  bool _isFocused = false;

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

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 0.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
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
    _pulseController.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() => _isFocused = _searchFocusNode.hasFocus);

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
    setState(() => _isFocused = false);

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
    final isDisconnected =
        connectionStatus == ConnectionStatus.none ||
        connectionStatus == ConnectionStatus.reconnecting ||
        connectionStatus == ConnectionStatus.offline;

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
      return Opacity(opacity: 0.38, child: bar);
    }

    return bar;
  }

  Widget _buildSearchBar() {
    final isFullBleed = widget.fullBleedMode;
    final borderColor = _isFocused
        ? KalinkaColors.textMuted
        : KalinkaColors.borderDefault;

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
      child: AnimatedContainer(
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
        ),
        padding:
            widget.contentPadding ?? const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            // Leading: Kalinka logo or back chevron
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
                        height: 44,
                        child: Center(
                          child: Icon(
                            Icons.arrow_back,
                            size: 16,
                            color: KalinkaColors.textPrimary,
                          ),
                        ),
                      ),
                    )
                  : SizedBox(
                      key: const ValueKey('search-leading-logo'),
                      width: 22,
                      height: 44,
                      child: Center(
                        child: SvgPicture.asset(
                          'assets/images/kalinka_icon.svg',
                          height: 22,
                          width: 22,
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
            const SizedBox(width: 4),
            // Separator between input area and controls
            Container(width: 1, height: 18, color: KalinkaColors.borderDefault),
            const SizedBox(width: 4),
            // AI pill toggle
            _buildAiPill(),
            // Mic button
            _buildMicButton(),
            // Connection dot
            _buildConnectionDot(),
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
    final isAiEnabled = ref.watch(searchStateProvider).isAiEnabled;
    return Semantics(
      label: isAiEnabled
          ? 'AI search active. Tap to switch to direct search.'
          : 'AI search inactive. Tap to enable AI search.',
      button: true,
      child: GestureDetector(
        onTap: () {
          KalinkaHaptics.lightImpact();
          ref.read(searchStateProvider.notifier).toggleAiMode();
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
                  color: isAiEnabled
                      ? KalinkaColors.gold.withValues(alpha: 0.6)
                      : KalinkaColors.borderDefault,
                  width: 1,
                ),
              ),
              child: Builder(
                builder: (context) {
                  final aiColor = isAiEnabled
                      ? KalinkaColors.gold
                      : KalinkaColors.textMuted;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome, size: 10, color: aiColor),
                      const SizedBox(width: 4),
                      Text(
                        'AI',
                        style: KalinkaTextStyles.aiBadge.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: aiColor,
                        ),
                      ),
                    ],
                  );
                },
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
        width: 36,
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

  Widget _buildConnectionDot() {
    final connectionState = ref.watch(connectionStateProvider);

    if (connectionState == ConnectionStatus.reconnecting ||
        connectionState == ConnectionStatus.connecting) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      if (_pulseController.isAnimating) {
        _pulseController.stop();
        _pulseController.value = 1.0;
      }
    }

    final color = switch (connectionState) {
      ConnectionStatus.connected => KalinkaColors.statusOnline,
      ConnectionStatus.reconnecting ||
      ConnectionStatus.connecting => KalinkaColors.statusPending,
      ConnectionStatus.offline ||
      ConnectionStatus.none => KalinkaColors.textMuted,
    };

    final semanticsLabel = switch (connectionState) {
      ConnectionStatus.connected =>
        'Server connected. Tap for server settings.',
      ConnectionStatus.reconnecting || ConnectionStatus.connecting =>
        'Reconnecting to server. Tap for server settings.',
      ConnectionStatus.offline => 'Server offline. Tap for server settings.',
      ConnectionStatus.none => 'No server configured. Tap for server settings.',
    };

    Widget dot = Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: connectionState == ConnectionStatus.connected
            ? [BoxShadow(color: color.withValues(alpha: 0.55), blurRadius: 6)]
            : null,
      ),
    );

    if (connectionState == ConnectionStatus.reconnecting ||
        connectionState == ConnectionStatus.connecting) {
      dot = FadeTransition(opacity: _pulseAnimation, child: dot);
    }

    return Semantics(
      label: semanticsLabel,
      button: true,
      child: GestureDetector(
        onTap: widget.onServerChipTap != null
            ? () => widget.onServerChipTap!()
            : null,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(width: 36, height: 44, child: Center(child: dot)),
      ),
    );
  }
}

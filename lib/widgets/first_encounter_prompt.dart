import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/add_mode_provider.dart';
import '../providers/kalinka_player_api_provider.dart';
import '../theme/app_theme.dart';

/// Bottom prompt shown on first + button tap.
/// Lets the user pick Mode A ("Play next" / ask each time)
/// or Mode B ("+ Append" / always append).
class FirstEncounterPrompt extends ConsumerStatefulWidget {
  const FirstEncounterPrompt({super.key});

  @override
  ConsumerState<FirstEncounterPrompt> createState() =>
      _FirstEncounterPromptState();
}

class _FirstEncounterPromptState extends ConsumerState<FirstEncounterPrompt>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _opacityAnimation;
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Cubic(0.4, 0, 0.2, 1),
          ),
        );
    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() {
    if (_dismissing) return;
    _dismissing = true;
    _controller.reverse().then((_) {
      if (mounted) {
        ref.read(addModeProvider.notifier).clearFirstEncounterTrigger();
        setState(() => _dismissing = false);
      }
    });
  }

  Future<void> _handlePlayNext() async {
    final item = ref.read(addModeProvider).firstEncounterTriggerItem;
    if (item == null) return;

    // Set mode and mark first encounter shown
    await ref.read(addModeProvider.notifier).setAddMode(AddMode.askEachTime);
    await ref.read(addModeProvider.notifier).markFirstEncounterShown();

    // Execute the action
    try {
      final api = ref.read(kalinkaProxyProvider);
      await api.add([item.id]);
    } catch (_) {}

    if (mounted) {
      _controller.reverse();
    }
  }

  Future<void> _handleAppend() async {
    final item = ref.read(addModeProvider).firstEncounterTriggerItem;
    if (item == null) return;

    // Set mode and mark first encounter shown
    await ref.read(addModeProvider.notifier).setAddMode(AddMode.alwaysAppend);
    await ref.read(addModeProvider.notifier).markFirstEncounterShown();

    // Execute the action
    try {
      final api = ref.read(kalinkaProxyProvider);
      await api.add([item.id]);
    } catch (_) {}

    if (mounted) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final addModeState = ref.watch(addModeProvider);
    final triggerItem = addModeState.firstEncounterTriggerItem;

    // Drive animation based on trigger state
    if (triggerItem != null && !_dismissing) {
      _controller.forward();
    }

    if (triggerItem == null && !_controller.isAnimating) {
      return const SizedBox.shrink();
    }

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _opacityAnimation,
        child: GestureDetector(
          onTap: _dismiss,
          behavior: HitTestBehavior.opaque,
          child: Container(
            decoration: BoxDecoration(
              color: KalinkaColors.miniPlayerSurface,
              border: const Border(
                top: BorderSide(color: KalinkaColors.borderElevated, width: 1),
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.65),
                  blurRadius: 48,
                  offset: const Offset(0, -16),
                ),
              ],
            ),
            child: GestureDetector(
              onTap: () {}, // absorb taps on the sheet itself
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                    child: Text(
                      'How do you want to add tracks?',
                      style: KalinkaTextStyles.trackRowTitle.copyWith(
                        fontSize: 15,
                        letterSpacing: -0.15,
                        color: KalinkaColors.textPrimary,
                      ),
                    ),
                  ),
                  // Two action buttons
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        // Play next button
                        Expanded(
                          child: GestureDetector(
                            onTap: _handlePlayNext,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              decoration: BoxDecoration(
                                color: KalinkaColors.accent.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(13),
                                border: Border.all(
                                  color: KalinkaColors.accent.withValues(
                                    alpha: 0.3,
                                  ),
                                  width: 1,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  'Play next',
                                  style: KalinkaTextStyles.trackRowTitle
                                      .copyWith(
                                        fontSize: 13,
                                        color: KalinkaColors.accent,
                                      ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Append button
                        Expanded(
                          child: GestureDetector(
                            onTap: _handleAppend,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              decoration: BoxDecoration(
                                color: KalinkaColors.gold.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(13),
                                border: Border.all(
                                  color: KalinkaColors.gold.withValues(
                                    alpha: 0.3,
                                  ),
                                  width: 1,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  '+ Append',
                                  style: KalinkaTextStyles.trackRowTitle
                                      .copyWith(
                                        fontSize: 13,
                                        color: KalinkaColors.gold,
                                      ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Preference labels
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Always ask',
                          style: KalinkaTextStyles.trackRowSubtitle.copyWith(
                            fontSize: 10,
                            color: KalinkaColors.textSecondary,
                          ),
                        ),
                        Text(
                          'Always append',
                          style: KalinkaTextStyles.trackRowSubtitle.copyWith(
                            fontSize: 10,
                            color: KalinkaColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Footer
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20, top: 4),
                    child: Text(
                      'You can change this in Settings',
                      style: KalinkaTextStyles.trackRowSubtitle.copyWith(
                        fontSize: 9,
                        color: const Color(0xFF48485A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

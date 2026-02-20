import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/kalinka_player_api_provider.dart';
import '../theme/app_theme.dart';

/// Confirmation dialog for clearing the entire queue.
/// Slides up from the bottom after a 160ms delay from the tray closing.
class ClearAllConfirmDialog extends ConsumerStatefulWidget {
  final VoidCallback onCancel;
  final VoidCallback onConfirmed;

  const ClearAllConfirmDialog({
    super.key,
    required this.onCancel,
    required this.onConfirmed,
  });

  @override
  ConsumerState<ClearAllConfirmDialog> createState() =>
      _ClearAllConfirmDialogState();
}

class _ClearAllConfirmDialogState extends ConsumerState<ClearAllConfirmDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _slideController,
            curve: const Cubic(0.4, 0, 0.2, 1),
          ),
        );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _animateClose() async {
    await _slideController.reverse();
    widget.onCancel();
  }

  Future<void> _doClearAll() async {
    try {
      await ref.read(kalinkaProxyProvider).clear();
      if (!mounted) return;
      await _slideController.reverse();
      widget.onConfirmed();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Queue cleared')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to clear queue: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: GestureDetector(
        onTap: _animateClose,
        child: Container(
          color: Colors.black.withValues(alpha: 0.60),
          child: Column(
            children: [
              const Spacer(),
              SlideTransition(
                position: _slideAnimation,
                child: GestureDetector(
                  // Prevent backdrop tap from passing through
                  onTap: () {},
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: KalinkaColors.miniPlayerSurface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: KalinkaColors.borderElevated),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.7),
                          blurRadius: 60,
                          offset: const Offset(0, -20),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Trash icon
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: KalinkaColors.deleteRed.withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: KalinkaColors.deleteRed.withValues(
                                alpha: 0.2,
                              ),
                            ),
                          ),
                          child: const Icon(
                            Icons.delete_outline,
                            size: 24,
                            color: KalinkaColors.deleteRed,
                          ),
                        ),
                        const SizedBox(height: 14),
                        // Title
                        Text(
                          'Clear entire queue?',
                          style: KalinkaTextStyles.dialogTitle,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        // Body
                        Text(
                          'This will remove all tracks including your play history. This cannot be undone.',
                          style: KalinkaTextStyles.dialogBody,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 22),
                        // Buttons
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: _animateClose,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: KalinkaColors.inputSurface,
                                    borderRadius: BorderRadius.circular(13),
                                    border: Border.all(
                                      color: KalinkaColors.borderElevated,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Cancel',
                                      style: KalinkaTextStyles.dialogButton
                                          .copyWith(
                                            color: KalinkaColors.textSecondary,
                                          ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: GestureDetector(
                                onTap: _doClearAll,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: KalinkaColors.deleteRed.withValues(
                                      alpha: 0.14,
                                    ),
                                    borderRadius: BorderRadius.circular(13),
                                    border: Border.all(
                                      color: KalinkaColors.deleteRed.withValues(
                                        alpha: 0.30,
                                      ),
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Clear all',
                                      style: KalinkaTextStyles.dialogButton
                                          .copyWith(
                                            color: KalinkaColors.deleteRed,
                                          ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 28),
            ],
          ),
        ),
      ),
    );
  }
}

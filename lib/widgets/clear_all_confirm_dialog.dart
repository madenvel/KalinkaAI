import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/toast_provider.dart';
import '../theme/app_theme.dart';
import '../utils/haptics.dart';

/// Confirmation dialog content for clearing the entire queue.
///
/// Returns `true` if the user confirmed and the clear succeeded,
/// `false` or `null` if cancelled.
class ClearAllConfirmDialog extends ConsumerWidget {
  final Future<void> Function() onConfirmClearAll;

  const ClearAllConfirmDialog({
    super.key,
    required this.onConfirmClearAll,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: KalinkaColors.surfaceRaised,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: KalinkaColors.borderDefault),
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
                  color: KalinkaColors.actionDelete.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: KalinkaColors.actionDelete.withValues(alpha: 0.2),
                  ),
                ),
                child: const Icon(
                  Icons.delete_outline,
                  size: 24,
                  color: KalinkaColors.actionDelete,
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
                      onTap: () {
                        KalinkaHaptics.lightImpact();
                        Navigator.pop(context, false);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: KalinkaColors.surfaceInput,
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(
                            color: KalinkaColors.borderDefault,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'Cancel',
                            style: KalinkaTextStyles.dialogButton.copyWith(
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
                      onTap: () async {
                        KalinkaHaptics.heavyImpact();
                        try {
                          await onConfirmClearAll();
                          if (context.mounted) Navigator.pop(context, true);
                        } catch (e) {
                          if (context.mounted) {
                            ref.read(toastProvider.notifier).show(
                              'Failed to clear queue: $e',
                              isError: true,
                            );
                          }
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: KalinkaColors.actionDelete.withValues(
                            alpha: 0.14,
                          ),
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(
                            color: KalinkaColors.actionDelete.withValues(
                              alpha: 0.30,
                            ),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'Clear all',
                            style: KalinkaTextStyles.dialogButton.copyWith(
                              color: KalinkaColors.actionDelete,
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
        SizedBox(height: MediaQuery.of(context).padding.bottom + 28),
      ],
    );
  }
}

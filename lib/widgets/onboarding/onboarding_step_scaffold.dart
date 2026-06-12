import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../kalinka_button.dart';

/// Shared chrome for wizard steps after the discovery step: progress
/// header, display-font title, scrollable body, Back/Continue footer.
///
/// Content is width-constrained and centered so the wizard reads well on
/// tablets without a separate layout.
class OnboardingStepScaffold extends StatelessWidget {
  /// 1-based step number shown in the header (includes the discovery step).
  final int stepNumber;
  final int stepCount;
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final VoidCallback? onBack;
  final VoidCallback? onNext;
  final String nextLabel;

  const OnboardingStepScaffold({
    super.key,
    required this.stepNumber,
    required this.stepCount,
    required this.title,
    this.subtitle,
    required this.children,
    this.onBack,
    this.onNext,
    this.nextLabel = 'Continue',
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'STEP $stepNumber OF $stepCount',
                      style: KalinkaTextStyles.sectionHeaderMuted,
                    ),
                    const SizedBox(height: 8),
                    _buildProgressBar(),
                    const SizedBox(height: 20),
                    Text(title, style: KalinkaTextStyles.dialogTitle),
                    if (subtitle != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        subtitle!,
                        style: KalinkaTextStyles.trayRowSublabel.copyWith(
                          fontSize: KalinkaTypography.baseSize + 2,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(top: 16, bottom: 24),
                  children: children,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: [
                    if (onBack != null) ...[
                      KalinkaButton(
                        label: 'Back',
                        variant: KalinkaButtonVariant.neutral,
                        size: KalinkaButtonSize.normal,
                        onTap: onBack,
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: KalinkaButton(
                        label: nextLabel,
                        variant: KalinkaButtonVariant.accent,
                        size: KalinkaButtonSize.normal,
                        fullWidth: true,
                        enabled: onNext != null,
                        onTap: onNext,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    final progress = stepNumber / stepCount;
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          height: 3,
          decoration: BoxDecoration(
            color: KalinkaColors.surfaceElevated,
            borderRadius: BorderRadius.circular(2),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: const Cubic(0.4, 0, 0.2, 1),
              width: constraints.maxWidth * progress,
              height: 3,
              decoration: BoxDecoration(
                color: KalinkaColors.accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Muted uppercase section label above a settings card, matching the
/// settings screen's section chrome.
class OnboardingSectionLabel extends StatelessWidget {
  final String text;

  const OnboardingSectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Text(
        text.toUpperCase(),
        style: KalinkaTextStyles.sectionHeaderMuted,
      ),
    );
  }
}

/// Explanatory note for wizard steps. Larger and brighter than the
/// settings screen's [FooterNote] — first-run copy is read once and must
/// be readable at a glance, not blend into the chrome.
class OnboardingNote extends StatelessWidget {
  final String text;

  const OnboardingNote(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Text(
        text,
        style: KalinkaTextStyles.trayRowSublabel.copyWith(
          fontSize: KalinkaTypography.baseSize + 3,
          height: 1.55,
        ),
      ),
    );
  }
}

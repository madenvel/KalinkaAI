import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'inline_markdown.dart';
import 'settings_toggle.dart';

/// Collapsible section header with an integrated enable/disable switch.
///
/// Layout:
/// ```
/// ┌──────────┬───────────────────────────────────────────┐
/// │  [tap]   │  [tap to expand]                          │
/// │ [switch] │  Section title                  [chevron] │
/// │          │  optional status text (markdown)          │
/// └──────────┴───────────────────────────────────────────┘
/// ```
///
/// The two header zones have independent tap targets, separated by a
/// thin vertical divider:
///
///   * Left zone — flips the enabled toggle.
///   * Right zone — expands/collapses the section body.
///
/// `statusMarkdown` lets a plugin-resolved sub-feature status appear
/// directly under the title, no separate "Status" label. When the
/// section is disabled, the body still expands on tap so users can see
/// what they'd be enabling, but the rows render dimmed.
class SettingsToggleableSection extends StatefulWidget {
  final String title;
  final bool enabled;
  final ValueChanged<bool> onToggle;
  final String? statusMarkdown;
  final Widget? body;
  final bool initiallyExpanded;
  final bool isStaged;

  const SettingsToggleableSection({
    super.key,
    required this.title,
    required this.enabled,
    required this.onToggle,
    this.statusMarkdown,
    this.body,
    this.initiallyExpanded = false,
    this.isStaged = false,
  });

  @override
  State<SettingsToggleableSection> createState() =>
      _SettingsToggleableSectionState();
}

class _SettingsToggleableSectionState extends State<SettingsToggleableSection>
    with SingleTickerProviderStateMixin {
  late AnimationController _chevronController;
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
    _chevronController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      value: _expanded ? 1.0 : 0.0,
    );
  }

  @override
  void dispose() {
    _chevronController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _expanded = !_expanded;
      if (_expanded) {
        _chevronController.forward();
      } else {
        _chevronController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasBody = widget.body != null;
    final hasStatus =
        widget.statusMarkdown != null && widget.statusMarkdown!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Staged amber bar on the far left when this section's enabled
        // toggle has unsaved changes — visually consistent with the
        // amber accent SettingsRow uses for staged fields.
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.isStaged)
                Container(
                  width: 1,
                  decoration: BoxDecoration(
                    color: KalinkaColors.statusPending,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              // Switch zone
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => widget.onToggle(!widget.enabled),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: SettingsToggle(
                    value: widget.enabled,
                    onChanged: widget.onToggle,
                  ),
                ),
              ),
              // Vertical divider between switch and title — also a
              // visual cue that the header has two independent tap
              // zones.
              const VerticalDivider(
                width: 1,
                thickness: 1,
                color: KalinkaColors.borderSubtle,
              ),
              // Title + status + chevron, tappable for expand/collapse.
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: hasBody ? _toggleExpanded : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.title,
                                style: KalinkaTextStyles.trayRowLabel.copyWith(
                                  // Slightly muted when disabled, to
                                  // reinforce the off state without
                                  // hiding the title.
                                  color: widget.enabled
                                      ? KalinkaColors.textPrimary
                                      : KalinkaColors.textSecondary,
                                ),
                              ),
                              if (hasStatus) ...[
                                const SizedBox(height: 3),
                                InlineMarkdown(
                                  text: widget.statusMarkdown!,
                                  style: KalinkaTextStyles.trayRowSublabel
                                      .copyWith(
                                        color: widget.enabled
                                            ? KalinkaColors.textSecondary
                                            : KalinkaColors.textMuted,
                                        height: 1.4,
                                      ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (hasBody) ...[
                          const SizedBox(width: 8),
                          AnimatedBuilder(
                            animation: _chevronController,
                            builder: (context, child) {
                              return Transform.rotate(
                                angle: _chevronController.value * 3.14159,
                                child: child,
                              );
                            },
                            child: const Icon(
                              Icons.keyboard_arrow_down,
                              size: 16,
                              color: KalinkaColors.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (hasBody)
          AnimatedSize(
            duration: const Duration(milliseconds: 340),
            curve: const Cubic(0.4, 0, 0.2, 1),
            alignment: Alignment.topCenter,
            child: _expanded
                ? Opacity(
                    // Dim the body when the sub-feature is off so the
                    // user sees what they'd be configuring but can tell
                    // at a glance that nothing's running yet.
                    opacity: widget.enabled ? 1.0 : 0.45,
                    child: widget.body!,
                  )
                : const SizedBox.shrink(),
          ),
      ],
    );
  }
}

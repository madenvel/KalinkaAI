import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data_model/data_model.dart';
import '../providers/source_modules_provider.dart';
import '../theme/app_theme.dart';
import '../utils/haptics.dart';

enum SourceBadgeSize { standard, small }

/// Whether a [SourceBadge] for [entityId] renders anything — false for a
/// single source, an unparseable id, or a source the server provides itself.
/// Callers gate the badge's trailing spacer on this so no gap is left when
/// it's hidden.
bool sourceBadgeVisible(WidgetRef ref, String entityId) {
  if (ref.watch(sourceCountProvider) <= 1) return false;
  final source = sourceOfId(entityId);
  if (source == null) return false;
  final info = ref.watch(sourceDisplayInfoProvider)[source];
  return info != null && !info.builtin;
}

/// Displays a source attribution badge: a pill containing the first letter
/// of the source name, uppercase, in the source colour.
///
/// Automatically hides when only one source is configured — with nothing to
/// tell apart, a badge is noise.
///
/// [size.standard]: 11dp font, 5dp h-padding, 2dp v-padding (list rows, now-playing)
/// [size.small]:    10dp font, 4dp h-padding, 1.5dp v-padding (queue rows, tiles)
class SourceBadge extends ConsumerWidget {
  final String entityId;
  final SourceBadgeSize size;

  /// Optional border-radius override for collapsed multi-badge groups.
  final BorderRadius? borderRadiusOverride;

  const SourceBadge({
    super.key,
    required this.entityId,
    this.size = SourceBadgeSize.standard,
    this.borderRadiusOverride,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!sourceBadgeVisible(ref, entityId)) return const SizedBox.shrink();

    final source = EntityId.fromString(entityId).source;
    final info = ref.watch(sourceDisplayInfoProvider)[source]!;

    final color = info.color;
    final letter = info.abbreviation; // already first letter, uppercased

    final double fs = size == SourceBadgeSize.small ? 10.0 : 11.0;
    final double px = size == SourceBadgeSize.small ? 4.0 : 5.0;
    final double py = size == SourceBadgeSize.small ? 1.5 : 2.0;
    final BorderRadius radius =
        borderRadiusOverride ?? BorderRadius.circular(4);

    return Semantics(
      label: info.title,
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: px, vertical: py),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          border: Border.all(color: color.withValues(alpha: 0.30), width: 1),
          borderRadius: radius,
        ),
        child: Text(
          letter,
          style: KalinkaTextStyles.sourceBadgeLetter.copyWith(
            fontSize: fs,
            color: color,
          ),
        ),
      ),
    );
  }
}

/// The letter tile that stands for a source where a results group, a filter
/// pill or a collection drawn from several names the sources it holds.
class SourceLetter extends ConsumerWidget {
  final String source;

  /// Side of the tile. Smaller where the letters sit on a row's second line
  /// rather than beside a heading.
  final double size;

  const SourceLetter({super.key, required this.source, this.size = 22});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(sourceDisplayInfoProvider)[source];
    final color = info?.color ?? colorForSourceName(source);
    final letter =
        info?.abbreviation ?? (source.isEmpty ? '?' : source[0].toUpperCase());
    return Semantics(
      label: info?.title ?? source,
      excludeSemantics: true,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          border: Border.all(color: color.withValues(alpha: 0.30), width: 1),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          letter,
          style: KalinkaTextStyles.sourceBadgeLetter.copyWith(
            fontSize: size / 2,
            color: color,
          ),
        ),
      ),
    );
  }
}

/// One choice in a row that picks which source to read: the mark
/// [SourceLetter] draws on a row, sized to be tapped.
///
/// Keeps that mark's shape — a rounded square, not a circle — so the control
/// and the badge it stands for read as the same thing. A source speaks in
/// its own colour; a choice that names no source ([tint] null, such as ALL)
/// speaks in the app's, and only when it is the one being read.
///
/// Selection is an outline, never a fill: this row is chrome that stays on
/// screen for the whole session, and the crimson fill is reserved for a
/// decision surface — see the palette's budget.
class SourceChoice extends StatefulWidget {
  final String label;

  /// The colour this choice is drawn in, or null for one that stands for no
  /// single source.
  final Color? tint;

  final bool selected;
  final VoidCallback onTap;

  /// Name for a screen reader, where [label] is a bare letter.
  final String semanticsLabel;

  /// Side of a single-letter choice, and the height of every one of them.
  static const side = 44.0;

  /// Breathing room either side of the label. A lone letter is squared up to
  /// [side] against these two.
  static const _padding = 12.0;
  static const _border = 1.0;

  const SourceChoice({
    super.key,
    required this.label,
    required this.tint,
    required this.selected,
    required this.onTap,
    required this.semanticsLabel,
  });

  @override
  State<SourceChoice> createState() => _SourceChoiceState();
}

class _SourceChoiceState extends State<SourceChoice> {
  bool _hovering = false;

  void _setHovering(bool value) {
    if (value == _hovering) return;
    setState(() => _hovering = value);
  }

  @override
  Widget build(BuildContext context) {
    // Berry for a choice with no colour of its own, at the alphas the
    // palette gives the outline treatment.
    final mark = widget.tint ?? KalinkaColors.accent;
    final Color bg;
    final Color border;
    if (widget.selected) {
      bg = mark.withValues(alpha: 0.10);
      border = mark.withValues(alpha: _hovering ? 0.70 : 0.40);
    } else {
      bg = _hovering
          ? KalinkaColors.surfaceOverlay
          : KalinkaColors.surfaceElevated;
      border = _hovering
          ? KalinkaColors.textMuted
          : KalinkaColors.borderDefault;
    }
    final fg =
        widget.tint ??
        (widget.selected
            ? KalinkaColors.accentTint
            : KalinkaColors.textSecondary);

    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.semanticsLabel,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => _setHovering(true),
        onExit: (_) => _setHovering(false),
        child: GestureDetector(
          onTap: () {
            KalinkaHaptics.selectionClick();
            widget.onTap();
          },
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 130),
            curve: Curves.easeOut,
            height: SourceChoice.side,
            padding: const EdgeInsets.symmetric(
              horizontal: SourceChoice._padding,
            ),
            decoration: BoxDecoration(
              color: bg,
              border: Border.all(color: border, width: SourceChoice._border),
              // SourceLetter's 5-on-22, so the two are the same shape.
              borderRadius: BorderRadius.circular(10),
            ),
            // Sized by its padding and this floor, never by an alignment —
            // a Container given one expands to fill whatever it is handed.
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth:
                    SourceChoice.side -
                    2 * (SourceChoice._padding + SourceChoice._border),
              ),
              child: Text(
                widget.label,
                textAlign: TextAlign.center,
                style: KalinkaTextStyles.sourceBadgeLetter.copyWith(
                  fontSize: 13,
                  color: fg,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

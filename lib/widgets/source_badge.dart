import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data_model/data_model.dart';
import '../providers/source_modules_provider.dart';
import '../theme/app_theme.dart';

enum SourceBadgeSize { standard, small }

/// Whether a [SourceBadge] for [entityId] renders anything — false for a
/// single source, an unparseable id, the local library, or a source the
/// server provides itself. Callers gate the badge's trailing spacer on this
/// so no gap is left when it's hidden.
bool sourceBadgeVisible(WidgetRef ref, String entityId) {
  if (ref.watch(sourceCountProvider) <= 1) return false;
  final source = sourceOfId(entityId);
  if (source == null || isLocalSource(source)) return false;
  final info = ref.watch(sourceDisplayInfoProvider)[source];
  return info != null && !info.builtin;
}

/// Displays a source attribution badge: a pill containing the first letter
/// of the source name, uppercase, in the source colour.
///
/// Automatically hides when only one source is configured, and always hides
/// for the local-files source (the unmarked default).
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

/// The letter tile for [source] where a results group or a filter pill
/// names its source, or nothing for the local library: it is the unmarked
/// default here as everywhere.
Widget? sourceLetter(String source) =>
    isLocalSource(source) ? null : SourceLetter(source: source);

/// The letter tile that stands for a source in a results group or a filter
/// pill. Reached through [sourceLetter], which keeps the library unmarked.
class SourceLetter extends ConsumerWidget {
  final String source;

  const SourceLetter({super.key, required this.source});

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
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          border: Border.all(color: color.withValues(alpha: 0.30), width: 1),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          letter,
          style: KalinkaTextStyles.sourceBadgeLetter.copyWith(
            fontSize: 11,
            color: color,
          ),
        ),
      ),
    );
  }
}

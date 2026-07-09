import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data_model/data_model.dart';
import '../providers/source_modules_provider.dart';
import '../theme/app_theme.dart';

enum SourceBadgeSize { standard, small }

/// Whether a [SourceBadge] for [entityId] will render anything — false when
/// there's only one source, the id is unparseable, or the source is the local
/// (unmarked) library. Callers gate the badge's trailing spacer on this so no
/// gap is left where a hidden badge would have been.
bool sourceBadgeVisible(WidgetRef ref, String entityId) {
  if (ref.watch(sourceCountProvider) <= 1) return false;
  final String source;
  try {
    source = EntityId.fromString(entityId).source;
  } catch (_) {
    return false;
  }
  if (isLocalSource(source)) return false;
  return ref.watch(sourceDisplayInfoProvider)[source] != null;
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

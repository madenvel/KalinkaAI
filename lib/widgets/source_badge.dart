import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data_model/data_model.dart';
import '../providers/source_modules_provider.dart';
import '../theme/app_theme.dart';

enum SourceBadgeStyle { dot, pill }

/// Displays a source attribution badge.
///
/// [dot]: 14x14 circle with single letter, for thumbnail overlays.
/// [pill]: Bordered pill with full source name, for detail views.
///
/// Automatically hides when only one source is configured.
class SourceBadge extends ConsumerWidget {
  final String entityId;
  final SourceBadgeStyle style;

  const SourceBadge({
    super.key,
    required this.entityId,
    this.style = SourceBadgeStyle.dot,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sourceCount = ref.watch(sourceCountProvider);
    if (sourceCount <= 1) return const SizedBox.shrink();

    final String source;
    try {
      source = EntityId.fromString(entityId).source;
    } catch (_) {
      return const SizedBox.shrink();
    }

    final sourceMap = ref.watch(sourceDisplayInfoProvider);
    final info = sourceMap[source];
    if (info == null) return const SizedBox.shrink();

    return switch (style) {
      SourceBadgeStyle.dot => _buildDot(info),
      SourceBadgeStyle.pill => _buildPill(info),
    };
  }

  Widget _buildDot(SourceDisplayInfo info) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: info.color.withValues(alpha: 0.85),
        shape: BoxShape.circle,
        border: Border.all(color: KalinkaColors.background, width: 1),
      ),
      alignment: Alignment.center,
      child: Text(info.abbreviation, style: KalinkaTextStyles.sourceBadgeDot),
    );
  }

  Widget _buildPill(SourceDisplayInfo info) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: info.color, width: 1),
      ),
      child: Text(
        info.title,
        style: KalinkaTextStyles.formatBadge.copyWith(color: info.color),
      ),
    );
  }
}
